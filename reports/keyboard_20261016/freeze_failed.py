from pathlib import Path
import hashlib,json,re,shutil,sys
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent;s=sys.argv[1]
m=json.loads((R/'reports/build_manifest.json').read_text())
for p,h in m['sources'].items():assert hashlib.sha256((R/p).read_bytes()).hexdigest()==h,p
d=O/s;d.mkdir(exist_ok=True)
for name in ['build_manifest.json','timing_status.txt','timing_summary.txt','physical_area.txt','synthesis.log','implementation.log','io.txt','tb_mode_reload.log']:
 shutil.copy2(R/'reports'/name,d/name)
raw=(O/(s+'_regression.log')).read_bytes();log=raw.decode('utf-16') if raw.startswith(b'\xff\xfe') else raw.decode('utf-8',errors='replace')
tests=sorted(set(re.findall(r'# vsim [^\r\n]* -c (tb_\w+)',log)))
v={'stage':s,'tests_run':len(tests),'regression_passed':False,'failed_test':'tb_mode_reload',
 'reason':'Selected image overwritten during idle-to-busy transition before runtime reload',
 'build_status':m['status'],'timing_ns':m['timing_ns'],'sources':m['sources'],'board_signoff':False}
(O/(s+'_validation.json')).write_text(json.dumps(v,indent=2),encoding='utf-8')
print(json.dumps({k:x for k,x in v.items() if k!='sources'}))
