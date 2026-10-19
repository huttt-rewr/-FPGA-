"""Back up and install the single-cycle WAV receive boundary trial."""
from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[2]
backup = Path(__file__).resolve().parent / 'before_wav_ingress'
backup.mkdir(exist_ok=True)
for name in ('src/modules/audio/audio_wav.v', 'scripts/implement.tcl', 'scripts/run_tests.ps1'):
    dest = backup / Path(name).name
    if dest.exists():
        raise RuntimeError(f'Backup already exists: {dest}')
    shutil.copy2(root / name, dest)

p = root / 'src/modules/audio/audio_wav.v'
s = p.read_text(encoding='utf-8-sig')
needle = ' reg resume_space;'
assert s.count(needle) == 1
s = s.replace(needle, ''' // Register the complete sector response at the WAV consumer boundary.
 // FAT32 owner/state/abort qualification ends here instead of feeding the
 // parser FSM and byte-counter enables through a long high-fanout net.
 // Keep data, valid, end and error on the same cycle, including last+end.
 // Abort/reset and SD loss flush the entire bundle before another request.
 reg [7:0] rx_data;
 reg rx_valid,rx_end,rx_error;
 always @(posedge clk or posedge rst)begin
  if(rst)begin rx_data<=0;rx_valid<=0;rx_end<=0;rx_error<=0;end
  else begin
   rx_data<=data;
   rx_valid<=sd_init_done && data_valid;
   rx_end<=sd_init_done && sector_end;
   rx_error<=sd_init_done && read_error;
  end
 end
 reg resume_space;''')
changes = {
 'if(state[2] && data_valid && count<512)sector_mem[count[8:0]]<=data;':
 'if(state[2] && rx_valid && count<512)sector_mem[count[8:0]]<=rx_data;',
 'if(data_valid && count<513)count<=count+1\'b1;':
 'if(rx_valid && count<513)count<=count+1\'b1;',
 'if(read_error || !sd_init_done)': 'if(rx_error || !sd_init_done)',
 'else if(sector_end)begin': 'else if(rx_end)begin',
 'if(count+data_valid!=512)': 'if(count+rx_valid!=512)',
}
for old,new in changes.items():
    assert s.count(old)==1, old
    s=s.replace(old,new)
p.write_text(s,encoding='utf-8',newline='\r\n')

p=root/'scripts/implement.tcl'
s=p.read_text()
start=s.index('# The legal SDC trial identifies owner')
end=s.index('route\n',start)
s=s[:start]+'''# Use the last legal flow. The directed replication experiment caused
# routing conflicts; the WAV receive register now cuts that path in RTL.
'''+s[end:]
s=s.replace('set_param place pr_strategy 2','set_param place pr_strategy 1')
p.write_text(s,encoding='utf-8',newline='\r\n')

p=root/'scripts/run_tests.ps1'
s=p.read_text(encoding='utf-8-sig')
needle=" $mergeTests += @('tb_image_index_equivalence')"
assert s.count(needle)==1
s=s.replace(needle,needle+"\n $mergeTests += @('tb_audio_rx_boundary')")
p.write_text(s,encoding='utf-8-sig',newline='\r\n')
print('Prepared WAV receive boundary; originals backed up in',backup)
