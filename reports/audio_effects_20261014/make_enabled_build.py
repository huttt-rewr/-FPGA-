"""Generate isolated enabled full-system build; official projects stay flat."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[2]
report = Path(__file__).resolve().parent
out = report/'enabled_system'
out.mkdir(exist_ok=True)
files = [root/p.strip() for p in (root/'scripts/design_files.txt').read_text().splitlines() if p.strip()]
assert len(files) == 62
literal = ' '.join(p.as_posix() for p in files)
tcl = f'''cd {root.as_posix()}
import_device eagle_s20.db -package EG4S20BG256
read_verilog -file {{{literal}}} -define AUDIO_EFFECTS_ENABLED_BUILD -top top
read_adc src/constraints/pin.adc
read_sdc src/constraints/timing.sdc
optimize_rtl
report_area -file {out.as_posix()}/rtl_area.txt
optimize_gate
legalize_phy_inst
report_area -file {out.as_posix()}/gate_area.txt
export_db {out.as_posix()}/gate.db
update_timing
source scripts/adaptive_clocks.tcl
place
route
update_timing -mode final
source scripts/adaptive_clocks.tcl
fix_hold
update_timing -mode final
report_area -io_info -file {out.as_posix()}/physical_area.txt
report_timing_status -file {out.as_posix()}/timing_status.txt
report_timing_summary -file {out.as_posix()}/timing_summary.txt
check_design
check_timing
export_db {out.as_posix()}/routed.db
puts "AUDIO_EFFECTS_ENABLED_SYSTEM_COMPLETED"
exit
'''
(report/'enabled_system.tcl').write_text(tcl, encoding='utf-8')
(out/'source_manifest.json').write_text(json.dumps({
    'define': 'AUDIO_EFFECTS_ENABLED_BUILD',
    'parameters': {'BASS_GAIN': 3276, 'TREBLE_GAIN': 3276, 'ECHO_DELAY': 2400, 'ECHO_FEEDBACK': 22938},
    'hashes': {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
}, indent=2), encoding='utf-8')
print('Isolated enabled system TCL created; official defaults unchanged')
