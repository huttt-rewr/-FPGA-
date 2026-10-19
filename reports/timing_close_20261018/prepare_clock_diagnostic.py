from pathlib import Path
p=Path('reports/timing_close_20261018/clock_diagnostic.tcl')
s=p.read_text().replace('clock_diagnostic\n','clock_refresh_diagnostic\n')
a='source scripts/adaptive_clocks.tcl\nreport_timing_status -file $dest/after_place_rebound_status.txt'
assert a in s;s=s.replace(a,'source scripts/adaptive_clocks.tcl\nupdate_timing\nreport_timing_status -file $dest/after_place_rebound_status.txt')
s=s.replace('puts DIAGNOSTIC_COMPLETED', '''route
update_timing -mode final
source scripts/adaptive_clocks.tcl
update_timing -mode final
report_timing_status -file $dest/prior_hold_status.txt
report_timing_summary -file $dest/prior_hold_paths.txt -ep_num 20 -path_num 1
export_db $dest/prior_hold.db
fix_hold
update_timing -mode final
report_timing_status -file $dest/final_status.txt
report_timing_summary -file $dest/final_paths.txt -ep_num 20 -path_num 1
report_area -file $dest/physical_area.txt
export_db $dest/routed.db
puts DIAGNOSTIC_COMPLETED''')
Path('reports/timing_close_20261018/clock_refresh_diagnostic.tcl').write_text(s,encoding='ascii')
