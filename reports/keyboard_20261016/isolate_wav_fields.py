from pathlib import Path
R=Path(__file__).resolve().parents[2];p=R/'src/modules/audio/audio_wav.v'
s=p.read_text(encoding='utf-8')
a=s.index('      if(kind==RIFF)begin');b=s.index('\n     end\n    end\n    state[5]',a)
s=s[:a]+'''      if(kind==RIFF)begin
       if(field==11)state<=RIFF_CHECK;
      end else if(kind==CHUNK)begin
       if(field==7)state<=CHUNK_CHECK;
      end else if(field==15)state<=FMT_CHECK;'''+s[b:]
for old,new in [
 ('chunk_size<=0;chunk_id<=0;', ''),
 ('riff_id<=0;riff_size<=0;wave_id<=0;rate<=0;byte_rate<=0;', ''),
 ('format<=0;channels<=0;align<=0;bits<=0;', '')]:
 assert old in s,old;s=s.replace(old,new,1)
fields=[('riff_id',4,'RIFF',0),('riff_size',4,'RIFF',4),('wave_id',4,'RIFF',8),
 ('chunk_id',4,'CHUNK',0),('chunk_size',4,'CHUNK',4),
 ('format',2,'FMT',0),('channels',2,'FMT',2),('rate',4,'FMT',4),
 ('byte_rate',4,'FMT',8),('align',2,'FMT',12),('bits',2,'FMT',14)]
block=''' // Independent fixed byte lanes avoid variable-part-select priority muxes.
 // All bytes are overwritten before their check state; reset behavior retained.
'''
for name,width,kind,offset in fields:
 block+=f' genvar g_{name};\n generate for(g_{name}=0;g_{name}<{width};g_{name}=g_{name}+1)begin:decode_{name}\n'
 block+=f'''  always @(posedge clk or posedge rst)begin
   if(rst){name}[g_{name}*8+:8]<=0;
   else if(state[4] && kind=={kind} && field==g_{name}+{offset})
    {name}[g_{name}*8+:8]<=q;
  end
 end endgenerate
'''
s=s.replace('endmodule',block+'endmodule');p.write_text(s,encoding='utf-8')
print('Isolated 36 WAV header byte lanes; state/sample/cache semantics unchanged')
