from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[2]
out=Path(__file__).resolve().parent/'initial_failed'
out.mkdir(exist_ok=True)
for name in ('build_manifest.json','timing_status.txt','timing_summary.txt','physical_area.txt','io.txt'):
    if (root/'reports'/name).exists():shutil.copy2(root/'reports'/name,out/name)
print('Preserved available initial failed-build reports; missing logs were removed externally')
