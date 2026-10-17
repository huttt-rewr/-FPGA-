from pathlib import Path
root=Path(__file__).resolve().parents[2]
out=Path(__file__).resolve().parent
files=' '.join((root/p.strip()).as_posix() for p in (root/'scripts/design_files.txt').read_text().splitlines() if p.strip())
text=(out/'synth_no_sch.tcl').read_text()
text=text.replace('open_project video_improve.al\n','')
text=text.replace('elaborate -no_sch -top top',f'read_verilog -file {{{files}}} -top top')
text=text.replace('nosch_','direct_').replace('FAT32_NOSCH','FAT32_DIRECT')
(out/'synth_direct.tcl').write_text(text)
