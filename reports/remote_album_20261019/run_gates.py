"""Run sequential phase gates with checked exit codes; never continue on failure."""
from pathlib import Path
import subprocess,sys
root=Path(__file__).resolve().parents[2]
task=Path(__file__).resolve().parent
phase=sys.argv[1]
subprocess.run([sys.executable,'scripts/static_check.py'],cwd=root,check=True)
with (task/(phase+'_regression.log')).open('wb') as log:
 subprocess.run(['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File','scripts/run_tests.ps1'],
                cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)
print('ALL PASS full regression',phase,flush=True)
with (task/(phase+'_build.log')).open('wb') as log:
 subprocess.run([sys.executable,'scripts/run_build.py'],cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)
subprocess.run([sys.executable,str(task/'validate.py'),phase],cwd=root,check=True)
subprocess.run([sys.executable,str(task/'manage.py'),'archive',phase+'_pass'],cwd=root,check=True)
