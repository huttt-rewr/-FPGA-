"""Generate and bind a candidate bitstream to the verified build inputs."""
from pathlib import Path
import datetime
import hashlib
import json
import re
import runpy
import shutil
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
TD = Path(r"J:\Anlogic\td.6.2.1\bin\td_commands_prompt.exe")
BIT = OUT / "video_improve_20261022.bit"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_timing(path):
    text = path.read_text(encoding="utf-8", errors="replace")
    values = {key: float(value) for key, value in re.findall(
        r"(SWNS|STNS|HWNS|HTNS):\s*(-?\d+\.\d+)ns", text)}
    if len(values) != 4 or any(value < 0 for value in values.values()):
        raise RuntimeError(f"Timing rejected: {path}: {values}")
    return values


def main():
    source_manifest = ROOT / "reports/build_manifest.json"
    build = json.loads(source_manifest.read_text(encoding="utf-8"))
    snapshot = runpy.run_path(str(ROOT / "scripts/run_build.py"))["snapshot"]
    if build["status"] != "completed" or snapshot() != build["sources"]:
        raise RuntimeError("Current inputs do not match a completed build")
    database = ROOT / "reports/video_improve_routed.db"
    database_sha = sha(database)
    if database_sha != build["products"][database.name]:
        raise RuntimeError("Routed database differs from completed build")
    if BIT.exists():
        raise FileExistsError(f"Refusing to overwrite existing candidate: {BIT}")
    shutil.copyfile(source_manifest, OUT / "source_build_manifest.json")
    record = {
        "status": "running",
        "started_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "device": "EG4S20BG256",
        "source_build_finished_utc": build["finished_utc"],
        "source_build_manifest_sha256": sha(source_manifest),
        "routed_database_sha256": database_sha,
        "board_signoff": False,
        "hardware_download_performed": False,
    }
    try:
        with (OUT / "bitgen.log").open("wb") as log:
            result = subprocess.run([TD.as_posix(), (OUT / "generate_candidate.tcl").as_posix()],
                                    cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                    timeout=600)
        log_text = (OUT / "bitgen.log").read_text(encoding="utf-8", errors="replace")
        errors = re.findall(
            r"^.*(?:\bERROR\s*:|\bFATAL\b|Oops!\s*coredump|invalid command name|couldn.t read file).*$",
            log_text, re.M | re.I)
        if result.returncode or "BITGEN_COMPLETED" not in log_text or errors:
            raise RuntimeError(f"Bitgen failed ({result.returncode}): {errors[:3]}")
        before = read_timing(OUT / "before_bit_timing_status.txt")
        after = read_timing(OUT / "after_bit_timing_status.txt")
        for name in ("before_bit_timing_summary.txt", "after_bit_timing_summary.txt"):
            section = (OUT / name).read_text(errors="replace").split(
                "Clock Summary", 1)[1].split("Notes", 1)[0]
            if not all(re.search(r"\b" + clock + r"\b", section) for clock in
                       ("vga_pixel", "svga_pixel", "vga_serial", "svga_serial")):
                raise RuntimeError(f"Missing mode clocks in {name}")
        if snapshot() != build["sources"] or sha(database) != database_sha:
            raise RuntimeError("Build inputs or database changed during bitgen")
        if not BIT.is_file() or BIT.stat().st_size == 0:
            raise RuntimeError("No nonempty bitstream produced")
        record.update({
            "status": "candidate_generated",
            "bit_file": str(BIT),
            "bit_bytes": BIT.stat().st_size,
            "bit_sha256": sha(BIT),
            "before_timing_ns": before,
            "after_timing_ns": after,
            "hold_margin_0_5ns_met": after["HWNS"] >= 0.5,
            "artifacts_sha256": {f.name: sha(f) for f in OUT.iterdir()
                                 if f.is_file() and f.name != "manifest.json"},
        })
        print("ALL PASS: candidate bitstream, before/after STA, four mode clocks, source binding")
        print(json.dumps({k: record[k] for k in
              ("bit_file", "bit_bytes", "bit_sha256", "after_timing_ns")}, indent=2))
    except Exception as exc:
        record.update(status="failed", error=str(exc))
        raise
    finally:
        record["finished_utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        (OUT / "manifest.json").write_text(json.dumps(record, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
