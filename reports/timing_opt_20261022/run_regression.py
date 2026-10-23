"""Run repository and AVF ModelSim regressions with isolated libraries/logs."""
from pathlib import Path
import glob
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SIM = ROOT / "sim"
LEGACY = ROOT / "legacy/f_drive_video_reference/sim"
REPORT = ROOT / "reports/timing_opt_20261022"
MODELSIM = Path(r"J:\win64")


def run(args, cwd, log=None):
    result = subprocess.run([str(arg) for arg in args], cwd=cwd,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, errors="replace")
    if log:
        Path(log).write_text(result.stdout, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(f"command failed ({result.returncode}): {args}\n{result.stdout[-4000:]}")
    return result.stdout


def main_regression():
    source = (ROOT / "scripts/run_tests.ps1").read_text(encoding="utf-8-sig")
    files = []
    tests = []
    for line in source.splitlines():
        if re.match(r"\s*\$files\s*(?:=|\+=)\s*@\(", line):
            files += re.findall(r"'([^']+)'", line)
        if re.match(r"\s*\$mergeTests\s*(?:=|\+=)\s*@\(", line):
            tests += re.findall(r"'([^']+)'", line)
    base = re.search(r"foreach\(\$tb in \(@\((.*?)\) \+ \$mergeTests\)\)", source)
    if not base:
        raise RuntimeError("Could not parse primary test list")
    tests = re.findall(r"'([^']+)'", base.group(1)) + tests
    files += [f"{test}.v" for test in tests]
    expanded = []
    for item in files:
        if "*" in item or "?" in item:
            matches = glob.glob(str(SIM / item))
            if not matches:
                raise RuntimeError(f"No source matches {item}")
            expanded += matches
        else:
            expanded.append(str(SIM / item))
    expanded = list(dict.fromkeys(expanded))
    missing = [p for p in expanded if not Path(p).is_file()]
    if missing:
        raise RuntimeError(f"Missing primary regression sources: {missing}")
    lib = "timing_opt_main_work_v2"
    if not (SIM / lib / "_info").exists():
        run([MODELSIM / "vlib.exe", lib], SIM)
    run([MODELSIM / "vlog.exe", "-work", lib, "+incdir+../src/modules/video", *expanded], SIM,
        REPORT / "main_compile.log")
    for test in tests:
        log = REPORT / "main" / f"{test}.log"
        log.parent.mkdir(parents=True, exist_ok=True)
        run([MODELSIM / "vsim.exe", "-c", "-lib", lib, test,
             "-do", "run -all; quit -f", "-l", log], SIM, log)
        result = log.read_text(encoding="utf-8", errors="replace")
        if re.search(r"FAILED|\[FAIL\]|# FAIL |\*\* Fatal", result) or "ALL PASS" not in result:
            raise RuntimeError(f"FAILED {test}; see {log}")
        print(f"ALL PASS {test}", flush=True)


def avf_regression():
    tests = ["tb_av_sync", "tb_av_controls", "tb_av_phase", "tb_av_fast_scaler",
             "tb_av_faults", "tb_sd_av", "tb_av_memory", "tb_boot_media_select",
             "tb_media_mode_switch", "tb_fat32_movie"]
    source_globs = ["../../../src/modules/common/*.v", "../../../src/modules/control/*.v",
                    "../../../src/modules/osd/*.v", "../../../src/modules/video/*.v",
                    "../../../src/modules/audio/*.v", "../../../src/modules/bmp/*.v",
                    "../../../src/modules/sd/*.v", "../../../src/modules/sd/native/*.v",
                    "../../../src/modules/memory/*.v", "../../../src/ip/fifo/*.v",
                    "../../../src/modules/input/*.v", "../../../sim/sd_native_card_model.v"]
    sources = []
    for item in source_globs:
        sources += glob.glob(str(LEGACY / item))
    sources += [str(LEGACY / f"{test}.v") for test in tests]
    missing = [p for p in sources if not Path(p).is_file()]
    if missing:
        raise RuntimeError(f"Missing AVF regression sources: {missing}")
    lib = "timing_opt_avf_work"
    if not (LEGACY / lib / "_info").exists():
        run([MODELSIM / "vlib.exe", lib], LEGACY)
    run([MODELSIM / "vlog.exe", "-work", lib,
         "+incdir+../../../src/modules/video+../../..", *sources], LEGACY,
        REPORT / "avf_compile.log")
    for test in tests:
        log = REPORT / "avf" / f"{test}.log"
        log.parent.mkdir(parents=True, exist_ok=True)
        run([MODELSIM / "vsim.exe", "-c", "-lib", lib, test,
             "-do", "run -all; quit -f", "-l", log], LEGACY, log)
        result = log.read_text(encoding="utf-8", errors="replace")
        if re.search(r"FAILED|\*\* Fatal", result) or f"ALL PASS {test}" not in result:
            raise RuntimeError(f"FAILED {test}; see {log}")
        print(f"ALL PASS {test}", flush=True)
    for test, generics in (("tb_av_fast_scaler", ["-gHQ=1"]),
                           ("tb_av_memory", ["-gHQ=1"]),
                           ("tb_fat32_movie", ["-gHQ=1"]),
                           ("tb_fat32_movie", ["-gSCENARIO=1"]),
                           ("tb_fat32_movie", ["-gSCENARIO=2"]),
                           ("tb_fat32_movie", ["-gHQ=1", "-gSCENARIO=2"]),
                           ("tb_fat32_movie", ["-gHQ=1", "-gSCENARIO=3"])):
        tag = test + "_" + "_".join(x.replace("-g", "").replace("=", "") for x in generics)
        log = REPORT / "avf" / f"{tag}.log"
        run([MODELSIM / "vsim.exe", "-c", "-lib", lib, test, *generics,
             "-do", "run -all; quit -f", "-l", log], LEGACY, log)
        result = log.read_text(encoding="utf-8", errors="replace")
        if re.search(r"FAILED|\*\* Fatal", result) or f"ALL PASS {test}" not in result:
            raise RuntimeError(f"FAILED {tag}; see {log}")
        print(f"ALL PASS {tag}", flush=True)


if __name__ == "__main__":
    REPORT.mkdir(parents=True, exist_ok=True)
    main_regression()
    avf_regression()
    (REPORT / "regression_summary.json").write_text(
        json.dumps({"main": "ALL PASS", "avf": "ALL PASS"}, indent=2), encoding="utf-8")
