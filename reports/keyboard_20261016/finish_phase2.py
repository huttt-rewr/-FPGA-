from pathlib import Path
import re,shutil
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent
p=R/'src/modules/sd/sd_card_cmd.v';s=p.read_text(encoding='utf-8')
shutil.copy2(p,O/'sd_card_cmd_before_decode.v')
states=dict(re.findall(r'parameter\s+(S_\w+)\s*=\s*(\d+);',s))
assert len(states)==18
for name,bit in states.items():
 s=re.sub(r'(parameter\s+'+name+r'\s*=\s*)\d+;',lambda m:m.group(1)+"18'h"+format(1<<int(bit),'05x')+';',s)
s=s.replace('reg[4:0]                      state;', '(* syn_encoding="onehot" *) reg[17:0] state;')
s=s.replace('reg [4:0] wait_state;', 'reg [17:0] wait_state;')
s=s.replace('case(state)', "case(1'b1)")
for name,bit in states.items():
 s=re.sub(r'(?m)^(\s*)'+name+r'\s*:',r'\g<1>state['+bit+']:',s)
s=s.replace('S_READ_ACK,S_WRITE_ACK,S_END:', 'state[8] | state[15] | state[17]:')
p.write_text(s,encoding='utf-8')
shutil.copy2(O/'audio_effects_stream.v',R/'src/modules/audio/audio_effects_stream.v')
shutil.copy2(O/'tb_audio_stream_flush.v',R/'sim/tb_audio_stream_flush.v')
p=R/'src/top.v';s=p.read_text(encoding='utf-8')
needle='wire audio_src_valid;'
assert needle in s
s=s.replace(needle,'''// A stream switch clears only the effects history; playback cadence and
// sticky underflow diagnostics survive. Release is local to the pixel clock.
wire audio_fx_reset;
reset_sync audio_effect_reset(.clk(video_clk),.arst(rst_video | audio_queue_reset),.rst(audio_fx_reset));
wire audio_src_valid;''')
s=s.replace('audio_effects #(.BASS_GAIN', 'audio_effects_stream #(.BASS_GAIN')
s=s.replace('audio_effects fx(.clk(video_clk),.rst(rst_video),', 'audio_effects_stream fx(.clk(video_clk),.rst(rst_video),')
needle=' .src_valid(audio_src_valid),.src_left(audio_src_left)'
assert needle in s;s=s.replace(needle,' .stream_rst(audio_fx_reset),'+needle)
p.write_text(s,encoding='utf-8')
source='src/modules/audio/audio_effects_stream.v'
p=R/'scripts/design_files.txt';s=p.read_text(encoding='utf-8');assert source not in s
p.write_text(s+source+'\n',encoding='utf-8')
for name in ('video_improve.al','src/td_project/video_improve.al'):
 p=R/name;s=p.read_text(encoding='utf-8')
 m=re.search(r'(?m)^\s*<File Path="[^"\n]*audio_effects\.v">[\s\S]*?</File>',s);assert m,name
 block=m.group().replace('audio_effects.v','audio_effects_stream.v')
 block=re.sub(r'CompileOrder" Val="\d+"','CompileOrder" Val="66"',block)
 p.write_text(s[:m.end()]+'\n'+block+s[m.end():],encoding='utf-8')
p=R/'scripts/run_tests.ps1';s=p.read_text(encoding='utf-8')
s=s.replace("$mergeTests += @('tb_audio_effects')", "$mergeTests += @('tb_audio_effects','tb_audio_stream_flush')")
p.write_text(s,encoding='utf-8')
p=R/'scripts/run_build.py';s=p.read_text(encoding='utf-8')
s=s.replace("('msim_work', 'pll_work')", "('msim_work', 'pll_work', 'indexed_work', 'keyboard_work', 'sd_native_work')")
p.write_text(s,encoding='utf-8')
print('Installed parallel onehot SD command decode, stream-only effects flush, and excluded generated simulation libraries from source snapshots')
