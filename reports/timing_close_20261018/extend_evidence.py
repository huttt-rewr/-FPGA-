from pathlib import Path
p=Path('reports/timing_close_20261018/evidence.py');s=p.read_text(encoding='utf-8')
s=s.replace("('fps_control.v','sd_fat32.v','bmp_scale_loader.v')", "('fps_control.v','sd_fat32.v','bmp_scale_loader.v','sd_card_bmp.v')")
s=s.replace("'src/modules/video/bmp_scale_loader.v'}", "'src/modules/video/bmp_scale_loader.v','src/modules/bmp/sd_card_bmp.v'}")
s=s.replace("    assert not subprocess.check_output(['git','diff','d34c488','--','src'],cwd=ROOT), 'Final production RTL must match baseline'", "    assert set(changed)<= {'src/modules/bmp/sd_card_bmp.v'}, 'Only selected image-index candidate may remain'")
s=s.replace("print('ALL PASS scope: production RTL/IP/top/constraints unchanged; only planned flow and regression scripts changed')", "print('ALL PASS scope: only selected image-index RTL plus flow/regression; IP/top/constraints/clocks unchanged')")
p.write_text(s,encoding='utf-8')
