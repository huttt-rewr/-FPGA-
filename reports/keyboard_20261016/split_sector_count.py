from pathlib import Path
R=Path(__file__).resolve().parents[2]
p=R/'src/modules/video/bmp_scale_loader.v';s=p.read_text(encoding='utf-8')
assert 'cache_count+sector_valid!=512' in s
s=s.replace('cache_count+sector_valid!=512','!(sector_valid ? (cache_count==511) : (cache_count==512))')
p.write_text(s,encoding='utf-8')
p=R/'src/modules/sd/sd_fat32.v';s=p.read_text(encoding='utf-8')
anchor=' // synthesis translate_off\n'
assert anchor in s
s=s.replace(anchor,''' // A separate byte-counter owner prevents its saturating increment/hold
 // decode being shared into every FSM register clock enable. Requests and
 // returned-byte timing remain unchanged, including end+last-byte together.
 always @(posedge clk or posedge rst)begin
  if(rst)byte_count<=0;
  else if(sd_init_done)begin
   if(state[1] || state[8] || state[13] || state[22])byte_count<=0;
   else if(transferring && disk_valid && byte_count<513)byte_count<=byte_count+1'b1;
  end
 end
 // synthesis translate_off
''',1)
s=s.replace('bpb_at_partition<=0;byte_count<=0;','bpb_at_partition<=0;')
s=s.replace("    if(byte_count<513)byte_count<=byte_count+1'b1;\n",'')
s=s.replace('begin byte_count<=0;','begin ')
p.write_text(s,encoding='utf-8')
print('Removed scaler terminal adder; isolated FAT saturating sector counter from FSM CE')
