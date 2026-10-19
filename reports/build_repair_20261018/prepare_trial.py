from pathlib import Path
import hashlib
import json
import shutil
root=Path(__file__).resolve().parents[2]
folder=root/'reports/build_repair_20261018/pr1_trial'
folder.mkdir(exist_ok=True)
source=root/'reports/build_repair_20261018/build2/video_improve_gate.db'
shutil.copy2(source,folder/'video_improve_gate.db')
text=(root/'scripts/implement.tcl').read_text(encoding='utf-8')
text=text.replace('set root [file normalize [file join [file dirname [info script]] ..]]', 'set root E:/fpga')
text=text.replace('set_param place pr_strategy 2','set_param place pr_strategy 1')
text=text.replace('reports/','reports/build_repair_20261018/pr1_trial/')
(folder/'implement.tcl').write_text(text,encoding='utf-8')
(folder/'trial_manifest.json').write_text(json.dumps({
 'gate_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
 'change':'Only place pr_strategy 2 -> 1; same gate netlist and constraints',
 'script_sha256':hashlib.sha256(text.encode()).hexdigest()},indent=2))
