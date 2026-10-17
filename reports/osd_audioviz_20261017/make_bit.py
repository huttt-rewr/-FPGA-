"""Replay source-bound implementation and export an internally timed candidate."""
from pathlib import Path
import hashlib,json,re,subprocess
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent
m=json.loads((R/'reports/build_manifest.json').read_text())
assert m['status']=='completed' and all(v>=0 for v in m['timing_ns'].values())
for n,h in m['sources'].items():assert hashlib.sha256((R/n).read_bytes()).hexdigest()==h,n
gate=R/'reports/video_improve_gate.db'
assert hashlib.sha256(gate.read_bytes()).hexdigest()==m['products'][gate.name]
bit=O/'video_improve_osd_audioviz.bit';assert not bit.exists()
s=(R/'scripts/implement.tcl').read_text(encoding='utf-8');s=s.replace(s.splitlines()[0],'set root E:/fpga',1)
prefix='reports/osd_audioviz_20261017/candidate_'
s=s.replace('-file reports/','-file '+prefix).replace('export_db reports/video_improve_routed.db','export_db '+prefix+'routed.db')
guard=r"""
set fh [open PREFIXtiming_status.txt r]
set metrics [read $fh]
close $fh
foreach name {SWNS STNS HWNS HTNS} {
 if {![regexp [format {%s: *(-?[0-9]+\.[0-9]+)ns} $name] $metrics ignored value]} {error "Cannot parse timing"}
 if {$value < 0} {error "$name negative; refusing bitgen"}
}
bitgen -bit reports/osd_audioviz_20261017/video_improve_osd_audioviz.bit
puts "OSD_AUDIOVIZ_BITGEN_COMPLETED"
""".replace('PREFIX',prefix)
s=s.replace('\nexit',guard+'\nexit')
p=O/'candidate_bitgen.tcl';p.write_text(s,encoding='utf-8')
log=O/'candidate_bitgen.log'
with log.open('wb') as f:
 result=subprocess.run(['J:/Anlogic/td.6.2.1/bin/td_commands_prompt.exe',p.as_posix()],cwd=R,stdout=f,stderr=subprocess.STDOUT,timeout=1800)
t=log.read_text(encoding='utf-8',errors='replace')
errors=re.findall(r'^.*(?:\bERROR\s*:|\bFATAL\b|invalid command name|couldn.t read file|can.t read .*no such variable).*$',t,re.M|re.I)
assert result.returncode==0 and 'OSD_AUDIOVIZ_BITGEN_COMPLETED' in t and not errors,(errors,t[-2000:])
assert bit.stat().st_size>100000
for n,h in m['sources'].items():assert hashlib.sha256((R/n).read_bytes()).hexdigest()==h,n
metrics={k:float(v) for k,v in re.findall(r'(SWNS|STNS|HWNS|HTNS):\s*(-?\d+\.\d+)ns',(O/'candidate_timing_status.txt').read_text())}
assert len(metrics)==4 and all(v>=0 for v in metrics.values())
record={'bit':bit.relative_to(R).as_posix(),'bytes':bit.stat().st_size,'sha256':hashlib.sha256(bit.read_bytes()).hexdigest(),'timing_ns':metrics,'programmed':False,'board_signoff':False,'sources':m['sources']}
(O/'candidate_bit_manifest.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in record.items() if k!='sources'},indent=2))
