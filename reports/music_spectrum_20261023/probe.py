from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
with (OUT/'fft_probe.log').open('wb') as f:
 result=subprocess.run(['J:/Anlogic/td.6.2.1/bin/td_commands_prompt.exe',(OUT/'probe_fft.tcl').as_posix()],
                       cwd=ROOT,stdout=f,stderr=subprocess.STDOUT)
text=(OUT/'fft_probe.log').read_text(errors='replace')
assert result.returncode==0 and 'PROBE_COMPLETED' in text
area=(OUT/'fft_probe_area.txt').read_text()
print('\n'.join(line for line in area.splitlines() if line.startswith(('#lut','#bram','#dsp'))))
