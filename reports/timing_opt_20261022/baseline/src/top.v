
module top(
    input uart_rx_pin,
    output uart_tx_pin,
    input ir_rx_pin,
    input ps2_clk,
    input ps2_data,
    input                       clk,
    input                       rst_n,
    input                       key1,           // 手动下一张
    input                       key2,           // 自动播放 开/关
    input                       key3,           // B1: select PLAY/BRIGHT/CONTRAST
    input [3:0]                 sw,             // ON=low: captions, scroll, mode[1:0]

	output [5:0]                seg_sel,
	output [7:0]                seg_data,

    // HDMI TMDS
    output                      HDMI_CLK_P,
    output                      HDMI_D2_P,
    output                      HDMI_D1_P,
    output                      HDMI_D0_P,

    // HDMI DDC
    output                      HDMI_DDC_SCL,
    inout                       HDMI_DDC_SDA,

    // TF native four-bit SDR, no SPI fallback in this profile.
    output SD_CLK,
    inout SD_CMD,
    inout SD_DAT0,
    inout SD_DAT1,
    inout SD_DAT2,
    inout SD_DAT3
);

parameter MEM_DATA_BITS = 32;
parameter ADDR_BITS     = 21;
parameter FRAME_PIXELS  = 21'd307200;   // 640*480
parameter BUF0_ADDR     = 21'd0;
parameter BUF1_ADDR     = FRAME_PIXELS;
parameter AVF_ENABLED=1;
parameter AUTO_ENHANCE_ENABLED=1;
parameter TRANSITIONS_ENABLED=1;
parameter CHINESE_ENABLED=1;
parameter DEBUG_ENABLED = 1; // 0 removes snapshots and extra seven-segment logic.
// Declare shared clocks, resets and mode payloads before their first use.
wire sd_card_clk;
wire movie_mode,movie_sd,movie_video,media_restart_request;
wire ext_mem_clk;
wire ext_mem_clk_sft;
wire video_clk;
wire hdmi_5x_clk;
wire rst_sd,rst_mem,rst_video,rst_write;
wire rst_controls;
wire tx_overflow,video_overflow;
wire vs;
(* async_reg="true" *) reg [1:0] mode_vff,mode_sff,mode_mff;
(* async_reg="true" *) reg [1:0] edid_good_vff;
wire mode_video=mode_vff[1],mode_sd=mode_sff[1],mode_mem=mode_mff[1];
(* keep="true" *) reg [7:0] image_index,audio_index;
(* keep="true" *) reg [1:0] res_mode;
(* keep="true" *) reg [3:0] fps_mode;
wire menu_open,gamma_enable,debug_enable;
wire [2:0] menu_item;
wire [1:0] debug_page;
wire [19:0] debug_mem_status;
wire [10:0] debug_read_status;
wire [3:0] debug_sd_status;
wire [23:0] debug_word;
wire [7:0] watchdog_resets,watchdog_resets_sd;
reg [7:0] frame_ui;
reg [1:0] frame_audio_status;
wire wav_sample_valid,wav_error,wav_ready,audio_queue_reset;
wire [23:0] wav_sample,audio_fifo_data;
wire audio_fifo_full,audio_fifo_empty,audio_fifo_read,audio_underflow;
wire [10:0] audio_wr_used,audio_rd_used;
wire audio_sample_room;
audio_fifo_room audio_admission(.clk(sd_card_clk),.rst(rst_sd | audio_queue_reset),
 .full(audio_fifo_full),.used(audio_wr_used),.sample_ready(audio_sample_room));
wire [1:0] audio_stream_video;
wire [3:0] wav_error_code,audio_error_code_video,audio_last_error;
wire audio_pcm_valid;
reg [3:0] frame_audio_error_code;
reg frame_audio_underflow;
wire gamma_vs,gamma_de;
wire [9:0] gamma_x,gamma_y;
wire [23:0] gamma_rgb;
wire mode_800,mode_done,mode_fallback,edid_mode_800;
wire boot_clk,rst_boot;
wire mode_ready;wire [1:0] active_res_mode,requested_mode_boot;
wire [15:0] output_width=mode_sd?16'd800:16'd640;
wire [15:0] output_height=mode_sd?16'd600:16'd480;
wire [20:0] output_pixels=mode_mem?21'd480000:21'd307200;
// Fixed non-overlapping slots sized for the maximum supported frame.
wire [20:0] buffer1=21'd480000;
// Runtime switching is controlled in the permanent EDID boot clock domain.
cdc_snapshot #(.WIDTH(2)) mode_request_cdc(.src_clk(sd_card_clk),.src_rst(rst_controls),
 .src_data(res_mode),.dst_clk(boot_clk),.dst_rst(rst_boot),.dst_data(requested_mode_boot));
