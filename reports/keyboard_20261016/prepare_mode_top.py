"""Prepare runtime mode integration without mutating an in-progress build."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
s=(ROOT/'src/top.v').read_text(encoding='utf-8')
def sub(a,b):
 global s
 assert a in s,a[:80]
 s=s.replace(a,b)
sub('wire mode_800,mode_done,mode_fallback;', 'wire mode_800,mode_done,mode_fallback,edid_mode_800;')
sub('reg mode_ready;\nreg [12:0] settle_count;', 'wire mode_ready;wire [1:0] active_res_mode,requested_mode_boot;')
a=s.index('always @(posedge boot_clk or posedge rst_boot)begin\n if(rst_boot)begin mode_ready');b=s.index('\n\n// Upgrade control',a)
s=s[:a]+'''// Runtime switching is controlled in the permanent EDID boot clock domain.
cdc_snapshot #(.WIDTH(2)) mode_request_cdc(.src_clk(sd_card_clk),.src_rst(rst_controls),
 .src_data(res_mode),.dst_clk(boot_clk),.dst_rst(rst_boot),.dst_data(requested_mode_boot));
video_mode_control mode_control(.clk(boot_clk),.rst(rst_boot),.edid_done(mode_done),
 .supports_800(edid_mode_800),.requested_mode(requested_mode_boot),
 .ready(mode_ready),.mode_800(mode_800),.active_mode(active_res_mode),.fallback(mode_fallback));
'''+s[b:]
# EDID remains an independent capability result, never OR'ed with the request.
sub('.mode_800(mode_800),.fallback(mode_fallback)', '.mode_800(edid_mode_800),.fallback()')
# Video HDMI cores may restart during a runtime mode change; boot negotiation
# is retained until a global/watchdog reset rather than parsing accidental
# partial traffic from a now unrelated pixel clock.
sub('edid_valid_boot<=edid_valid;edid_data_boot<=edid_data;', 'edid_valid_boot<=edid_valid && !mode_done;edid_data_boot<=edid_data;')
sub('wire rst_sd,rst_mem,rst_video,rst_write;', '''wire rst_sd,rst_mem,rst_video,rst_write;
wire rst_controls;
reset_sync reset_controls(.clk(sd_card_clk),.arst(rst_all),.rst(rst_controls));''')
sub('ps2_keyboard keyboard(.clk(sd_card_clk),.rst(rst_sd)', 'ps2_keyboard keyboard(.clk(sd_card_clk),.rst(rst_controls)')
sub('ps2_controls keyboard_events(.clk(sd_card_clk),.rst(rst_sd)', 'ps2_controls keyboard_events(.clk(sd_card_clk),.rst(rst_controls)')
sub('always @(posedge sd_card_clk or posedge rst_sd)begin\n if(rst_sd)begin image_index', 'always @(posedge sd_card_clk or posedge rst_controls)begin\n if(rst_controls)begin image_index')
sub(')) buttons(.clk(sd_card_clk),.rst(rst_sd)', ')) buttons(.clk(sd_card_clk),.rst(rst_controls)')
sub('switch_controls switches(.clk(sd_card_clk),.rst(rst_sd)', 'switch_controls switches(.clk(sd_card_clk),.rst(rst_controls)')
sub('  if(kb_image_select)image_index', '''  if(!rst_sd && media_image_count!=0 && !status_busy && !kb_image_select && !media_image_select)
   image_index<={1'b0,media_image_index}; // resume committed image after R
  if(kb_image_select)image_index''')
(ROOT/'reports/keyboard_20261016/top_mode_candidate.v').write_text(s,encoding='utf-8')
print('Prepared boot-domain mode controller + persistent controls reset + EDID capability separation')
