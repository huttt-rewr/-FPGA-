from pathlib import Path
import subprocess

root=Path(__file__).resolve().parents[2]
task='reports/transitions_20261019/'
paths=['README.md','docs/USER_GUIDE.md','docs/KEY_SW_OPERATION.md','docs/BUILD_STATUS.md',
       'docs/TRANSITIONS_ZOOM_FFT_20261019.md']
paths += [task+p for p in ('RESULT.md','validation.json','audit.py','archive_build.py',
                         'update_docs.py','finalize.py','check_zoom_storage.py','zoom_storage.json',
                         'build2.log','regression3.log')]
paths += [task+'build2/reports/'+p for p in ('build_manifest.json','timing_status.txt','timing_summary.txt',
         'routed_timing_paths20.txt','physical_area.txt','gate_area.txt','synthesis.log',
         'implementation.log','hold_finalization.log','rebound_placed_timing_status.txt')]
paths += [task+'build1_failed/reports/'+p for p in ('build_manifest.json','implementation.log','gate_area.txt')]
paths += [p.relative_to(root).as_posix() for sub in ('src','regression')
          for p in (root/task/'build2'/sub).rglob('*') if p.is_file()]
paths.append(task+'build2/validation.json')
subprocess.run(['git','add','--',*paths],cwd=root,check=True)
print('Staged',len(paths),'explicit delivery paths')
