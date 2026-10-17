from pathlib import Path
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent
s=(R/'sim/tb_audio_stream_flush.v').read_text(encoding='utf-8')
s=s.replace('reg clk=0,rst=1,flush=1,valid=0;', 'reg clk=0,rst=1,flush=1,valid=0,mute=0,zero_volume=0;')
s=s.replace('clk,rst,stream_rst,valid,sample,sample,ov,ol,orr);', 'clk,rst,stream_rst | mute | zero_volume,valid,sample,sample,ov,ol,orr);')
needle='  if(errors==0)$display('
assert needle in s
s=s.replace(needle,'''  // An optional echo profile must obey hard mute and volume zero too.
  for(n=0;n<22;n=n+1)send_sample(24'sd1000000);
  mute=1;
  for(n=0;n<12;n=n+1)begin send_sample(24'sd1000000);check(ol==0,"mute suppresses an existing echo tail");end
  mute=0;
  for(n=0;n<22;n=n+1)begin send_sample(0);check(ol==0,"unmute has no old echo history");end
  for(n=0;n<22;n=n+1)send_sample(24'sd1000000);
  zero_volume=1;
  for(n=0;n<12;n=n+1)begin send_sample(24'sd1000000);check(ol==0,"volume zero also suppresses echo");end
  zero_volume=0;
  for(n=0;n<22;n=n+1)begin send_sample(0);check(ol==0,"volume restore has no old echo");end
'''+needle)
s=s.replace('scheduled silence and valid preserved','scheduled silence and valid preserved; mute/volume0 clear old echo')
(O/'tb_audio_stream_flush_mute.v').write_text(s,encoding='utf-8')
print('Prepared nonzero effects mute/volume-zero coverage')
