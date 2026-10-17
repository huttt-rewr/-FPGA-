"""Export a source-bound internally timed candidate, never program hardware."""
from pathlib import Path
import hashlib,json,re,subprocess,sys
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent
stage=sys.argv[1];label=sys.argv[2]
assert re.fullmatch(r'[a-z0-9_]+',label)
assert not (O/('video_improve_'+label+'.bit')).exists(), 'Use a fresh export label; preserve previous evidence'
v=json.loads((O/(stage+'_validation.json')).read_text())
assert v['build_status']=='completed' and all(x>=0 for x in v['timing_ns'].values())
for name,digest in v['sources'].items():assert hashlib.sha256((R/name).read_bytes()).hexdigest()==digest,name
m=json.loads((O/stage/'build_manifest.json').read_text())
gate=R/'reports/video_improve_gate.db'
assert hashlib.sha256(gate.read_bytes()).hexdigest()==m['products'][gate.name]
# TD6.2 routed-DB reimport loses clock hierarchy associations. Replay the same
# implementation from its source-bound gate DB, then check and export without
# leaving that session. Keep all replay reports separate from accepted evidence.
source=(R/'scripts/implement.tcl').read_text(encoding='utf-8')
source=source.replace(source.splitlines()[0], 'set root E:/fpga',1)
prefix='reports/keyboard_20261016/'+label+'_bit_'
source=source.replace('-file reports/','-file '+prefix)
source=source.replace('export_db reports/video_improve_routed.db','export_db '+prefix+'routed.db')
guard=r'''
set fh [open PREFIXtiming_status.txt r]
set metrics [read $fh]
close $fh
foreach name {SWNS STNS HWNS HTNS} {
 if {![regexp [format {%s: *(-?[0-9]+\.[0-9]+)ns} $name] $metrics ignored value]} {error "Cannot parse timing"}
 if {$value < 0} {error "$name is negative; refusing bitgen"}
}
bitgen -bit reports/keyboard_20261016/video_improve_LABEL.bit
puts "BITGEN_COMPLETED_KEYBOARD"
'''.replace('PREFIX',prefix).replace('LABEL',label)
source=source.replace('\nexit',guard+'\nexit')
p=O/(label+'_bitgen.tcl');p.write_text(source,encoding='utf-8')
with (O/(label+'_bitgen.log')).open('wb') as log:
 result=subprocess.run(['J:/Anlogic/td.6.2.1/bin/td_commands_prompt.exe',p.as_posix()],cwd=R,stdout=log,stderr=subprocess.STDOUT,timeout=1800)
text=(O/(label+'_bitgen.log')).read_text(encoding='utf-8',errors='replace')
errors=re.findall(r'^.*(?:\bERROR\s*:|\bFATAL\b|invalid command name|couldn.t read file|can.t read .*no such variable).*$',text,re.M|re.I)
assert result.returncode==0 and 'BITGEN_COMPLETED_KEYBOARD' in text and not errors,(errors,text[-2000:])
bit=O/('video_improve_'+label+'.bit');assert bit.stat().st_size>100000
timing=(O/(label+'_bit_timing_status.txt')).read_text()
metrics={k:float(x) for k,x in re.findall(r'(SWNS|STNS|HWNS|HTNS):\s*(-?\d+\.\d+)ns',timing)}
assert len(metrics)==4 and all(x>=0 for x in metrics.values())
for name,digest in v['sources'].items():assert hashlib.sha256((R/name).read_bytes()).hexdigest()==digest,name
record={'stage':stage,'bit':str(bit.relative_to(R)),'sha256':hashlib.sha256(bit.read_bytes()).hexdigest(),
 'bytes':bit.stat().st_size,'timing_ns':metrics,'board_signoff':False,
 'programmed':False,'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=R).decode().strip()}
(O/(label+'_bit_manifest.json')).write_text(json.dumps(record,indent=2),encoding='utf-8')
print(json.dumps(record,indent=2))
