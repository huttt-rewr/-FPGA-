"""Install targeted phase-two timing/resource changes after the current run ends."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=ROOT/'src/modules/sd/sd_fat32.v';s=p.read_text(encoding='utf-8')
def sub(a,b):
 global s
 assert a in s,a[:100]
 s=s.replace(a,b)
sub('localparam [44:0]','localparam [46:0]')
sub("TABLE_READ=45'h100000000000;", "TABLE_READ=47'h100000000000,TABLE_HIGH=47'h200000000000,TABLE_LATCH=47'h400000000000;")
sub('reg [44:0] state;', 'reg [46:0] state;')
a=s.index('  // A single 128x64');b=s.index('  assign bmp_size=0;',a)
s=s[:a]+'''  // Interleave two 32-bit words in one 256-deep RAM rather than a
  // shallow 64-bit table. This uses fewer physical BRAM columns on EG4S20.
  (* ram_style="bram" *) reg [31:0] entries[0:255];
  reg [31:0] entry_q,low_q,high_q;
  reg write_high;reg [6:0] write_address;reg [31:0] cluster_hold;
  always @(posedge clk)begin
   write_high<=sd_init_done && !rst && (store_bmp || store_wav);
   write_address<={store_wav,store_index};cluster_hold<=store_cluster;
   if(!rst && sd_init_done && (store_bmp || store_wav))entries[{store_wav,store_index,1'b0}]<=store_size;
   else if(write_high && !rst && sd_init_done)entries[{write_address,1'b1}]<=cluster_hold;
   entry_q<=entries[{owner,request_file,state[45]}];
   if(state[45])low_q<=entry_q;
   if(state[46])high_q<=entry_q;
  end
  assign descriptor={high_q,low_q};
'''+s[b:]
sub('state[44]:state<=STREAM_INIT; // synchronous descriptor read latency',
'''state[44]:state<=TABLE_HIGH;
    state[45]:state<=TABLE_LATCH;
    state[46]:state<=STREAM_INIT; // two synchronous descriptor words''')
# Counters consume already registered acceptance events, not the directory
# qualifier -> capacity -> parallel increment decode in the metadata process.
sub(' reg [6:0] total_files;', ''' reg [6:0] total_files;
 reg truncate_event;
 always @(posedge clk or posedge rst)begin
  if(rst)begin bmp_count<=0;wav_found<=0;wav_count<=0;total_files<=0;files_truncated<=0;end
  else if(!sd_init_done)begin bmp_count<=0;wav_found<=0;wav_count<=0;total_files<=0;files_truncated<=0;end
  else begin
   if(store_bmp)bmp_count<=bmp_count+1'b1;
   if(store_wav)begin wav_count<=wav_count+1'b1;wav_found<=1;end
   if(INDEXED && (store_bmp || store_wav))total_files<=total_files+1'b1;
   if(truncate_event)files_truncated<=1;
  end
 end''')
sub('bmp_count<=0;wav_found<=0;wav_count<=0;total_files<=0;files_truncated<=0;cancel_aud<=0;', 'truncate_event<=0;cancel_aud<=0;')
# The previous replacement also matched the new block only when cancel_aud is
# present, so the standalone counter process remains the sole register owner.
sub('store_bmp<=0;store_wav<=0;', 'store_bmp<=0;store_wav<=0;truncate_event<=0;')
sub("store_bmp<=1;bmp_count<=bmp_count+1'b1;if(INDEXED)total_files<=total_files+1'b1;", 'store_bmp<=1;')
sub("store_wav<=1;wav_found<=1;wav_count<=wav_count+1'b1;if(INDEXED)total_files<=total_files+1'b1;", 'store_wav<=1;')
sub(')))files_truncated<=1;', ')))truncate_event<=1;')
p.write_text(s,encoding='utf-8')
p=ROOT/'src/modules/audio/audio_wav.v';s=p.read_text(encoding='utf-8')
s=s.replace('localparam [14:0]','localparam [15:0]').replace('reg [14:0] state;','reg [15:0] state;')
s=s.replace("CHUNK_CLASSIFY=15'h4000;","CHUNK_CLASSIFY=15'h4000,FMT_APPLY=16'h8000;")
s=s.replace(' reg resume_space;', ''' reg format_bad;
 always @(posedge clk or posedge rst)begin
  if(rst)format_bad<=0;
  else format_bad<=format!=1 || channels!=1 || rate!=48000 || byte_rate!=96000 || align!=2 || bits!=16;
 end
 reg resume_space;''')
s=s.replace('    state[7]:begin\n     if(format!=1 || channels!=1 || rate!=48000 || byte_rate!=96000 || align!=2 || bits!=16)',
'''    state[7]:state<=FMT_APPLY; // let the final fmt byte reach format_bad
    state[15]:begin
     if(format_bad)''')
p.write_text(s,encoding='utf-8')
p=ROOT/'src/top.v';s=p.read_text(encoding='utf-8')
# Mode metadata itself need not reset asynchronously: all consumers stay reset
# for 4096 boot cycles. Keep two local samples and synchronously initialize;
# this removes a redundant raw-reset receiver, not a timing exception.
a=s.index('// These synchronizers must settle');b=s.index('\n\n\nwire rst_sd',a)
s=s[:a]+'''// Metadata is sampled while consumers are held reset for 4096 boot cycles.
// It needs no asynchronous reset pins: initialize synchronously and allow the
// two-stage samples to settle before releasing the actual consumers.
always @(posedge video_clk)begin
 if(rst_all)begin mode_vff<=0;edid_good_vff<=0;end
 else begin mode_vff<={mode_vff[0],mode_800};edid_good_vff<={edid_good_vff[0],edid_good};end
end
always @(posedge sd_card_clk)begin
 if(rst_all)mode_sff<=0;else mode_sff<={mode_sff[0],mode_800};
end
always @(posedge ext_mem_clk)begin
 if(rst_all)mode_mff<=0;else mode_mff<={mode_mff[0],mode_800};
end
'''+s[b:]
p.write_text(s,encoding='utf-8')
print('Installed interleaved BRAM, registered count events, fmt compare stage, synchronous mode metadata initialization')
