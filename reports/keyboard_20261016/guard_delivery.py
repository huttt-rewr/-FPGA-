from pathlib import Path
import argparse,hashlib,json,subprocess,re
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent
a=argparse.ArgumentParser();a.add_argument('stage');a.add_argument('--bit',action='store_true');args=a.parse_args()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
m=json.loads((O/args.stage/'build_manifest.json').read_text())
assert m['status']=='completed',m['status']
for p,h in m['sources'].items():assert sha(R/p)==h,p
protected=subprocess.check_output(['git','ls-tree','-r','--name-only','f504141','src/ip','src/modules/hdmi','src/modules/memory','src/constraints','src/modules/sd/spi_master.v','src/modules/sd/sd_card_top.v','src/modules/sd/sd_card_sec_read_write.v','src/modules/sd/sd_read_arbiter.v'],cwd=R).decode().splitlines()
for p in protected:
 old=subprocess.check_output(['git','show','f504141:'+p],cwd=R)
 assert hashlib.sha256(old).hexdigest()==sha(R/p),p
v=json.loads((O/(args.stage+'_validation.json')).read_text())
record={'stage':args.stage,'tests':v['regression_passed'],'source_hashes_match':True,
 'protected_files_unchanged':protected,'status70_unchanged':v['status70_unchanged'],
 'timing_ns':m['timing_ns'],'board_signoff':False,'formal_sd':'SPI 25MHz',
 'native_4bit_board_integrated':False,'sd_50mhz_verified':False,
 'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=R).decode().strip()}
if args.bit:
 p=O/'video_improve_keyboard_media.bit';assert p.stat().st_size>100000
 t=(O/'bitgen_timing_status.txt').read_text()
 bit_metrics={k:float(x) for k,x in re.findall(r'(SWNS|STNS|HWNS|HTNS):\s*(-?\d+\.\d+)ns',t)}
 assert len(bit_metrics)==4 and all(x>=0 for x in bit_metrics.values()),bit_metrics
 assert 'BITGEN_COMPLETED_KEYBOARD' in (O/'bitgen.log').read_text(encoding='utf-8',errors='replace')
 record.update(bit={'path':str(p),'sha256':sha(p),'bytes':p.stat().st_size},bitgen_timing_ns=bit_metrics)
(O/'delivery_manifest.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
print(json.dumps(record,ensure_ascii=False,indent=2))
