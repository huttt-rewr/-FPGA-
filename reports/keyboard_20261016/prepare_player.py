"""Stage-two player experiment; never changes active build inputs."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
s=(ROOT/'src/modules/bmp/sd_card_bmp.v').read_text(encoding='utf-8')
def sub(a,b):
 global s
 assert a in s,a[:120]
 s=s.replace(a,b)
sub('module sd_card_bmp #(', 'module sd_card_bmp #(\n    parameter integer INDEXED=0,parameter integer MAX_FILES=64,')
sub('output [3:0] audio_error_code\n', '''output [3:0] audio_error_code,
    input [7:0] image_select_index,audio_select_index,
    input image_select_valid,audio_select_valid,
    output [6:0] media_image_index,media_image_count,media_audio_index,media_audio_count,
    output media_truncated
''')
sub('reg [1:0] load_idx;', 'reg [5:0] load_idx;')
sub('wire [2:0] fat_count;', 'wire [(INDEXED?7:3)-1:0] fat_count;\nwire [6:0] fat_audio_count;wire fat_audio_idle;')
sub('sd_fat32 #(.MAX_BMP(MAX_BMP))', 'sd_fat32 #(.MAX_BMP(MAX_BMP),.INDEXED(INDEXED),.MAX_FILES(MAX_FILES))')
sub(".bmp_file_idx({1'b0,load_idx})", '.bmp_file_idx(INDEXED?{1\'b0,load_idx}:load_idx[2:0])')
sub('.aud_req(aud_req),.aud_rel_sector', '''.aud_req(aud_req),.aud_file_idx(audio_active),.aud_abort(audio_switching),.aud_idle(fat_audio_idle),
  .wav_count(fat_audio_count),.files_truncated(media_truncated),.aud_rel_sector''')
sub('assign fat_done=0;', 'assign fat_audio_count=0;assign fat_audio_idle=1;assign media_truncated=0;\n assign fat_done=0;')
sub('assign audio_stream_reset=rst || load_abort ||', 'assign audio_stream_reset=rst || load_abort || audio_switching ||')
sub('.rst(rst | load_abort),.sd_init_done', '.rst(rst | load_abort | audio_switching),.sd_init_done')
# Declare before instances: TD does not reliably resolve generate forward refs.
sub('wire [11:0] source_width,source_height;', '''wire [11:0] source_width,source_height;
reg [5:0] audio_active,audio_target;
reg audio_switching;
wire [5:0] selected_audio=(audio_select_index>=fat_audio_count)?6'd0:audio_select_index[5:0];
always @(posedge clk or posedge rst)begin
 if(rst)begin audio_active<=0;audio_target<=0;audio_switching<=0;end
 else if(INDEXED && fat_done)begin
  if(!audio_switching)begin
   if(audio_select_valid || selected_audio!=audio_active)begin audio_target<=selected_audio;audio_switching<=1;end
  end else if(audio_select_valid)audio_target<=selected_audio;
  else if(fat_audio_idle)begin audio_active<=audio_target;audio_switching<=0;end
 end
end
assign media_image_index={1'b0,img_idx};assign media_image_count=img_found_count;
assign media_audio_index={1'b0,audio_active};assign media_audio_count=fat_audio_count;
''')
sub('wire             scan_done;', 'wire scan_done,bmp_scan_done;\nassign scan_done=INDEXED?fat_done:bmp_scan_done;')
sub('wire             scan_found_valid;', 'wire scan_found_valid,bmp_scan_found_valid;\nassign scan_found_valid=INDEXED?1\'b0:bmp_scan_found_valid;')
sub('reg [2:0]        img_found_count;', 'reg [6:0]        img_found_count;')
sub('reg [1:0]        img_idx;', 'reg [5:0]        img_idx;')
sub('wire [1:0] next_from_current;', '''wire [5:0] next_from_current;
reg direct_pending;reg [5:0] direct_index;
wire [5:0] requested_next=direct_pending?direct_index:next_from_current;''')
sub('img_found_count[1:0] - 2\'d1', 'img_found_count[5:0] - 6\'d1')
sub('function [1:0] next_index_limited;', 'function [5:0] next_index_limited;')
a=s.index('    input [1:0] cur;',s.index('function [5:0] next_index_limited;'))
b=s.index('endfunction',a)
s=s[:a]+'''    input [5:0] cur;
    input [6:0] count;
    begin
        next_index_limited=({1'b0,cur}+7'd1>=count)?6'd0:cur+6'd1;
    end
'''+s[b:]
sub('assign status_index = img_idx;', 'assign status_index = img_idx[1:0];')
sub('assign status_count = img_found_count;', 'assign status_count = img_found_count[2:0];')
# Reset direct command together with the existing pending mailbox.
sub('next_req_pending      <= 1\'b0;', "next_req_pending      <= 1'b0;direct_pending<=0;direct_index<=0;")
sub('            if (scan_found_valid) status_error', '            if(INDEXED && fat_done)img_found_count<=fat_count;\n            if (scan_found_valid) status_error')
sub('begin next_req_pending <= 1\'b1; prev_requested <= cmd_prev; end', '''begin next_req_pending <= 1'b1; prev_requested <= cmd_prev;direct_pending<=0;end
                if(INDEXED && image_select_valid && scan_done && img_found_count!=0)begin
                    direct_index<=(image_select_index>=img_found_count)?6'd0:image_select_index[5:0];
                    direct_pending<=1;next_req_pending<=1;
                end''')
sub('load_idx         <= 2\'d0;\n                    load_sector      <= img_sector0;', '''load_idx         <= INDEXED?((image_select_index>=img_found_count)?6'd0:image_select_index[5:0]):6'd0;
                    load_sector      <= INDEXED?0:img_sector0;''')
sub('load_idx         <= next_from_current;', 'load_idx         <= requested_next;')
sub('load_sector      <= sector_lut(next_from_current);', 'load_sector      <= INDEXED?0:sector_lut(requested_next[1:0]);')
sub("next_req_pending <= 1'b0;", "next_req_pending <= 1'b0;direct_pending<=0;")
sub('.fs_bmp_count(fat_count)', ".fs_bmp_count(INDEXED?3'd0:fat_count[2:0])")
sub('.scan_done              (scan_done)', '.scan_done              (bmp_scan_done)')
sub('.scan_found_valid       (scan_found_valid)', '.scan_found_valid       (bmp_scan_found_valid)')
# Older Verilog frontends reject forward references in a declaration initializer
# or generate body. Move shared declarations ahead of those uses.
for declaration in ('wire fat_done,fat_error,fat_wav_found;',
 'wire [6:0] fat_audio_count;wire fat_audio_idle;',
 'reg [6:0]        img_found_count;',
 'reg [5:0]        img_idx;'):
    assert declaration in s
    s=s.replace(declaration,'')
    s=s.replace('wire [11:0] source_width,source_height;',declaration+'\nwire [11:0] source_width,source_height;')
(ROOT/'reports/keyboard_20261016/stage2/sd_card_bmp.v').write_text(s,encoding='utf-8')
print('Prepared staged indexed player')
