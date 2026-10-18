from pathlib import Path
import hashlib
import importlib.util
import json
import shutil
import subprocess
import zipfile

root=Path(__file__).resolve().parents[2]
folder=Path(__file__).resolve().parent
name='src/modules/sd/sd_fat32.v'
candidate=root/name
shutil.copy2(candidate,folder/'fat_compare_candidate.v')
patch=subprocess.check_output(['git','diff','--',name],cwd=root)
(folder/'fat_compare_candidate.patch').write_bytes(patch)
manifest=json.loads((folder/'build3/build_manifest.json').read_text())
with zipfile.ZipFile(root/'backups/build_repair_20261018/before.zip') as backup:
    data=backup.read(name)
assert hashlib.sha256(data).hexdigest()==manifest['sources'][name]
candidate.write_bytes(data)
spec=importlib.util.spec_from_file_location('build',root/'scripts/run_build.py')
build=importlib.util.module_from_spec(spec);spec.loader.exec_module(build)
assert manifest['sources']==build.snapshot(),'Refusing mismatched final source selection'
names=['build_manifest.json','synthesis.log','implementation.log','gate_area.txt','rtl_area.txt',
       'physical_area.txt','timing_status.txt','timing_summary.txt','io.txt',
       'video_improve_gate.db','video_improve_prior_opt.db','video_improve_routed.db',
       'prior_opt_timing_status.txt','prior_opt_timing_paths20.txt','routed_timing_paths20.txt']
for name in names:
    p=folder/'build3'/name
    if p.exists():
        shutil.copy2(p,root/'reports'/name)
(folder/'selection.json').write_text(json.dumps({
    'selected':'build3','current_inputs_match_selected_build':True,
    'rejected':{'build2':'PHY-8023 routing conflicts; counter candidate reverted',
                'pr1_trial':'same PHY-8023 conflicts with another place strategy',
                'build4':'PHY-8023 FAT mux routing conflict; FAT candidate restored from exact backup'},
    'gate_note':'Selected legal route still has negative setup; no bitgen or board signoff',
    'canonical_reports':'Restored exact build3 products; build4 failure evidence preserved separately'},indent=2))
print('SELECTED build3: current source hashes exactly match; FAT baseline restored; canonical products restored')
