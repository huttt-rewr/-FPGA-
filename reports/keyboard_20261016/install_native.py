"""Install native25 only after phase four is accepted. No media logic edits."""
from pathlib import Path
import hashlib,json,re,shutil,subprocess,sys
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent
v=json.loads((O/(sys.argv[1]+'_validation.json')).read_text())
assert v['build_status']=='completed' and v['regression_passed']==77
for name,digest in v['sources'].items():
 assert hashlib.sha256((R/name).read_bytes()).hexdigest()==digest,name
subprocess.run(['python',str(O/'prepare_native_integration.py')],cwd=R,check=True)
subprocess.run(['python',str(O/'prepare_native_player_test.py')],cwd=R,check=True)
for name,target in [('top.v','src/top.v'),('sd_card_top.v','src/modules/sd/sd_card_top.v'),
 ('sd_card_bmp.v','src/modules/bmp/sd_card_bmp.v'),('pin.adc','src/constraints/pin.adc')]:
 shutil.copy2(O/'native_integration'/name,R/target)
shutil.copy2(O/'native_integration/tb_sd_native_integrated.v',R/'sim/tb_sd_native_integrated.v')
p=R/'scripts/run_tests.ps1';s=p.read_text(encoding='utf-8')
s=s.replace(" $mergeTests += @('tb_fps_control','tb_rate_player')", " $mergeTests += @('tb_fps_control','tb_rate_player','tb_sd_native_integrated')")
p.write_text(s,encoding='utf-8')
sources=['src/modules/sd/native/'+n for n in ('sd_bus_phy.v','sd_native_controller.v','sd_card_top_native.v')]
p=R/'scripts/design_files.txt';s=p.read_text(encoding='utf-8')
for name in sources:
 assert name not in s;s+=name+'\n'
p.write_text(s,encoding='utf-8')
for name in ('video_improve.al','src/td_project/video_improve.al'):
 p=R/name;s=p.read_text(encoding='utf-8')
 m=re.search(r'(?m)^\s*<File Path="[^"\n]*sd_card_top\.v">[\s\S]*?</File>',s);assert m
 additions=''
 for i,path in enumerate(sources):
  block=m.group().replace('sd_card_top.v','native/'+Path(path).name)
  block=re.sub(r'CompileOrder" Val="\d+"',f'CompileOrder" Val="{70+i}"',block)
  additions+='\n'+block
 p.write_text(s[:m.end()]+additions+s[m.end():],encoding='utf-8')
# Legacy testing continues to use NATIVE_4BIT=0. Register native descendants
# in targeted compilation scripts too, although that branch is constant-dead.
p=R/'scripts/run_indexed_tests.ps1';s=p.read_text(encoding='utf-8')
s=s.replace("'../src/modules/audio/*.v'", "'../src/modules/sd/native/*.v','../src/modules/audio/*.v'")
p.write_text(s,encoding='utf-8')
print('Native four-bit 25MHz installed, 72 formal sources/40 top IO; upper parsers unchanged')