video_mode_control mode_control(.clk(boot_clk),.rst(rst_boot),.edid_done(mode_done),
 .supports_800(edid_mode_800),.requested_mode(movie_mode?2'd1:requested_mode_boot),
 .ready(mode_ready),.mode_800(mode_800),.active_mode(active_res_mode),.fallback(mode_fallback));


// Upgrade control and status signals.
(* async_reg="true" *) reg [1:0] video_overflow_sd;
always @(posedge sd_card_clk or posedge rst_sd) begin
    if (rst_sd) video_overflow_sd <= 0;
    else video_overflow_sd <= {video_overflow_sd[0],video_overflow};
end
wire cmd_next,cmd_prev,cmd_toggle;
wire pc_next,pc_prev,pc_toggle;
wire ir_vol_up,ir_vol_dn,ir_mute,ir_bri_up,ir_bri_dn,ir_con_up,ir_con_dn;
wire ir_osd_toggle,ir_test_toggle,ir_transition_toggle;
wire [23:0] remote_time_bcd;
wire [7:0] remote_time_seq;
wire remote_time_set;
wire [32:0] time_video;
wire auto_enh_en,auto_enh_video,slide_enable,zh_enable,large_clock;
wire [1:0] album_video;
wire slide_next;
wire zh_vs,zh_de;wire [23:0] zh_rgb;wire [9:0] zh_x,zh_y;
wire ae_vs,ae_de;wire [9:0] ae_x,ae_y;wire [23:0] ae_rgb;
wire pixel_write_ready;
wire [11:0] image_width,image_height;
wire [3:0] contrast;
wire [1:0] edit_mode;
wire adjusted_vs,adjusted_de;
wire [9:0] adjusted_x,adjusted_y;
wire [4:0] volume;
wire mute,osd_enable,test_pattern;
wire kb_next,kb_prev,kb_toggle,kb_vol_up,kb_vol_dn,kb_mute,kb_osd,kb_res,kb_fps;
wire kb_image_select,kb_audio_select,kb_audio_pending;
wire [3:0] kb_digit;
wire [7:0] kb_scan_code;
wire kb_valid,kb_release,kb_extended,kb_error;
wire board_next,board_toggle;
reg osd_on;
reg media_image_select,media_audio_select;
wire [6:0] media_image_index,media_image_count,media_audio_index,media_audio_count;
wire media_truncated,rate_limited;wire [6:0] rate_video;reg [6:0] frame_rate;wire player_display_valid;
reg committed_image_seen;reg [6:0] last_committed_image;
// Track commits separately from selection requests. An idle cycle before
// load_busy rises must not overwrite a newly requested file with the old frame.
always @(posedge sd_card_clk or posedge rst_sd)begin
 if(rst_sd)begin committed_image_seen<=0;last_committed_image<=0;end
 else if(player_display_valid)begin committed_image_seen<=1;last_committed_image<=media_image_index;end
end
wire [28:0] media_video;
reg [28:0] frame_media;
wire [1:0] transition_mode,slogan_select,sw_transition_mode;
reg [1:0] ir_transition_offset,last_sw_transition;
reg test_pattern_reg;
wire captions_enable,scroll_enable;
wire signed [7:0] brightness;
wire status_auto,status_busy,status_error;
wire [1:0] status_index;
wire [2:0] status_count;
wire commit_req,commit_ack,vblank,visible;
wire [1:0] commit_buffer,active_buffer;

wire memory_underflow,memory_overflow,memory_frame_invalid;
(* async_reg="true" *) reg [1:0] memory_overflow_video;
always @(posedge video_clk or posedge rst_video) begin
 if(rst_video) memory_overflow_video<=0;
 else memory_overflow_video<={memory_overflow_video[0],memory_overflow};
end
wire [23:0] osd_rgb,enhanced_rgb,source_rgb,transition_rgb,caption_rgb;
wire transition_vs,transition_de,caption_vs,caption_de;
wire osd_vs,osd_de;
wire game_vs,game_de,game_on,game_tick,game_over;
wire [23:0] game_rgb;wire [7:0] game_score;
wire kb_game_on,kb_held_up,kb_held_down,kb_held_left,kb_held_right;
wire [4:0] game_controls_video;wire [1:0] game_dir;
wire [9:0] game_x,game_y;
wire [2:0] running_effect;
wire [5:0] fade_level;
wire [9:0] slide_offset;
wire transition_busy;
wire [9:0] pixel_x,pixel_y;
wire [23:0] audio_left,audio_right;
wire audio_valid,edid_done,edid_good;
wire [69:0] status_video;
wire [69:0] status_source={wav_error,wav_ready,debug_page,debug_enable,gamma_enable,menu_item,menu_open,image_height,image_width,edit_mode,contrast,transition_mode,captions_enable,scroll_enable,slogan_select,
    (status_error | tx_overflow | video_overflow_sd[1]),status_busy,status_count,status_index,
    status_auto,test_pattern,brightness,osd_enable,mute,volume};
wire [4:0] video_volume=status_video[4:0];
wire video_mute=status_video[5];
wire video_osd=status_video[6];
wire signed [7:0] video_brightness=status_video[14:7];
wire video_pattern=status_video[15];
wire video_auto=status_video[16];
wire [1:0] video_index=status_video[18:17];
wire [2:0] video_count=status_video[21:19];
wire video_busy=status_video[22];
wire video_error=status_video[23];
wire [1:0] video_slogan=status_video[25:24];
wire video_scroll=status_video[26];
wire video_captions=status_video[27];
wire [1:0] video_effect=status_video[29:28];

reg signed [7:0] frame_brightness;
reg [3:0] frame_contrast;
reg [1:0] frame_edit_mode;
reg [11:0] frame_source_width,frame_source_height;
reg settings_vs_d;
reg frame_osd;
always @(posedge video_clk or posedge rst_video)begin
 if(rst_video)begin
  settings_vs_d<=1;frame_brightness<=0;frame_contrast<=4;frame_edit_mode<=0;frame_osd<=1;
  frame_source_width<=0;frame_source_height<=0;
  frame_ui<=0;frame_audio_status<=0;frame_audio_error_code<=0;frame_audio_underflow<=0;frame_media<=0;frame_rate<=0;
 end else begin
  settings_vs_d<=vs;
  if(settings_vs_d && !vs)begin
   frame_osd<=video_osd;
   frame_brightness<=video_brightness;frame_contrast<=status_video[33:30];
   frame_edit_mode<=status_video[35:34];
   frame_source_width<=status_video[47:36];frame_source_height<=status_video[59:48];
   frame_ui<=status_video[67:60];frame_audio_status<=status_video[69:68];
   frame_audio_error_code<=audio_last_error;frame_audio_underflow<=audio_underflow;
   frame_media<=media_video;frame_rate<=rate_video;
  end
 end
end
wire Sdr_init_done;
wire Sdr_init_ref_vld;
wire Sdr_busy;



wire hs;
wire de;

wire [23:0] vout_data_raw;
wire [23:0] vout_data;

wire [3:0]  state_code;
wire [6:0]  seg_data_0;

wire        video_read_req;
wire        video_read_req_ack;
wire        video_read_en;
wire [31:0] video_read_data;

wire        sd_card_write_en;
wire [31:0] sd_card_write_data;
wire        sd_card_write_req;
wire        sd_card_write_req_ack;
wire        frame_write_finish;
reg         frame_write_toggle_mem;

wire [1:0]  write_buf_idx;
wire [1:0]  disp_buf_idx;

wire App_rd_en;
wire [ADDR_BITS-1:0] App_rd_addr;
wire Sdr_rd_en;
wire [MEM_DATA_BITS-1:0] Sdr_rd_dout;
wire App_wr_en;
wire [ADDR_BITS-1:0] App_wr_addr;
wire [MEM_DATA_BITS-1:0] App_wr_din;
wire [3:0] App_wr_dm;

wire hs_0;
wire vs_0;
wire de_0;

// HDMI 1.4b 相关
wire        axis_s_user;
wire        axis_s_valid;
wire        axis_s_last;
wire [23:0] axis_s_data;
wire        axis_s_ready;

wire        edid_trig;
wire        edid_valid;
wire [7:0]  edid_data;
reg edid_valid_boot;
reg [7:0] edid_data_boot;
// EDID transfer occurs only before the clock selection (both domains 25MHz).
// A local input stage also keeps data decode off the cross-clock timing path.
always @(posedge boot_clk or posedge rst_boot)begin
 if(rst_boot)begin edid_valid_boot<=0;edid_data_boot<=0;end
 else begin edid_valid_boot<=edid_valid && !mode_done;edid_data_boot<=edid_data;end
end

wire [9:0]  tmds_ch0_data;
wire [9:0]  tmds_ch1_data;
wire [9:0]  tmds_ch2_data;
wire [9:0]  tmds_clk_data;

// 统一复位：TF 图像链路 + HDMI 链路
wire sys_pll_lock;
wire video_pll_lock;
wire rst_all;
// Mode payload settles while all consumers are reset; each domain gets local
// synchronized copies well before mode_ready releases its reset synchronizer.

// Metadata is sampled while consumers are held reset for 4096 boot cycles.
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




reset_sync reset_controls(.clk(sd_card_clk),.arst(rst_all),.rst(rst_controls));
reset_sync reset_writer(.clk(ext_mem_clk),.arst(rst_all | !mode_ready | status_error),.rst(rst_write));
// 10 ms after BOTH PLLs lock; frame heartbeat timeout is 2 seconds.
// This fixed boot clock supervisor is outside its own reset feedback.
reg frame_heartbeat,heartbeat_vs_d;
always @(posedge video_clk or posedge rst_video)begin
 if(rst_video)begin frame_heartbeat<=0;heartbeat_vs_d<=1;end
 else begin
  heartbeat_vs_d<=vs_0;
  if(heartbeat_vs_d && !vs_0)frame_heartbeat<=~frame_heartbeat;
 end
end
board_supervisor supervisor(.clk(boot_clk),
 .arst(!rst_n || !sys_pll_lock || !video_pll_lock || media_restart_request),
 .enable(mode_ready),.heartbeat_toggle(frame_heartbeat),
 .reset_request(rst_all),.watchdog_resets(watchdog_resets));
reset_sync reset_sd(.clk(sd_card_clk),.arst(rst_all | !mode_ready),.rst(rst_sd));
reset_sync reset_mem(.clk(ext_mem_clk),.arst(rst_all | !mode_ready),.rst(rst_mem));
reset_sync reset_video(.clk(video_clk),.arst(rst_all | !mode_ready),.rst(rst_video));

reset_sync reset_boot(.clk(boot_clk),.arst(rst_all),.rst(rst_boot));

// Keep the system/SDRAM clock configuration; negotiate video at boot.
sys_pll sys_pll_m0(
    .refclk     (clk),
    .reset      (1'b0),
    .extlock    (sys_pll_lock),
    .clk0_out   (sd_card_clk),
    .clk1_out   (ext_mem_clk),
    .clk2_out   (ext_mem_clk_sft)
);

adaptive_video_clock video_pll_m0(.refclk(clk),.reset(1'b0),.mode_800(mode_800),
 .locked(video_pll_lock),.boot_clk(boot_clk),.pixel_clk(video_clk),.serial_clk(hdmi_5x_clk));

// mem_clk 域把 write_finish 单拍转成 toggle，供 sd_card_clk 域可靠同步
always @(posedge ext_mem_clk or posedge rst_mem) begin
    if (rst_mem)
        frame_write_toggle_mem <= 1'b0;
    else if (frame_write_finish)
        frame_write_toggle_mem <= ~frame_write_toggle_mem;
end

// Boot selection is latched before the supervisor releases media resets.

wire boot_select_rst_n=rst_n && sys_pll_lock && video_pll_lock;
wire media_select_valid,media_select_movie;
wire button_select_valid,button_select_movie;
generate if(AVF_ENABLED)begin: avf_selection
media_keyboard_request media_keys(.clk(sd_card_clk),.rst_n(boot_select_rst_n),.controls_reset(rst_controls),
 .scan_code(kb_scan_code),.key_valid(kb_valid),.key_release(kb_release),
 .key_extended(kb_extended),.receive_error(kb_error),
 .select_valid(media_select_valid),.select_movie(media_select_movie));
media_button_request board_media_keys(.clk(boot_clk),.rst_n(boot_select_rst_n),
 .key1_n(key1),.key2_n(key2),.movie_mode(movie_mode),
 .select_valid(button_select_valid),.select_movie(button_select_movie));
boot_media_select #(.DEFAULT_MOVIE(1),.RUNTIME_SELECT(1)) media_select(
 .clk(boot_clk),.rst_n(boot_select_rst_n),.key1_n(key1),.movie_mode(movie_mode),
 .select_valid(media_select_valid || button_select_valid),
 .select_movie(button_select_valid?button_select_movie:media_select_movie),
 .restart_request(media_restart_request));
end else begin: photo_only_selection
 assign movie_mode=0;assign media_restart_request=0;
end endgenerate
(* async_reg="true" *) reg [1:0] movie_sd_ff,movie_video_ff;
always @(posedge sd_card_clk or negedge rst_n)begin
 if(!rst_n)movie_sd_ff<=0;else movie_sd_ff<={movie_sd_ff[0],movie_mode};
end
always @(posedge video_clk or negedge rst_n)begin
 if(!rst_n)movie_video_ff<=0;else movie_video_ff<={movie_video_ff[0],movie_mode};
end
assign movie_sd=movie_sd_ff[1];assign movie_video=movie_video_ff[1];
wire movie_req,movie_valid,movie_end,movie_error,movie_ready;
wire [31:0] movie_sector;wire [7:0] movie_data;
wire av_playing,av_error,av_ended,av_busy,av_ack,av_visible,av_buffering;
wire av_publish,av_bank,av_we,av_write_req,av_write_en,av_valid;
wire [10:0] av_address;wire [15:0] av_data;
wire [31:0] av_write_data;wire [1:0] av_write_bank,av_active;
wire [3:0] av_state;wire [23:0] av_left,av_right;wire av_high_quality;
wire rst_movie_sd,rst_movie_video,rst_photo_video;
reg [6:0] movie_index;
wire [6:0] movie_count;
reg movie_restart_toggle;
(* async_reg="true" *) reg [1:0] movie_restart_video_ff;
(* async_reg="true" *) reg movie_ended_d;
wire movie_restart_video_pulse=movie_restart_video_ff[1] ^ movie_restart_video_ff[0];
wire movie_end_video_pulse=av_ended && !movie_ended_d;
wire movie_restart_event=movie_sd && movie_ready && movie_count!=0 && (cmd_next || cmd_prev || movie_end_video_pulse);
reset_sync reset_movie_sd(.clk(sd_card_clk),.arst(rst_sd | !movie_sd | movie_restart_event),.rst(rst_movie_sd));
reset_sync reset_movie_video(.clk(video_clk),.arst(rst_video | !movie_video | movie_restart_video_pulse),.rst(rst_movie_video));
always @(posedge video_clk or posedge rst_video)begin
 if(rst_video)begin movie_restart_video_ff<=0;end
 else begin movie_restart_video_ff<={movie_restart_video_ff[0],movie_restart_toggle};end
end
always @(posedge sd_card_clk or posedge rst_sd)begin
 if(rst_sd)begin movie_index<=0;movie_restart_toggle<=0;movie_ended_d<=0;end
 else begin
  movie_ended_d<=av_ended;
  if(movie_sd && movie_ready && movie_count!=0 && (cmd_next || cmd_prev || movie_end_video_pulse))begin
   if(cmd_prev)movie_index<=(movie_index==0)?movie_count-1'b1:movie_index-1'b1;
   else movie_index<=(movie_index+1'b1>=movie_count)?7'd0:movie_index+1'b1;
   movie_restart_toggle<=~movie_restart_toggle;
  end
 end
end
reset_sync reset_photo_video(.clk(video_clk),.arst(rst_video | movie_video),.rst(rst_photo_video));
generate if(AVF_ENABLED)begin: avf_playback
sd_av_reader movie_reader(.clk(sd_card_clk),.rst(rst_movie_sd),.mode_800(1'b0),.toggle_play(cmd_toggle),
 .sd_ready(movie_ready),.sd_error(movie_error),.sector_read(movie_req),.sector_address(movie_sector),
 .sector_data(movie_data),.sector_valid(movie_valid),.sector_end(movie_end),
 .write_req(av_write_req),.write_req_ack(sd_card_write_req_ack),.write_finish_toggle(frame_write_toggle_mem),
 .write_en(av_write_en),.write_data(av_write_data),.pixel_ready(pixel_write_ready),.write_bank(av_write_bank),
 .request_toggle(av_publish),.requested_bank(av_bank),.ack_toggle(av_ack),
 .audio_we(av_we),.audio_address(av_address),.audio_data(av_data),
 .playing(av_playing),.error(av_error),.ended(av_ended),.busy(av_busy),.state_code(av_state),.high_quality(av_high_quality));
av_sync_player movie_player(.clk(video_clk),.rst(rst_movie_video),.mode_800(1'b0),.vblank(vblank),
 .request_toggle(av_publish),.requested_bank(av_bank),.play(av_playing),.failed(av_error),.ended(av_ended),
 .ack_toggle(av_ack),.active_buffer(av_active),.visible(av_visible),.buffering(av_buffering),
 .write_clk(sd_card_clk),.audio_we(av_we),.audio_address(av_address),.audio_data(av_data),
 .audio_valid(av_valid),.left_pcm(av_left),.right_pcm(av_right));
end else begin: photo_only_playback
 assign movie_req=0;assign movie_sector=0;assign av_playing=0;assign av_error=0;
 assign av_ended=0;assign av_busy=0;assign av_ack=0;assign av_visible=0;assign av_buffering=0;
 assign av_publish=0;assign av_bank=0;assign av_we=0;assign av_write_req=0;assign av_write_en=0;
 assign av_valid=0;assign av_address=0;assign av_data=0;assign av_write_data=0;
 assign av_write_bank=0;assign av_active=0;assign av_state=0;assign av_left=0;assign av_right=0;assign av_high_quality=0;
end endgenerate
wire bmp_commit_req,bmp_status_auto,bmp_status_busy,bmp_status_error,bmp_display_valid;
wire bmp_write_req,bmp_write_en,bmp_wav_error,bmp_wav_ready;
wire [1:0] bmp_commit_buffer,bmp_status_index,bmp_write_bank,bmp_disp_bank;
wire [2:0] bmp_status_count;wire [3:0] bmp_state,bmp_wav_code;
wire [31:0] bmp_write_data;wire [11:0] bmp_width,bmp_height;
wire [6:0] bmp_media_index,bmp_media_count,bmp_audio_index,bmp_audio_count;
assign commit_req=bmp_commit_req;assign commit_buffer=bmp_commit_buffer;
assign status_auto=movie_sd?av_playing:bmp_status_auto;
assign status_busy=movie_sd?av_busy:bmp_status_busy;
assign status_error=movie_sd?av_error:bmp_status_error;
assign status_index=movie_sd?2'd0:bmp_status_index;
assign status_count=movie_sd?{2'd0,movie_ready}:bmp_status_count;
assign player_display_valid=!movie_sd && bmp_display_valid;
assign state_code=movie_sd?av_state:bmp_state;
assign write_buf_idx=movie_sd?av_write_bank:bmp_write_bank;
assign disp_buf_idx=movie_sd?2'd0:bmp_disp_bank;
assign sd_card_write_req=movie_sd?av_write_req:bmp_write_req;
assign sd_card_write_en=movie_sd?av_write_en:bmp_write_en;
assign sd_card_write_data=movie_sd?av_write_data:bmp_write_data;
assign image_width=movie_sd?(av_high_quality?12'd320:12'd160):bmp_width;
assign image_height=movie_sd?(av_high_quality?12'd240:12'd120):bmp_height;
assign wav_error=movie_sd?av_error:bmp_wav_error;
assign wav_ready=movie_sd?movie_ready:bmp_wav_ready;
assign wav_error_code=movie_sd?(av_error?4'd1:4'd0):bmp_wav_code;
assign media_image_index=movie_sd?movie_index:bmp_media_index;
assign media_image_count=movie_sd?movie_count:bmp_media_count;
assign media_audio_index=movie_sd?7'd0:bmp_audio_index;
assign media_audio_count=movie_sd?{6'd0,movie_ready}:bmp_audio_count;

// ===================== TF 多图扫描与缓存（双缓冲） =====================
sd_card_bmp #(
    .CLK_FREQ_HZ       (100_000_000),
    .ENABLE_SCALING(1),.ADAPTIVE(1),
    // 正式媒体来自 FAT32 根目录；裸扇区参数仅保留给历史单元测试。
    .VIDEO_FILES(AVF_ENABLED),.ENABLE_AUDIO(1),.FAT32_ENABLE(1),.MAX_BMP(4),.NATIVE_4BIT(1),.NATIVE_HIGH_SPEED(1),.INDEXED(1),.MAX_FILES(64),.RATE_CONTROLS(1),
    .SCAN_TARGET_COUNT (3'd4)
) sd_card_bmp_m0(
    .clk               (sd_card_clk),
    .rst               (rst_sd),
    .key_next          (1'b1),
    .key_auto          (1'b1),
    .cmd_next(cmd_next),.cmd_prev(cmd_prev),.cmd_toggle(cmd_toggle),
    .image_select_index(image_index),.audio_select_index(audio_index),
    .image_select_valid(media_image_select),.audio_select_valid(media_audio_select),
    .media_image_index(bmp_media_index),.media_image_count(bmp_media_count),
    .media_audio_index(bmp_audio_index),.media_audio_count(bmp_audio_count),.media_truncated(media_truncated),.fps_mode(fps_mode),.rate_limited(rate_limited),
    .commit_ack_toggle(commit_ack),.commit_req_toggle(bmp_commit_req),
    .commit_buffer(bmp_commit_buffer),.status_auto(bmp_status_auto),
    .status_index(bmp_status_index),.status_count(bmp_status_count),
    .status_busy(bmp_status_busy),.status_error(bmp_status_error),.display_valid(bmp_display_valid),
    .state_code        (bmp_state),
    .bmp_width         (output_width),
    .bmp_height        (output_height),

    .write_finish_toggle(frame_write_toggle_mem),
    .write_buf_idx     (bmp_write_bank),
    .disp_buf_idx      (bmp_disp_bank),

    .write_req         (bmp_write_req),
    .write_req_ack     (sd_card_write_req_ack),
    .write_en          (bmp_write_en),
    .write_data        (bmp_write_data),
    .SD_nCS(),.SD_DCLK(),.SD_MOSI(),.SD_MISO(1'b1),
    .SD_CLK(SD_CLK),.SD_CMD(SD_CMD),.SD_DAT0(SD_DAT0),
    .SD_DAT1(SD_DAT1),.SD_DAT2(SD_DAT2),.SD_DAT3(SD_DAT3),
    .pixel_ready(pixel_write_ready),.image_width(bmp_width),.image_height(bmp_height),
    .debug_sd_status(debug_sd_status),
    .audio_enable(!mute),.audio_sample_ready(audio_sample_room),
    .audio_sector_room(audio_wr_used<=11'd764 && !audio_fifo_full),
    .audio_sample_valid(wav_sample_valid),.audio_sample(wav_sample),
    .audio_error(bmp_wav_error),.audio_ready(bmp_wav_ready),.audio_stream_reset(audio_queue_reset),
    .audio_error_code(bmp_wav_code),
    .movie_mode(movie_sd),.movie_restart(movie_restart_event),.movie_index(movie_index),.movie_count(movie_count),
    .movie_req(movie_req),.movie_sector(movie_sector),.movie_data(movie_data),.movie_valid(movie_valid),
    .movie_end(movie_end),.movie_error(movie_error),.movie_ready(movie_ready)
);

seg_decoder seg_decoder_m0(
    .bin_data          (state_code),
    .seg_data          (seg_data_0)
);

wire [47:0] debug_segments;
genvar digit;
generate if(DEBUG_ENABLED)begin: debug_instrumentation
 cdc_snapshot #(.WIDTH(8)) reset_count_cdc(.src_clk(boot_clk),.src_rst(rst_all),
  .src_data(watchdog_resets),.dst_clk(sd_card_clk),.dst_rst(rst_sd),.dst_data(watchdog_resets_sd));
 board_debug diagnostics(.clk(sd_card_clk),.rst(rst_sd),
  .video_clk(video_clk),.video_rst(rst_video),.mem_clk(ext_mem_clk),.mem_rst(rst_mem),
  .vs(vs_0),.hs(hs_0),.de(de_0),
  .video_flags({visible,memory_frame_invalid,memory_underflow,video_overflow,vs_0,hs_0,de_0,transition_busy}),
  .memory_status(debug_mem_status),.read_status(debug_read_status),
  .reset_count(watchdog_resets_sd),.sd_status(debug_sd_status),.player_state(state_code),
  .page(debug_page),.display_word(debug_word));
 for(digit=0;digit<6;digit=digit+1)begin: segment
  wire [6:0] pattern;
  seg_decoder decoder(.bin_data(debug_word[digit*4+:4]),.seg_data(pattern));
  assign debug_segments[digit*8+:8]={1'b1,pattern};
 end
end else begin: no_debug
 assign debug_word=0;assign debug_segments=48'hffffffffffff;
 assign watchdog_resets_sd=0;
end endgenerate

seg_scan #(.CLK_FREQ(100000000)) seg_scan_m0(
    .clk               (sd_card_clk),
    .rst_n             (~rst_sd),
    .seg_sel           (seg_sel),
    .seg_data          (seg_data),
    .seg_data_0        ((DEBUG_ENABLED && debug_enable)?debug_segments[47:40]:8'hff),
    .seg_data_1        ((DEBUG_ENABLED && debug_enable)?debug_segments[39:32]:8'hff),
    .seg_data_2        ((DEBUG_ENABLED && debug_enable)?debug_segments[31:24]:8'hff),
    .seg_data_3        ((DEBUG_ENABLED && debug_enable)?debug_segments[23:16]:8'hff),
    .seg_data_4        ((DEBUG_ENABLED && debug_enable)?debug_segments[15:8]:8'hff),
    .seg_data_5        ((DEBUG_ENABLED && debug_enable)?debug_segments[7:0]:{1'b1,seg_data_0})
);

// ===================== 原图像时序与帧缓存 =====================
video_timing_data #(.ADAPTIVE(1)) video_timing_data_m0(.mode_800(mode_video),
    .video_clk         (video_clk),
    .rst               (rst_video),
    .read_req          (video_read_req),
    .read_req_ack      (video_read_req_ack),
    .vblank(vblank),
    .hs                (hs_0),
    .vs                (vs_0),
    .de                (de_0)
);

video_delay video_delay_m0(
    .video_clk         (video_clk),
    .rst               (rst_video),
    .read_en           (video_read_en),
    .read_data         (video_read_data[31:8]),
    .hs                (hs_0),
    .vs                (vs_0),
    .de                (de_0),
    .hs_r              (hs),
    .vs_r              (vs),
    .de_r              (de),
    .vout_data         (vout_data_raw)
);

// 首图提交前黑屏；提交后一直显示当前显示缓冲区内容
assign vout_data = (visible && !memory_frame_invalid) ? vout_data_raw : 24'h102438;

frame_read_write #(
    .ADAPTIVE(1),.BURST_SIZE(64),
    .WRITE_V_FLIP     (1),
    .FRAME_WIDTH      (640),
    .FRAME_HEIGHT     (480)
) frame_read_write_m0(.mode_800(mode_mem),
    .write_rst         (rst_write),
    .mem_clk           (ext_mem_clk),
    .rst               (rst_mem),
    .Sdr_init_done     (Sdr_init_done),
    .Sdr_init_ref_vld  (Sdr_init_ref_vld),
    .Sdr_busy          (Sdr_busy),

    .App_rd_en         (App_rd_en),
    .App_rd_addr       (App_rd_addr),
    .Sdr_rd_en         (Sdr_rd_en),
    .Sdr_rd_dout       (Sdr_rd_dout),

    .read_clk          (video_clk),
    .read_req          (video_read_req && visible),
    .read_req_ack      (video_read_req_ack),
    .read_finish       (),
    .read_addr_0       (BUF0_ADDR),
    .read_addr_1       (buffer1),
    .read_addr_2       (21'd0),
    .read_addr_3       (21'd0),
    .read_addr_index   (active_buffer),
    .read_len          (output_pixels),
    .read_en           (video_read_en && visible),
    .read_data         (video_read_data),

    .App_wr_en         (App_wr_en),
    .App_wr_addr       (App_wr_addr),
    .App_wr_din        (App_wr_din),
    .App_wr_dm         (App_wr_dm),

    .write_clk         (sd_card_clk),
    .write_req         (sd_card_write_req),
    .write_req_ack     (sd_card_write_req_ack),
    .write_finish      (frame_write_finish),
    .write_addr_0      (BUF0_ADDR),
    .write_addr_1      (buffer1),
    .write_addr_2      (21'd0),
    .write_addr_3      (21'd0),
    .write_addr_index  (write_buf_idx),
    .write_len         (output_pixels),
    .write_en          (sd_card_write_en),
    .write_data        (sd_card_write_data),
    .write_ready(pixel_write_ready),
    .wr_overflow_sticky(memory_overflow),
    .rd_underflow_sticky(memory_underflow),
    .rd_frame_invalid(memory_frame_invalid),
    .debug_mem_status(debug_mem_status),.debug_read_status(debug_read_status)
);

sdram U3(
    .Clk               (ext_mem_clk),
    .Clk_sft           (ext_mem_clk_sft),
    .Rst               (rst_mem),
    .Sdr_init_done     (Sdr_init_done),
    .Sdr_init_ref_vld  (Sdr_init_ref_vld),
    .Sdr_busy          (Sdr_busy),
    .App_wr_en         (App_wr_en),
    .App_wr_addr       (App_wr_addr),
    .App_wr_dm         (App_wr_dm),
    .App_wr_din        (App_wr_din),
    .App_rd_en         (App_rd_en),
    .App_rd_addr       (App_rd_addr),
    .Sdr_rd_en         (Sdr_rd_en),
    .Sdr_rd_dout       (Sdr_rd_dout)
);

// ===================== RGB/DE 转 AXIS 视频 =====================
video_rgb_to_axis_640x480 #(.ADAPTIVE(1)) u_video_rgb_to_axis_640x480(.mode_800(mode_video),
    .I_clk         (video_clk),
    .I_rst         (rst_video),
    .I_ready       (axis_s_ready),
    .O_overflow    (video_overflow),
    .I_vs          (game_vs),
    .I_de          (game_de),
    .I_rgb         (game_rgb),
    .O_video_user  (axis_s_user),
    .O_video_valid (axis_s_valid),
    .O_video_last  (axis_s_last),
    .O_video_data  (axis_s_data)
);

// 上电后自动打一拍，触发一次 EDID 读取
startup_pulse #(
    .CNT_MAX(20'd100000)
) u_startup_pulse (
    .I_clk   (boot_clk),
    .I_rst   (rst_boot),
    .O_pulse (edid_trig)
);

// ===================== HDMI 1.4b 发射 =====================
wire [9:0] vga_ch0,vga_ch1,vga_ch2,vga_clk;
wire [9:0] svga_ch0,svga_ch1,svga_ch2,svga_clk;
wire svga_ready;
wire unused_ddc_sda;
wire rst_vga,rst_svga;
// Mode bits are settled before rst_video releases. Use local synchronized
// signals here instead of decoding EDID-domain outputs into the core resets.
// VGA must run during initial EDID acquisition (mode_done=0). Afterwards
// both HDMI cores must remain reset throughout every runtime clock switch.
reset_sync reset_vga(.clk(video_clk),.arst(rst_all | mode_video | (mode_done && rst_video)),.rst(rst_vga));
reset_sync reset_svga(.clk(video_clk),.arst(rst_video | !mode_video),.rst(rst_svga));
assign axis_s_ready=mode_video?svga_ready:1'b1;
assign tmds_ch0_data=mode_video?svga_ch0:vga_ch0;
assign tmds_ch1_data=mode_video?svga_ch1:vga_ch1;
assign tmds_ch2_data=mode_video?svga_ch2:vga_ch2;
assign tmds_clk_data=mode_video?svga_clk:vga_clk;
// Video-only VGA consumes the final composited pixel stream directly.
hdmi_tmds_vga u_hdmi_640(
    .clk(video_clk),.rst(rst_vga),.vs(game_vs),.de(game_de),.rgb(game_rgb),
    .ch0(vga_ch0),.ch1(vga_ch1),.ch2(vga_ch2),.clk_ch(vga_clk)
);
// EDID runs on the permanent boot clock and survives runtime mode changes.
edid_i2c u_edid_i2c(
    .clk(boot_clk),.rst(rst_boot),.start(edid_trig),
    .scl(HDMI_DDC_SCL),.sda(HDMI_DDC_SDA),
    .valid(edid_valid),.data(edid_data),.busy(),.done(),.error()
);

hdmi_1_4b_transmitter_core_wrapper #(
    .DEVICE                 ( "EG"       ),
    .HTOTAL                 ( 1056 ),
    .HSA                    ( 128 ),
    .HFP                    ( 40 ),
    .HBP                    ( 88 ),
    .HACTIVE                ( 800 ),
    .VTOTAL                 ( 628 ),
    .VSA                    ( 4 ),
    .VFP                    ( 1 ),
    .VBP                    ( 23 ),
    .VACTIVE                ( 600 ),
    .VIDEO_VIC              ( 0 ),
    .VIDEO_TPG              ( "Disable"  ),
    .VIDEO_FORMAT           ( "RGB"      ),
    .AUDIO_SAMPLE_RATE      ( "48K"      ),
    .IIC_SCL_DIV            ( 400 )
) u_hdmi_svga(
    .I_pixel_clk        (video_clk),
    .I_rst              (rst_svga),
    .I_edid_read_trig   (1'b0),
    .O_edid_read_valid  (),
    .O_edid_read_data   (),

    .I_axis_s_user      (axis_s_user),
    .I_axis_s_valid     (axis_s_valid),
    .I_axis_s_last      (axis_s_last),
    .I_axis_s_data      (axis_s_data),
    .O_axis_s_ready     (svga_ready),

    .I_audio_valid      (audio_valid),
    .I_audio_left_data  (audio_left),
    .I_audio_right_data (audio_right),
    .I_acr_valid        (audio_valid),
    .I_acr_cts          (20'd40000),
    .I_acr_n            (20'd6144),

    .O_video_locked     (),
    .O_ddc_scl          (),
    .IO_ddc_sda         (unused_ddc_sda),

    .O_ch0_tmds_data    (svga_ch0),
    .O_ch1_tmds_data    (svga_ch1),
    .O_ch2_tmds_data    (svga_ch2),
    .O_clk_tmds_data    (svga_clk)
);

hdmi_phy_wrapper #(
    .DEVICE ( "EG" )
) u_hdmi2phy_wrapper(
    .I_pixel_clk        (video_clk),
    .I_serial_clk       (hdmi_5x_clk),
    .I_rst              (rst_video),
    .I_tmds_channel_0   (tmds_ch0_data),
    .I_tmds_channel_1   (tmds_ch1_data),
    .I_tmds_channel_2   (tmds_ch2_data),
    .I_tmds_channel_clk (tmds_clk_data),
    .O_tmds_ch0_p       (HDMI_D0_P),
    .O_tmds_ch1_p       (HDMI_D1_P),
    .O_tmds_ch2_p       (HDMI_D2_P),
    .O_tmds_clk_p       (HDMI_CLK_P)
);

// Physical keys, keyboard and remote commands share the same playback consumer.
assign cmd_next=board_next || kb_next || pc_next || slide_next;
assign cmd_prev=kb_prev || pc_prev;
assign cmd_toggle=board_toggle || kb_toggle || pc_toggle;
remote_controls #(.IR_ENABLED(1)) remote(.clk(sd_card_clk),.rst(rst_controls),.rx(uart_rx_pin),
 .tx(uart_tx_pin),.overflow(tx_overflow),.next_pulse(pc_next),.prev_pulse(pc_prev),.toggle_pulse(pc_toggle),
 .time_bcd(remote_time_bcd),.time_seq(remote_time_seq),.time_set(remote_time_set),.ir_rx(ir_rx_pin),.auto_enh_en(auto_enh_en),.slide_enable(slide_enable),.zh_enable(zh_enable),.large_clock(large_clock),
 .vol_up(ir_vol_up),.vol_dn(ir_vol_dn),.mute_toggle(ir_mute),.bri_up(ir_bri_up),.bri_dn(ir_bri_dn),.con_up(ir_con_up),.con_dn(ir_con_dn),
 .osd_toggle(ir_osd_toggle),.test_toggle(ir_test_toggle),.transition_toggle(ir_transition_toggle),.transition_mode(),
 .captions_enable(),.scroll_enable(),.slogan_select());
slideshow_timer #(.PERIOD(500000000)) album_timer(.clk(sd_card_clk),.rst(rst_controls),
 .enable(!movie_sd && slide_enable && !status_auto && player_display_valid && media_image_count>1),
 .busy(status_busy || status_error || !sd_init_done),.next_pulse(slide_next));
cdc_snapshot #(.WIDTH(2)) album_cdc(.src_clk(sd_card_clk),.src_rst(rst_controls),
 .src_data({large_clock,zh_enable}),.dst_clk(video_clk),.dst_rst(rst_video),.dst_data(album_video));
cdc_snapshot #(.WIDTH(33)) time_cdc(.src_clk(sd_card_clk),.src_rst(rst_controls),
 .src_data({remote_time_set,remote_time_seq,remote_time_bcd}),.dst_clk(video_clk),.dst_rst(rst_video),.dst_data(time_video));
assign osd_enable=osd_on;
assign test_pattern=test_pattern_reg;
// Cycle the three built-in slogans with the displayed image index.
assign slogan_select=(status_index==3)?2'd0:status_index;
ps2_keyboard keyboard(.clk(sd_card_clk),.rst(rst_controls),.ps2_clk(ps2_clk),.ps2_data(ps2_data),
 .scan_code(kb_scan_code),.key_valid(kb_valid),.key_release(kb_release),
 .key_extended(kb_extended),.receive_error(kb_error));
ps2_controls keyboard_events(.clk(sd_card_clk),.rst(rst_controls),.scan_code(kb_scan_code),
 .key_valid(kb_valid),.key_release(kb_release),.key_extended(kb_extended),.receive_error(kb_error),
 .ev_next(kb_next),.ev_prev(kb_prev),.ev_toggle_auto(kb_toggle),.ev_vol_up(kb_vol_up),.ev_vol_dn(kb_vol_dn),
 .ev_mute(kb_mute),.ev_osd(kb_osd),.ev_res(kb_res),.ev_fps(kb_fps),
 .game_enable(kb_game_on),.held_up(kb_held_up),.held_down(kb_held_down),.held_left(kb_held_left),.held_right(kb_held_right),
 .ev_digit(kb_digit),.ev_image_select(kb_image_select),.ev_audio_select(kb_audio_select),.audio_pending(kb_audio_pending));
always @(posedge sd_card_clk or posedge rst_controls)begin
 if(rst_controls)begin image_index<=0;audio_index<=0;res_mode<=1;fps_mode<=2;osd_on<=1;test_pattern_reg<=0;ir_transition_offset<=0;last_sw_transition<=0;media_image_select<=0;media_audio_select<=0;end
 else begin
  // Align pulses to the registered index, including consecutive choices.
  media_image_select<=kb_image_select;media_audio_select<=kb_audio_select;
  if(!rst_sd && player_display_valid && (!committed_image_seen || media_image_index!=last_committed_image) && media_image_count!=0 && !status_busy && !kb_image_select && !media_image_select)
   image_index<={1'b0,media_image_index}; // resume committed image after R
  if(kb_image_select)image_index<={4'd0,kb_digit};
  if(kb_audio_select)audio_index<={4'd0,kb_digit};
  if(kb_res)res_mode<=(res_mode==2)?0:res_mode+1'b1;
  if(kb_fps)fps_mode<=(fps_mode==5)?0:fps_mode+1'b1;
  if(kb_osd || ir_osd_toggle)osd_on<=!osd_on;
  if(ir_test_toggle)test_pattern_reg<=!test_pattern_reg;
  last_sw_transition<=sw_transition_mode;
  if(last_sw_transition!=sw_transition_mode)ir_transition_offset<=0;
  else if(ir_transition_toggle)ir_transition_offset<=ir_transition_offset+1'b1;
 end
end
picture_controls #(.BOARD_MENU(1),.AUDIO_MENU(1),.KEYBOARD_CONTROLS(1),.AUDIO_MUTE_DEFAULT(0)) buttons(.clk(sd_card_clk),.rst(rst_controls),
 .key1_n(key1),.key2_n(key2),.key3_n(key3),.next_pulse(board_next),.toggle_pulse(board_toggle),
 .brightness(brightness),.contrast(contrast),.edit_mode(edit_mode),
 .menu_open(menu_open),.menu_item(menu_item),.gamma_enable(gamma_enable),
 .debug_enable(debug_enable),.debug_page(debug_page),.audio_volume(volume),.audio_mute(mute),
 .kb_vol_up(kb_vol_up),.kb_vol_dn(kb_vol_dn),.kb_mute(kb_mute),
 .ir_vol_up(ir_vol_up),.ir_vol_dn(ir_vol_dn),.ir_mute(ir_mute),.ir_bri_up(ir_bri_up),.ir_bri_dn(ir_bri_dn),
 .ir_con_up(ir_con_up),.ir_con_dn(ir_con_dn));
switch_controls switches(.clk(sd_card_clk),.rst(rst_controls),.sw(sw),
 .captions_enable(captions_enable),.scroll_enable(scroll_enable),
 .transition_mode(sw_transition_mode));
// SW sets the base mode; a debounced SW change takes priority over IR.
assign transition_mode=sw_transition_mode+ir_transition_offset;
cdc_snapshot #(.WIDTH(70),.ENCODE_HOLD(1)) status_cdc(.src_clk(sd_card_clk),.src_rst(rst_sd),
 .src_data(status_source),.dst_clk(video_clk),.dst_rst(rst_video),.dst_data(status_video));
cdc_snapshot #(.WIDTH(7)) rate_cdc(.src_clk(sd_card_clk),.src_rst(rst_controls),
 .src_data({res_mode,rate_limited,fps_mode}),.dst_clk(video_clk),.dst_rst(rst_video),.dst_data(rate_video));
// Independent bus: historical 70-bit status layout and selectors stay fixed.
cdc_snapshot #(.WIDTH(29),.ENCODE_HOLD(1)) media_cdc(.src_clk(sd_card_clk),.src_rst(rst_sd),
 .src_data({media_truncated,media_audio_index,media_audio_count,media_image_index,media_image_count}),
 .dst_clk(video_clk),.dst_rst(rst_video),.dst_data(media_video));
wire bmp_commit_ack,bmp_visible,bmp_transition_busy;
wire [1:0] bmp_active_buffer;
wire [2:0] bmp_running_effect;
wire [5:0] bmp_fade_level;wire [9:0] bmp_slide_offset;
assign commit_ack=bmp_commit_ack;
assign active_buffer=movie_video?av_active:bmp_active_buffer;
assign visible=movie_video?av_visible:bmp_visible;
assign running_effect=movie_video?3'd0:bmp_running_effect;
assign fade_level=movie_video?6'd32:bmp_fade_level;
assign slide_offset=movie_video?10'd0:bmp_slide_offset;
assign transition_busy=movie_video?1'b0:bmp_transition_busy;
frame_swap #(.ENABLE_EFFECTS(TRANSITIONS_ENABLED),.ADAPTIVE(1)) swap(.mode_800(mode_video),.clk(video_clk),.rst(rst_photo_video),.vblank(vblank),
 .request_toggle(commit_req),.requested_buffer(commit_buffer),
 .ack_toggle(bmp_commit_ack),.active_buffer(bmp_active_buffer),.display_valid(bmp_visible),
 .transition_mode(video_effect),.effect_mode(bmp_running_effect),.fade_level(bmp_fade_level),
 .slide_offset(bmp_slide_offset),.transition_busy(bmp_transition_busy));
video_coordinates source_coordinates(video_clk,rst_video,vs,de,pixel_x,pixel_y);
assign source_rgb=video_pattern ? {pixel_x[7:0],pixel_y[7:0],8'h80} : vout_data;
picture_adjust enhance(.clk(video_clk),.rst(rst_video),.vs(vs),.de(de),.x(pixel_x),.y(pixel_y),
 .rgb(source_rgb),.brightness(frame_brightness),.contrast(frame_contrast),
 .out_vs(adjusted_vs),.out_de(adjusted_de),.out_x(adjusted_x),.out_y(adjusted_y),.out_rgb(enhanced_rgb));
picture_gamma gamma(.clk(video_clk),.rst(rst_video),.vs(adjusted_vs),.de(adjusted_de),
 .x(adjusted_x),.y(adjusted_y),.rgb(enhanced_rgb),.enable(frame_ui[4]),
 .out_vs(gamma_vs),.out_de(gamma_de),.out_x(gamma_x),.out_y(gamma_y),.out_rgb(gamma_rgb));
cdc_snapshot #(.WIDTH(1)) autoenh_cdc(.src_clk(sd_card_clk),.src_rst(rst_controls),
 .src_data(auto_enh_en),.dst_clk(video_clk),.dst_rst(rst_video),.dst_data(auto_enh_video));
generate if(AUTO_ENHANCE_ENABLED)begin: auto_enhancement
auto_enhance autoe(.clk(video_clk),.rst(rst_video),.vs(gamma_vs),.de(gamma_de),.x(gamma_x),.y(gamma_y),
 .rgb(gamma_rgb),.enable(auto_enh_video),.out_vs(ae_vs),.out_de(ae_de),.out_x(ae_x),.out_y(ae_y),.out_rgb(ae_rgb));
end else begin
 assign ae_vs=gamma_vs;assign ae_de=gamma_de;assign ae_x=gamma_x;assign ae_y=gamma_y;assign ae_rgb=gamma_rgb;
end endgenerate
generate if(TRANSITIONS_ENABLED)begin: transition_rendering
transition_pixels effects(.clk(video_clk),.rst(rst_video),.vs(ae_vs),.de(ae_de),
 .x(ae_x),.y(ae_y),.mode_800(mode_video),.rgb(ae_rgb),.effect_mode(running_effect),
 .fade_level(fade_level),.slide_offset(slide_offset),
 .out_vs(transition_vs),.out_de(transition_de),.out_rgb(transition_rgb));
end else begin
 assign transition_vs=ae_vs;assign transition_de=ae_de;assign transition_rgb=ae_rgb;
end endgenerate
// Physical coordinates for line RAM, logical viewport for adaptive UI panels.
wire [9:0] fx_x,fx_y,wave_x,wave_y;
wire fx_vs,fx_de,wave_vs,wave_de;
wire [23:0] fx_rgb,wave_rgb;
wire [11:0] fx_luma_sum;wire [7:0] fx_luma;wire fx_window_valid,fx_sobel;
video_coordinates fx_coordinates(video_clk,rst_video,transition_vs,transition_de,fx_x,fx_y);
pixel_effects #(.DEPTH(800),.EDGE_TH(8'd80),.BRAM_WINDOW(1)) pixel_filter(
 .clk(video_clk),.rst(rst_video),.vs(transition_vs),.de(transition_de),.x(fx_x),.rgb(transition_rgb),
 .mode_sel(video_effect),.out_vs(fx_vs),.out_de(fx_de),.out_rgb(fx_rgb),
 .out_luma_sum(fx_luma_sum),.out_luma(fx_luma),.out_window_valid(fx_window_valid),.out_sobel(fx_sobel));
viewport_coordinates waveform_coordinates(video_clk,rst_video,fx_vs,fx_de,mode_video,wave_x,wave_y,,);
audio_visualizer #(.BRAM_HISTORY(1)) waveform(.clk(video_clk),.rst(rst_video),.vs(fx_vs),.de(fx_de),.x(wave_x),.y(wave_y),
 .rgb(fx_rgb),.audio_valid(audio_valid),.audio_left(audio_left),.enable(video_osd),
 .out_vs(wave_vs),.out_de(wave_de),.out_rgb(wave_rgb));
caption_overlay #(.ADAPTIVE(1),.PIPELINED(1)) captions(.mode_800(mode_video),.clk(video_clk),.rst(rst_video),.vs(wave_vs),.de(wave_de),
 .large_clock(album_video[1]),.time_set(time_video[32]),.time_seq(time_video[31:24]),.time_bcd(time_video[23:0]),
 .rgb(wave_rgb),.enable(video_captions),.scroll_enable(video_scroll),
 .slogan_select(video_slogan),.transition_mode(video_effect),
 .out_vs(caption_vs),.out_de(caption_de),.out_rgb(caption_rgb));
viewport_coordinates chinese_coordinates(video_clk,rst_video,caption_vs,caption_de,mode_video,zh_x,zh_y,,);
generate if(CHINESE_ENABLED)begin: chinese_caption
zh_overlay chinese(.clk(video_clk),.rst(rst_video),.vs(caption_vs),.de(caption_de),.x(zh_x),.y(zh_y),
 .rgb(caption_rgb),.enable(album_video[0]),.out_vs(zh_vs),.out_de(zh_de),.out_rgb(zh_rgb),.out_x(),.out_y());
end else begin
 assign zh_vs=caption_vs;assign zh_de=caption_de;assign zh_rgb=caption_rgb;
end endgenerate
status_osd #(.ENHANCED_UI(1),.ADAPTIVE(1),.PIPELINED(1),.BOARD_UI(1),.AUDIO_UI(1),.AUDIO_DIAGNOSTICS(1),.FILE_UI(1),.RATE_UI(1)) osd(.out_vs(osd_vs),.out_de(osd_de),.mode_800(mode_video),.clk(video_clk),.rst(rst_video),.vs(zh_vs),.de(zh_de),.rgb(zh_rgb),
 .enable(frame_osd),.auto_play(video_auto),.image_index(video_index),.image_count(video_count),
 .volume(video_volume),.mute(video_mute),.busy(video_busy),
 .error(video_error | memory_underflow | memory_overflow_video[1]),.edid_ok(edid_good_vff[1]),
 .result(osd_rgb),.pixel_x(),.pixel_y(),
 .brightness(frame_brightness),.contrast(frame_contrast),.edit_mode(frame_edit_mode),
 .source_width(frame_source_width),.source_height(frame_source_height),
 .menu_open(frame_ui[0]),.menu_item(frame_ui[3:1]),.gamma_enable(frame_ui[4]),
 .debug_enable(frame_ui[5]),.debug_page(frame_ui[7:6]),
 .audio_ready(frame_audio_status[0]),.audio_error(|frame_audio_error_code),
 .audio_error_code(frame_audio_error_code),.audio_underflow(frame_audio_underflow),
 .file_image_index(frame_media[13:7]),.file_image_count(frame_media[6:0]),
 .file_audio_index(frame_media[27:21]),.file_audio_count(frame_media[20:14]),.file_table_truncated(frame_media[28]),.slide_rate_mode(frame_rate[3:0]),.slide_rate_limited(frame_rate[4]),.requested_res_mode(frame_rate[6:5]));
// Separate game control snapshot: historical 70-bit status layout is fixed.
cdc_snapshot #(.WIDTH(5)) game_control_cdc(.src_clk(sd_card_clk),.src_rst(rst_controls),
 .src_data({kb_game_on,kb_held_up,kb_held_down,kb_held_left,kb_held_right}),
 .dst_clk(video_clk),.dst_rst(rst_video),.dst_data(game_controls_video));
snake_frame_control game_clock(.clk(video_clk),.rst(rst_video),.vs(osd_vs),
 .controls(game_controls_video),.game_on(game_on),.dir_req(game_dir),.tick(game_tick));
// status_osd.pixel_x/y describe its INPUT, before its registered output.
// Rebuild at the actual output; logical 640x480 viewport also centers SVGA.
viewport_coordinates game_coordinates(video_clk,rst_video,osd_vs,osd_de,mode_video,game_x,game_y,,);
snake_game_bram game(.clk(video_clk),.rst(rst_video),.vs(osd_vs),.de(osd_de),
 .x(game_x),.y(game_y),.rgb(osd_rgb),.game_enable(game_on),.dir_req(game_dir),.tick(game_tick),
 .out_vs(game_vs),.out_de(game_de),.out_rgb(game_rgb),.score(game_score),.game_over(game_over));
// 音频流有效标志单独整体跨域，不等待显示帧锁存；错误同时清空队列。
// Local reset release leaf for the audio-status source handshake.
(* preserve="true" *) reg rst_audio_status;
always @(posedge sd_card_clk or posedge rst_sd)begin
 if(rst_sd)rst_audio_status<=1;else rst_audio_status<=0;
end
cdc_snapshot #(.WIDTH(2)) audio_state_cdc(.src_clk(sd_card_clk),.src_rst(rst_audio_status),
 .src_data({wav_error,wav_ready}),.dst_clk(video_clk),.dst_rst(rst_video),.dst_data(audio_stream_video));
// Independent diagnostic bus; the original 70-bit status_source is untouched.
cdc_snapshot #(.WIDTH(4)) audio_error_cdc(.src_clk(sd_card_clk),.src_rst(rst_sd),
 .src_data(wav_error_code),.dst_clk(video_clk),.dst_rst(rst_video),.dst_data(audio_error_code_video));
audio_error_history audio_history(.clk(video_clk),.rst(rst_video),
 .current_code(audio_error_code_video),.pcm_valid(audio_pcm_valid),.last_code(audio_last_error));
audio_async_fifo audio_fifo(.wr_clk(sd_card_clk),.rd_clk(video_clk),
 // audio_queue_reset already includes rst_sd (async assertion from rst_all,
 // synchronized release). Avoid a redundant boot-domain reset release branch.
 .rst(!mode_ready | audio_queue_reset),.wr_en(wav_sample_valid),.wr_data(wav_sample),
 .full(audio_fifo_full),.rd_en(audio_fifo_read),.rd_data(audio_fifo_data),.empty(audio_fifo_empty),
 .wr_used(audio_wr_used),.rd_used(audio_rd_used));
// A stream switch clears only the effects history; playback cadence and
// sticky underflow diagnostics survive. Release is local to the pixel clock.
wire audio_fx_reset;
reset_sync audio_effect_reset(.clk(video_clk),.arst(rst_video | audio_queue_reset),.rst(audio_fx_reset));
wire audio_src_valid;
wire [23:0] audio_src_left,audio_src_right;
audio_playback #(.ADAPTIVE(1)) audio_source(.clk(video_clk),.rst(rst_video),.volume(video_volume),
 .mute(video_mute),.mode_800(mode_video),.stream_ok(!movie_video && audio_stream_video[0] && !audio_stream_video[1] && !video_mute),
 .fifo_empty(audio_fifo_empty),.fifo_used(audio_rd_used),.fifo_data(audio_fifo_data),.fifo_rd_en(audio_fifo_read),
 .valid(audio_src_valid),.left_pcm(audio_src_left),.right_pcm(audio_src_right),.underflow(audio_underflow),.pcm_valid(audio_pcm_valid));
wire av_gain_valid;wire [23:0] av_gain_pcm;
generate if(AVF_ENABLED)begin: avf_gain
 av_audio_gain movie_gain(.clk(video_clk),.rst(rst_movie_video),.valid(av_valid),.pcm(av_left),
  .volume(video_volume),.mute(video_mute),.out_valid(av_gain_valid),.out_pcm(av_gain_pcm));
end else begin
 assign av_gain_valid=0;assign av_gain_pcm=0;
end endgenerate
`ifdef AUDIO_EFFECTS_ENABLED_BUILD
    // Optional fixed build profile; no runtime controls or CDC are added.
    audio_effects_stream #(.BASS_GAIN(16'sd3276),.TREBLE_GAIN(16'sd3276),
     .ECHO_FEEDBACK(16'sd22938)) fx(.clk(video_clk),.rst(rst_video),
`else
    audio_effects_stream fx(.clk(video_clk),.rst(rst_video),
`endif
 .stream_rst(audio_fx_reset || video_mute || video_volume==0), .src_valid(movie_video?av_gain_valid:audio_src_valid),.src_left(movie_video?av_gain_pcm:audio_src_left),.src_right(movie_video?av_gain_pcm:audio_src_right),
 .out_valid(audio_valid),.out_left(audio_left),.out_right(audio_right));
edid_display_mode edid_check(.clk(boot_clk),.rst(rst_boot),.start(edid_trig),
 .valid(edid_valid_boot),.data(edid_data_boot),.done(mode_done),.good(edid_good),
 .mode_800(edid_mode_800),.fallback());
assign edid_done=mode_done;

endmodule
