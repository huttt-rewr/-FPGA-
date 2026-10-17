from pathlib import Path
R=Path(__file__).resolve().parents[2]
p=R/'src/modules/video/bmp_scale_loader.v';s=p.read_text(encoding='utf-8')
assert 'byte_address<=offset+load_y*stride;' in s
s=s.replace('byte_address<=0;cache_sector<=0;', 'cache_sector<=0;')
s=s.replace('byte_address<=offset+load_y*stride;', '')
s=s.replace("byte_address<=byte_address+1'b1;",'')
needle=' // Synchronous RAM reads; memories deliberately have no reset.'
assert needle in s
s=s.replace(needle,''' // Keep the row-address load/increment separate from the pixel FSM.
 // This prevents sparse state enables being shared into its address DSP CE.
 always @(posedge clk or posedge rst)begin
  if(rst)byte_address<=0;
  else if(state[6])byte_address<=offset+load_y*stride;
  else if(state[9])byte_address<=byte_address+1'b1;
 end
'''+needle)
p.write_text(s,encoding='utf-8')
print('Isolated scale byte-address owner; no added pixel/SD wait')
