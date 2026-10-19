from pathlib import Path
p=Path('scripts/implement.tcl');s=p.read_text(encoding='utf-8')
a='source scripts/adaptive_clocks.tcl\nupdate_timing\n';assert a in s
s=s.replace(a,'''# Register the exact existing mode-clock definitions as an SDC input.
# TD replays SDC inputs when pack/route rebuilds the timing engine; Tcl-only
# definitions disappear inside those commands even if final STA rebinds them.
read_sdc scripts/adaptive_mode_clocks.sdc
update_timing
''',1)
s=s.replace('set_param place pr_strategy 2','set_param place pr_strategy 1')
p.write_text(s,encoding='utf-8')
p=Path('reports/timing_close_20261018/evidence.py');s=p.read_text(encoding='utf-8')
s=s.replace("'scripts/run_tests.ps1'},script_changes", "'scripts/run_tests.ps1','scripts/adaptive_mode_clocks.sdc'},script_changes")
s=s.replace("assert set(changed)<= {'src/modules/sd/sd_fat32.v'}, 'Only selected FAT32 guard partition may remain'", "assert not changed, 'All production RTL candidates must be restored'")
s=s.replace('only selected FAT32 guard RTL plus flow/regression','production RTL unchanged; only flow/regression')
p.write_text(s,encoding='utf-8')
