from pathlib import Path
import json,hashlib,shutil,sys
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent;dest=O/sys.argv[1]
assert not dest.exists();dest.mkdir()
m=json.loads((R/'reports/build_manifest.json').read_text())
for n,h in m['sources'].items():assert hashlib.sha256((R/n).read_bytes()).hexdigest()==h,n
for n in ('build_manifest.json','synthesis.log','implementation.log','gate_area.txt','physical_area.txt','timing_status.txt','timing_summary.txt'):
 p=R/'reports'/n
 if p.exists():shutil.copy2(p,dest/n)
for n in ('pixel_effects.v','glass_osd.v','audio_visualizer.v'):shutil.copy2(R/'src/modules/video'/n,dest/(n+'.txt'))
print('Archived',m['status'],dest)
