from pathlib import Path
import shutil
r=Path('E:/fpga');h=r/'reports/timing_close_20261018'
for name in ('sd_fat32.v','bmp_scale_loader.v'):
 p=next((r/'src').rglob(name));shutil.copy2(h/'initial'/name,p)
for name in ('implement.tcl','run_build.py'):
 shutil.copy2(r/'scripts'/name,h/'initial'/name)
p=r/'scripts/implement.tcl';s=p.read_text(encoding='utf-8')
s=s.replace('source scripts/adaptive_clocks.tcl\n','source scripts/adaptive_clocks.tcl\nupdate_timing\n',1)
a='''source scripts/adaptive_clocks.tcl
# Native 4-bit/CMD6'''
b='''source scripts/adaptive_clocks.tcl
# Rebinding changes constraints but leaves the previous timer cache intact.
# Refresh BEFORE phys_opt, so it sees the same mode clocks as final STA.
update_timing
report_timing_status -file reports/rebound_placed_timing_status.txt
report_timing_summary -file reports/rebound_placed_timing_paths20.txt -ep_num 20 -path_num 1
# Native 4-bit/CMD6'''
assert a in s;s=s.replace(a,b)
a='phys_opt -post_place -effort ultra\n';assert a in s
s=s.replace(a,a+'# Physical optimization can rebuild the timer; refresh before route too.\nupdate_timing\n')
p.write_text(s,encoding='utf-8')
p=r/'scripts/run_build.py';s=p.read_text(encoding='utf-8')
a="'prior_opt_timing_paths20.txt', 'routed_timing_paths20.txt'])"
b="'prior_opt_timing_paths20.txt', 'routed_timing_paths20.txt',\n             'rebound_placed_timing_status.txt', 'rebound_placed_timing_paths20.txt'])"
assert a in s;s=s.replace(a,b)
a="        if sources != snapshot():"
b='''        # A physically remapped mux can silently lose its alternative clocks.
        # Check refreshed placement and final routing, before trusting metrics.
        for report_name in ('rebound_placed_timing_paths20.txt', 'routed_timing_paths20.txt'):
            clock_section = (REPORTS / report_name).read_text().split('Clock Summary', 1)[1].split('Notes', 1)[0]
            if not all(re.search(r'\\b' + name + r'\\b', clock_section)
                       for name in ('vga_pixel', 'svga_pixel', 'vga_serial', 'svga_serial')):
                raise RuntimeError(f'Mode clock missing in {report_name}')
        if sources != snapshot():'''
assert a in s;s=s.replace(a,b)
p.write_text(s,encoding='utf-8')
p=h/'evidence.py';s=p.read_text(encoding='utf-8')
s=s.replace("'video_improve_gate.db','video_improve_routed.db','video_improve_prior_opt.db']", "'video_improve_gate.db','video_improve_routed.db','video_improve_prior_opt.db',\n        'rebound_placed_timing_status.txt','rebound_placed_timing_paths20.txt']")
p.write_text(s,encoding='utf-8')
print('All production RTL restored; immediate mode-clock refresh and missing-clock guard installed')
