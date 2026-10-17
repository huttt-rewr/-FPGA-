from pathlib import Path
R=Path(__file__).resolve().parents[2]
p=R/'src/modules/bmp/sd_card_bmp.v';s=p.read_text(encoding='utf-8')
assert 'reg images_present,images_multiple;' in s
s=s.replace('reg images_present,images_multiple;', '''reg images_present,images_multiple;
// Predecode the initialization branch before the frame-control priority mux.
// Launch paths still require live sd_init_done; no SD request is issued early.
reg waiting_for_init;
always @(posedge clk or posedge rst)begin
 if(rst)waiting_for_init<=1;
 else waiting_for_init<=!sd_init_done && !scan_done;
end''')
s=s.replace('end else if (!sd_init_done && !scan_done) begin',
 'end else if (waiting_for_init) begin')
p.write_text(s,encoding='utf-8')
p=R/'src/top.v';s=p.read_text(encoding='utf-8')
s=s.replace('wire media_truncated;wire player_display_valid;', '''wire media_truncated;wire player_display_valid;
reg committed_image_seen;reg [6:0] last_committed_image;
// Track commits separately from selection requests. An idle cycle before
// load_busy rises must not overwrite a newly requested file with the old frame.
always @(posedge sd_card_clk or posedge rst_sd)begin
 if(rst_sd)begin committed_image_seen<=0;last_committed_image<=0;end
 else if(player_display_valid)begin committed_image_seen<=1;last_committed_image<=media_image_index;end
end''')
s=s.replace('player_display_valid && media_image_count!=0 && !status_busy',
 'player_display_valid && (!committed_image_seen || media_image_index!=last_committed_image) && media_image_count!=0 && !status_busy')
old='reset_sync reset_vga(.clk(video_clk),.arst(rst_all | mode_video),.rst(rst_vga));'
assert old in s
s=s.replace(old,'''// VGA must run during initial EDID acquisition (mode_done=0). Afterwards
// both HDMI cores must remain reset throughout every runtime clock switch.
reset_sync reset_vga(.clk(video_clk),.arst(rst_all | mode_video | (mode_done && rst_video)),.rst(rst_vga));''')
s=s.replace('// Stage 1 request registers: consumers for direct file selection and runtime\n// display/slide-rate changes are introduced only after this foundation passes.',
 '// Shared control registers: file selection and runtime display/slide-rate requests.')
p.write_text(s,encoding='utf-8')
p=R/'src/modules/video/adaptive_video_clock.v';s=p.read_text(encoding='utf-8')
s=s.replace('// Select changes only during boot with ALL consumers held in reset for 4096\n// reference pixel cycles. Dedicated global switches select related 1x/5x pairs.',
 '// Boot and runtime selections hold consumers reset around the clock change\n// and for 4096 boot clocks afterwards. Dedicated muxes select related 1x/5x pairs.')
p.write_text(s,encoding='utf-8')
p=R/'sim/tb_video_mode_control.v';s=p.read_text(encoding='utf-8')
s=s.replace('wire video_reset,sd_reset;','wire video_reset,sd_reset,hdmi_vga_reset;')
s=s.replace(' reset_sync sr(sd,rst | !ready,sd_reset);',
 ' reset_sync sr(sd,rst | !ready,sd_reset);\n reset_sync vg(pixel,rst | mode | (done && video_reset),hdmi_vga_reset);')
s=s.replace('if(!video_reset || !sd_reset || ready || quiet_ticks<8)',
 'if(!video_reset || !sd_reset || !hdmi_vga_reset || ready || quiet_ticks<8)')
s=s.replace('check(!ready,"EDID gate");done=1;',
 'check(!ready,"EDID gate");check(!hdmi_vga_reset,"VGA EDID core can run before acquisition completes");done=1;')
s=s.replace('check(active==1 && !mode,"default VGA");',
 'check(active==1 && !mode && !hdmi_vga_reset,"default VGA and core release");')
s=s.replace('pending requests, restart','pending requests, restart, EDID boot exception and runtime HDMI reset')
p.write_text(s,encoding='utf-8')
p=R/'sim/tb_mode_reload.v';s=p.read_text(encoding='utf-8')
old=''' always @(posedge clk)if(!rst && shown && ic!=0 && !busy && !image_valid)
  image<=ii;'''
assert old in s
s=s.replace(old,''' reg committed_seen=0;reg [6:0] committed_index=0;
 always @(posedge clk)begin
  if(rst)begin committed_seen<=0;committed_index<=0;end
  else if(shown)begin
   if((!committed_seen || ii!=committed_index) && ic!=0 && !busy && !image_valid)image<=ii;
   committed_seen<=1;committed_index<=ii;
  end
 end''')
p.write_text(s,encoding='utf-8')
print('Kept initial VGA EDID acquisition live; held HDMI cores reset for runtime switches; expanded reset coverage')
