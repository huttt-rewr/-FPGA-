from pathlib import Path
import hashlib,json,re,shutil,datetime
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent
m=json.loads((R/'reports/build_manifest.json').read_text())
assert m['status']=='completed' and all(v>=0 for v in m['timing_ns'].values())
for n,h in m['sources'].items():assert hashlib.sha256((R/n).read_bytes()).hexdigest()==h,n
log=O/'regression_final.log';raw=log.read_bytes();s=raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8',errors='replace')
assert 'ALL TESTS PASSED' in s
names=re.findall(r'# vsim .*?-c (tb_[a-z0-9_]+)',s)
assert len(names)==85 and len(set(names))==85,(len(names),names)
freeze=O/'accepted';assert not freeze.exists();freeze.mkdir()
logs=freeze/'tests';logs.mkdir();test_hashes={}
for n in names:
 p=R/'reports'/(n+'.log');t=p.read_text(encoding='utf-8',errors='replace')
 assert 'ALL PASS' in t and not re.search(r'FAILED|\[FAIL\]|# FAIL |\*\* (Error|Fatal)',t),n
 shutil.copy2(p,logs/p.name);test_hashes[n]=hashlib.sha256(p.read_bytes()).hexdigest()
a=(R/'reports/physical_area.txt').read_text()
resources={k:int(re.search(r'^#'+k+r'\s+(\d+)',a,re.M)[1]) for k in ('lut','reg','bram','dsp')}
assert resources['lut']<18500 and resources['bram']==61 and resources['dsp']==17,resources
scope=json.loads((O/'scope_audit.json').read_text());assert scope['top_only_planned_video_insertion']
for n in ('build_manifest.json','synthesis.log','implementation.log','gate_area.txt','physical_area.txt','timing_status.txt','timing_summary.txt','io.txt'):
 shutil.copy2(R/'reports'/n,freeze/n)
for n in ('pixel_effects.v','glass_osd.v','audio_visualizer.v'):shutil.copy2(R/'src/modules/video'/n,freeze/(n+'.txt'))
record={'validated_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'build_status':m['status'],'tests_passed':len(names),'test_names':names,'test_log_sha256':test_hashes,'regression_log_sha256':hashlib.sha256(log.read_bytes()).hexdigest(),'resources':resources,'timing_ns':m['timing_ns'],'scope_audit':scope,'sources':m['sources'],'board_signoff':False,'hold_margin_0_5ns_met':False}
(O/'validation.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
print(json.dumps({k:record[k] for k in ('build_status','tests_passed','resources','timing_ns')},indent=2))
