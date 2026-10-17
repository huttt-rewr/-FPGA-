"""Prepare a stage-two experiment outside frozen build inputs; install separately."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=ROOT/'src/modules/sd/sd_fat32.v'
s=p.read_text(encoding='utf-8')
def sub(a,b):
 global s
 assert a in s, a[:100]
 s=s.replace(a,b)
sub('parameter integer MAX_BMP=4,parameter integer ROOT_CLUSTER_LIMIT=4096',
'''parameter integer MAX_BMP=4,parameter integer ROOT_CLUSTER_LIMIT=4096,
 parameter integer INDEXED=0,parameter integer MAX_FILES=64,
 parameter integer COUNT_WIDTH=INDEXED?7:3''')
sub('output reg [2:0] bmp_count,output reg wav_found,','output reg [COUNT_WIDTH-1:0] bmp_count,output reg wav_found,')
sub('output [MAX_BMP*32-1:0] bmp_size,output reg [31:0] wav_size,','output [MAX_BMP*32-1:0] bmp_size,output [31:0] wav_size,')
sub('input bmp_req,input [2:0] bmp_file_idx,','input bmp_req,input [COUNT_WIDTH-1:0] bmp_file_idx,')
sub('input bmp_abort\n','''input bmp_abort,
 input [5:0] aud_file_idx,input aud_abort,output aud_idle,
 output reg [6:0] wav_count,output reg files_truncated
''')
sub('localparam [43:0]', 'localparam [44:0]')
sub("FAT_COMMIT=44'h80000000000;", "FAT_COMMIT=44'h80000000000,TABLE_READ=45'h100000000000;")
sub('reg [43:0] state;', 'reg [44:0] state;')
sub('reg store_bmp,store_wav;reg [2:0] store_index;', 'reg store_bmp,store_wav;reg [5:0] store_index;')
sub('reg [1:0] cursor_valid;reg [2:0] cursor_file;', 'reg [1:0] cursor_valid;reg [5:0] cursor_file[0:1];')
sub('reg [2:0] request_file;', 'reg [5:0] request_file;\n reg cancel_aud;\n wire cancel_audio=INDEXED && (cancel_aud || aud_abort);\n wire [63:0] descriptor;\n reg [6:0] total_files;\n assign aud_idle=state[18] && !aud_req;')
a=s.index(' generate for(k=0;k<MAX_BMP;')
b=s.index(' reg [7:0] disk_data;',a)
s=s[:a]+''' generate if(INDEXED)begin:indexed_files
  // A single 128x64 synchronous table, no reset of RAM contents. Two typed
  // address regions allow O(1) nth-image/nth-audio lookup; MAX_FILES limits
  // the combined number of accepted entries, not each region separately.
  (* ram_style="bram" *) reg [63:0] entries[0:127];
  reg [63:0] entry_q;
  always @(posedge clk)begin
   if(store_bmp || store_wav)entries[{store_wav,store_index}]<={store_cluster,store_size};
   entry_q<=entries[{owner,request_file}];
  end
  assign descriptor=entry_q;
  assign bmp_size=0;assign wav_size=0; // legacy parallel metadata not used
 end else begin:legacy_files
  for(k=0;k<MAX_BMP;k=k+1)begin:sizes
   assign bmp_size[k*32+:32]=image_size[k];
   always @(posedge clk or posedge rst)begin
    if(rst)begin image_cluster[k]<=0;image_size[k]<=0;end
    else if(store_bmp && store_index==k)begin image_cluster[k]<=store_cluster;image_size[k]<=store_size;end
   end
  end
  reg [31:0] legacy_wav_size;
  assign wav_size=legacy_wav_size;assign descriptor=0;
  always @(posedge clk or posedge rst)begin
   if(rst)begin wav_cluster<=0;legacy_wav_size<=0;end
   else if(store_wav)begin wav_cluster<=store_cluster;legacy_wav_size<=store_size;end
  end
 end endgenerate
'''+s[b:]
sub('owner && disk_valid && !disk_error;', 'owner && disk_valid && !disk_error && !cancel_audio;')
sub('owner && disk_end && !disk_error && final_count==512;', 'owner && disk_end && !disk_error && final_count==512 && !cancel_audio;')
sub('aud_error<=sd_init_done && owner && (', 'aud_error<=sd_init_done && owner && !cancel_audio && (')
sub('MAX_BMP>4 || ROOT_CLUSTER_LIMIT<1', '(!INDEXED && MAX_BMP>4) || MAX_FILES<1 || MAX_FILES>64 || ROOT_CLUSTER_LIMIT<1')
sub('bmp_count<=0;wav_found<=0;', 'bmp_count<=0;wav_found<=0;wav_count<=0;total_files<=0;files_truncated<=0;cancel_aud<=0;')
sub('cursor_valid<=0;cursor_file<=0;', 'cursor_valid<=0;cursor_file[0]<=0;cursor_file[1]<=0;')
sub('store_index<=bmp_count;', 'store_index<=(INDEXED && ext0=="W" && ext1=="A" && ext2=="V")?wav_count:bmp_count;')
sub('if(bmp_abort)begin', 'if(INDEXED && aud_abort)begin cursor_valid[1]<=0;cancel_aud<=1;end\n   if(bmp_abort)begin')
sub('&& bmp_count<MAX_BMP)begin','&& bmp_count<(INDEXED?MAX_FILES:MAX_BMP) && (!INDEXED || total_files<MAX_FILES))begin')
sub('store_bmp<=1;bmp_count<=bmp_count+1\'b1;', 'store_bmp<=1;bmp_count<=bmp_count+1\'b1;if(INDEXED)total_files<=total_files+1\'b1;')
sub('&& !wav_found)begin', '&& (INDEXED?(total_files<MAX_FILES):!wav_found))begin')
sub('store_wav<=1;wav_found<=1;', "store_wav<=1;wav_found<=1;wav_count<=wav_count+1'b1;if(INDEXED)total_files<=total_files+1'b1;")
sub('      end\n      default:;\n     endcase\n    end\n   end\n   case(1\'b1)', '''       if(INDEXED && total_files>=MAX_FILES &&
          ((ext0=="B" && ext1=="M" && ext2=="P") || (ext0=="W" && ext1=="A" && ext2=="V")))files_truncated<=1;
      end
      default:;
     endcase
    end
   end
   case(1'b1)''')
sub('mount_fat<=0;cancel_bmp<=0;', 'mount_fat<=0;cancel_bmp<=0;cancel_aud<=0;')
sub('owner<=aud_req;request_file<=bmp_file_idx;', '''owner<=aud_req;
      if(INDEXED)request_file<=aud_req?((aud_file_idx>=wav_count)?6'd0:aud_file_idx):((bmp_file_idx>=bmp_count)?6'd0:bmp_file_idx);
      else request_file<=bmp_file_idx;''')
sub('bmp_rel_sector;state<=STREAM_INIT;', 'bmp_rel_sector;state<=INDEXED?TABLE_READ:STREAM_INIT;')
sub('    state[19]:begin', '    state[44]:state<=STREAM_INIT; // synchronous descriptor read latency\n    state[19]:begin')
sub('request_size<=owner?wav_size:image_size[request_file[1:0]];', 'request_size<=INDEXED?descriptor[31:0]:(owner?wav_size:image_size[request_file[1:0]]);')
sub('(owner || cursor_file==request_file)', '(cursor_file[owner]==request_file)')
sub('working_cluster<=owner?wav_cluster:image_cluster[request_file[1:0]];', 'working_cluster<=INDEXED?descriptor[63:32]:(owner?wav_cluster:image_cluster[request_file[1:0]]);')
sub('else if(!owner && (cancel_bmp || bmp_abort))', 'else if(owner?cancel_audio:(cancel_bmp || bmp_abort))')
sub('if(!owner)cursor_file<=request_file;', 'cursor_file[owner]<=request_file;')
dest=ROOT/'reports/keyboard_20261016/stage2'
dest.mkdir(exist_ok=True)
(dest/'sd_fat32.v').write_text(s,encoding='utf-8')
print('Prepared experiment:',dest/'sd_fat32.v')
