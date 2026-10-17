from pathlib import Path
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent
s=(R/'sim/tb_file_osd.v').read_text(encoding='utf-8')
s=s.replace('integer errors=0;', 'integer errors=0;reg [3:0] rate=2;reg limited=0;reg [1:0] res=1;')
s=s.replace('.FILE_UI(1)', '.FILE_UI(1),.RATE_UI(1)')
s=s.replace('.file_table_truncated(truncated));', '.file_table_truncated(truncated),.slide_rate_mode(rate),.slide_rate_limited(limited),.requested_res_mode(res));')
needle='  if(errors==0)$display('
assert needle in s
s=s.replace(needle,'''  y=16;char_at(24,"T");char_at(25,"A");char_at(26,"R");char_at(27,"G");
  char_at(28,"E");char_at(29,"T");char_at(30,":");char_at(31,"0");char_at(32,"5");char_at(33," ");
  rate=5;limited=1;char_at(31,"3");char_at(32,"0");char_at(33,"L");
  rate=0;limited=0;char_at(31,"0");char_at(32,"1");char_at(33," ");
  char_at(35,"R");char_at(36,":");char_at(37,"1");res=0;char_at(37,"0");res=2;char_at(37,"2");
'''+needle)
s=s.replace('truncation,busy/error','truncation,busy/error,TARGET05/30/01 and limited flag')
(O/'tb_file_osd_rate.v').write_text(s,encoding='utf-8')
print('Prepared target/limited OSD assertions alongside full file-count coverage')
