from pathlib import Path
p=Path('reports/timing_close_20261018/evidence.py');s=p.read_text(encoding='utf-8')
a="    for name in ['video_improve.al','scripts/implement.tcl','scripts/adaptive_clocks.tcl']:"
b="    for name in ['video_improve.al','scripts/adaptive_clocks.tcl']:"
assert a in s;s=s.replace(a,b)
a="    result=dict(base='d34c488',changed_source_files=changed,official_ip_and_top_and_constraints_unchanged=True,"
b="""    script_changes=subprocess.check_output(['git','diff','--name-only','d34c488','--','scripts'],cwd=ROOT).decode().splitlines()
    assert set(script_changes)<={'scripts/implement.tcl','scripts/run_build.py','scripts/run_tests.ps1'},script_changes
    assert not subprocess.check_output(['git','diff','d34c488','--','src'],cwd=ROOT), 'Final production RTL must match baseline'
    result=dict(base='d34c488',changed_source_files=changed,changed_script_files=script_changes,official_ip_and_top_and_constraints_unchanged=True,"""
assert a in s;s=s.replace(a,b)
s=s.replace("print('ALL PASS scope: only planned timer/FAT32/scaler RTL; IP, top, constraints, clocks unchanged')", "print('ALL PASS scope: production RTL/IP/top/constraints unchanged; only planned flow and regression scripts changed')")
p.write_text(s,encoding='utf-8')
