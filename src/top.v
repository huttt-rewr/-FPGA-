
module top(
    input uart_rx_pin,
    output uart_tx_pin,
    input ir_rx_pin,
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

    // TF card SPI
    output                      sd_ncs,
    output                      sd_dclk,
    output                      sd_mosi,
    input                       sd_miso
);

parameter MEM_DATA_BITS = 32;
parameter ADDR_BITS     = 21;
parameter FRAME_PIXELS  = 21'd307200;   // 640*480
parameter BUF0_ADDR     = 21'd0;
parameter BUF1_ADDR     = FRAME_PIXELS;
parameter DEBUG_ENABLED = 1; // 0 removes snapshots and extra seven-segment logic.
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
wire [1:0] audio_stream_video;
wire [3:0] wav_error_code,audio_error_code_video,audio_last_error;
wire audio_pcm_valid;
reg [3:0] frame_audio_error_code;
reg frame_audio_underflow;
wire gamma_vs,gamma_de;
wire [9:0] gamma_x;
wire [23:0] gamma_rgb;
wire mode_800,mode_done,mode_fallback;
wire boot_clk,rst_boot;
reg mode_ready;
reg [12:0] settle_count;
wire [15:0] output_width=mode_sd?16'd800:16'd640;
wire [15:0] output_height=mode_sd?16'd600:16'd480;
wire [20:0] output_pixels=mode_mem?21'd480000:21'd307200;
// Fixed non-overlapping slots sized for the maximum supported frame.
wire [20:0] buffer1=21'd480000;
always @(posedge boot_clk or posedge rst_boot)begin
 if(rst_boot)begin mode_ready<=0;settle_count<=0;end
 else if(mode_done && !mode_ready)begin
  if(settle_count==4095)mode_ready<=1;
  else settle_count<=settle_count+1'b1;
 end
end

// Upgrade control and status signals.
(* async_reg="true" *) reg [1:0] video_overflow_sd;
always @(posedge sd_card_clk or posedge rst_sd) begin
    if (rst_sd) video_overflow_sd <= 0;
    else video_overflow_sd <= {video_overflow_sd[0],video_overflow};
end
wire cmd_next,cmd_prev,cmd_toggle;
wire pixel_write_ready;
wire [11:0] image_width,image_height;
wire [3:0] contrast;
wire [1:0] edit_mode;
wire adjusted_vs,adjusted_de;
wire [9:0] adjusted_x;
wire [4:0] volume;
wire mute,osd_enable,test_pattern;
wire [1:0] transition_mode,slogan_select;
wire captions_enable,scroll_enable;
wire signed [7:0] brightness;
wire status_auto,status_busy,status_error;
wire [1:0] status_index;
wire [2:0] status_count;
wire commit_req,commit_ack,vblank,visible;
wire [1:0] commit_buffer,active_buffer;
wire tx_overflow,video_overflow;
wire memory_underflow,memory_overflow,memory_frame_invalid;
(* async_reg="true" *) reg [1:0] memory_overflow_video;
always @(posedge video_clk or posedge rst_video) begin
 if(rst_video) memory_overflow_video<=0;
 else memory_overflow_video<={memory_overflow_video[0],memory_overflow};
end
wire [23:0] osd_rgb,enhanced_rgb,source_rgb,transition_rgb,caption_rgb;
wire transition_vs,transition_de,caption_vs,caption_de;
wire osd_vs,osd_de;
wire [1:0] running_effect;
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
always @(posedge video_clk or posedge rst_video)begin
 if(rst_video)begin
  settings_vs_d<=1;frame_brightness<=0;frame_contrast<=4;frame_edit_mode<=0;
  frame_source_width<=0;frame_source_height<=0;
  frame_ui<=0;frame_audio_status<=0;frame_audio_error_code<=0;frame_audio_underflow<=0;
 end else begin
  settings_vs_d<=vs;
  if(settings_vs_d && !vs)begin
   frame_brightness<=video_brightness;frame_contrast<=status_video[33:30];
   frame_edit_mode<=status_video[35:34];
   frame_source_width<=status_video[47:36];frame_source_height<=status_video[59:48];
   frame_ui<=status_video[67:60];frame_audio_status<=status_video[69:68];
   frame_audio_error_code<=audio_last_error;frame_audio_underflow<=audio_underflow;
  end
 end
end
wire Sdr_init_done;
wire Sdr_init_ref_vld;
wire Sdr_busy;

wire sd_card_clk;
wire ext_mem_clk;
wire ext_mem_clk_sft;
wire video_clk;
wire hdmi_5x_clk;

wire hs;
wire vs;
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
 else begin edid_valid_boot<=edid_valid;edid_data_boot<=edid_data;end
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
(* async_reg="true" *) reg [1:0] mode_vff,mode_sff,mode_mff;
(* async_reg="true" *) reg [1:0] edid_good_vff;
wire mode_video=mode_vff[1],mode_sd=mode_sff[1],mode_mem=mode_mff[1];
always @(posedge video_clk or posedge rst_all)begin
 if(rst_all)begin mode_vff<=0;edid_good_vff<=0;end
 else begin mode_vff<={mode_vff[0],mode_800};edid_good_vff<={edid_good_vff[0],edid_good};end
end
always @(posedge sd_card_clk or posedge rst_all)begin
 if(rst_all)mode_sff<=0;else mode_sff<={mode_sff[0],mode_800};
end
always @(posedge ext_mem_clk or posedge rst_all)begin
 if(rst_all)mode_mff<=0;else mode_mff<={mode_mff[0],mode_800};
end


wire rst_sd,rst_mem,rst_video,rst_write;
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
 .arst(!rst_n || !sys_pll_lock || !video_pll_lock),
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

// ===================== TF 多图扫描与缓存（双缓冲） =====================
sd_card_bmp #(
    .CLK_FREQ_HZ       (100_000_000),
    .ENABLE_SCALING(1),.ADAPTIVE(1),
    // 正式媒体来自 FAT32 根目录；裸扇区参数仅保留给历史单元测试。
    .ENABLE_AUDIO(1),.FAT32_ENABLE(1),.MAX_BMP(4),
    .SCAN_TARGET_COUNT (3'd4)
) sd_card_bmp_m0(
    .clk               (sd_card_clk),
    .rst               (rst_sd),
    .key_next          (1'b1),
    .key_auto          (1'b1),
    .cmd_next(cmd_next),.cmd_prev(cmd_prev),.cmd_toggle(cmd_toggle),
    .commit_ack_toggle(commit_ack),.commit_req_toggle(commit_req),
    .commit_buffer(commit_buffer),.status_auto(status_auto),
    .status_index(status_index),.status_count(status_count),
    .status_busy(status_busy),.status_error(status_error),
    .state_code        (state_code),
    .bmp_width         (output_width),
    .bmp_height        (output_height),

    .write_finish_toggle(frame_write_toggle_mem),
    .write_buf_idx     (write_buf_idx),
    .disp_buf_idx      (disp_buf_idx),

    .write_req         (sd_card_write_req),
    .write_req_ack     (sd_card_write_req_ack),
    .write_en          (sd_card_write_en),
    .write_data        (sd_card_write_data),
    .SD_nCS            (sd_ncs),
    .SD_DCLK           (sd_dclk),
    .SD_MOSI           (sd_mosi),
    .SD_MISO           (sd_miso),
    .pixel_ready(pixel_write_ready),.image_width(image_width),.image_height(image_height),
    .debug_sd_status(debug_sd_status),
    .audio_enable(!mute),.audio_sample_ready(!audio_fifo_full),
    .audio_sector_room(audio_wr_used<=11'd764 && !audio_fifo_full),
    .audio_sample_valid(wav_sample_valid),.audio_sample(wav_sample),
    .audio_error(wav_error),.audio_ready(wav_ready),.audio_stream_reset(audio_queue_reset),
    .audio_error_code(wav_error_code)
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
    .I_vs          (osd_vs),
    .I_de          (osd_de),
    .I_rgb         (osd_rgb),
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
wire vga_ready,svga_ready;
wire unused_ddc_sda;
wire rst_vga,rst_svga;
// Mode bits are settled before rst_video releases. Use local synchronized
// signals here instead of decoding EDID-domain outputs into the core resets.
reset_sync reset_vga(.clk(video_clk),.arst(rst_all | mode_video),.rst(rst_vga));
reset_sync reset_svga(.clk(video_clk),.arst(rst_video | !mode_video),.rst(rst_svga));
assign axis_s_ready=mode_video?svga_ready:vga_ready;
assign tmds_ch0_data=mode_video?svga_ch0:vga_ch0;
assign tmds_ch1_data=mode_video?svga_ch1:vga_ch1;
assign tmds_ch2_data=mode_video?svga_ch2:vga_ch2;
assign tmds_clk_data=mode_video?svga_clk:vga_clk;
hdmi_1_4b_transmitter_core_wrapper #(
    .DEVICE                 ( "EG"       ),
    .HTOTAL                 ( 800        ),
    .HSA                    ( 96         ),
    .HFP                    ( 16         ),
    .HBP                    ( 48         ),
    .HACTIVE                ( 640        ),
    .VTOTAL                 ( 525        ),
    .VSA                    ( 2          ),
    .VFP                    ( 10         ),
    .VBP                    ( 33         ),
    .VACTIVE                ( 480        ),
    .VIDEO_VIC              ( 1          ),
    .VIDEO_TPG              ( "Disable"  ),
    .VIDEO_FORMAT           ( "RGB"      ),
    .AUDIO_SAMPLE_RATE      ( "48K"      ),
    .IIC_SCL_DIV            ( 250        )
) u_hdmi_1_4b_transmitter_core_wrapper(
    .I_pixel_clk        (video_clk),
    .I_rst              (rst_vga),
    .I_edid_read_trig   (edid_trig),
    .O_edid_read_valid  (edid_valid),
    .O_edid_read_data   (edid_data),

    .I_axis_s_user      (axis_s_user),
    .I_axis_s_valid     (axis_s_valid),
    .I_axis_s_last      (axis_s_last),
    .I_axis_s_data      (axis_s_data),
    .O_axis_s_ready     (vga_ready),

    .I_audio_valid      (audio_valid),
    .I_audio_left_data  (audio_left),
    .I_audio_right_data (audio_right),
    .I_acr_valid        (audio_valid),
    .I_acr_cts          (20'd25000),
    .I_acr_n            (20'd6144),

    .O_video_locked     (),
    .O_ddc_scl          (HDMI_DDC_SCL),
    .IO_ddc_sda         (HDMI_DDC_SDA),

    .O_ch0_tmds_data    (vga_ch0),
    .O_ch1_tmds_data    (vga_ch1),
    .O_ch2_tmds_data    (vga_ch2),
    .O_clk_tmds_data    (vga_clk)
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

// Physical controls only in this build. Keep legacy package pins and source
// modules for compatibility, but serial/IR traffic cannot change the settings.
assign uart_tx_pin=1'b1;
assign tx_overflow=1'b0;
assign cmd_prev=1'b0;
assign osd_enable=1'b1;
assign test_pattern=1'b0;
// Cycle the three built-in slogans with the displayed image index.
assign slogan_select=(status_index==3)?2'd0:status_index;
picture_controls #(.BOARD_MENU(1),.AUDIO_MENU(1)) buttons(.clk(sd_card_clk),.rst(rst_sd),
 .key1_n(key1),.key2_n(key2),.key3_n(key3),.next_pulse(cmd_next),.toggle_pulse(cmd_toggle),
 .brightness(brightness),.contrast(contrast),.edit_mode(edit_mode),
 .menu_open(menu_open),.menu_item(menu_item),.gamma_enable(gamma_enable),
 .debug_enable(debug_enable),.debug_page(debug_page),.audio_volume(volume),.audio_mute(mute));
switch_controls switches(.clk(sd_card_clk),.rst(rst_sd),.sw(sw),
 .captions_enable(captions_enable),.scroll_enable(scroll_enable),
 .transition_mode(transition_mode));
cdc_snapshot #(.WIDTH(70)) status_cdc(.src_clk(sd_card_clk),.src_rst(rst_sd),
 .src_data(status_source),.dst_clk(video_clk),.dst_rst(rst_video),.dst_data(status_video));
frame_swap #(.ENABLE_EFFECTS(1),.ADAPTIVE(1)) swap(.mode_800(mode_video),.clk(video_clk),.rst(rst_video),.vblank(vblank),
 .request_toggle(commit_req),.requested_buffer(commit_buffer),
 .ack_toggle(commit_ack),.active_buffer(active_buffer),.display_valid(visible),
 .transition_mode(video_effect),.effect_mode(running_effect),.fade_level(fade_level),
 .slide_offset(slide_offset),.transition_busy(transition_busy));
video_coordinates source_coordinates(video_clk,rst_video,vs,de,pixel_x,pixel_y);
assign source_rgb=video_pattern ? {pixel_x[7:0],pixel_y[7:0],8'h80} : vout_data;
picture_adjust enhance(.clk(video_clk),.rst(rst_video),.vs(vs),.de(de),.x(pixel_x),
 .rgb(source_rgb),.brightness(frame_brightness),.contrast(frame_contrast),
 .out_vs(adjusted_vs),.out_de(adjusted_de),.out_x(adjusted_x),.out_rgb(enhanced_rgb));
picture_gamma gamma(.clk(video_clk),.rst(rst_video),.vs(adjusted_vs),.de(adjusted_de),
 .x(adjusted_x),.rgb(enhanced_rgb),.enable(frame_ui[4]),
 .out_vs(gamma_vs),.out_de(gamma_de),.out_x(gamma_x),.out_rgb(gamma_rgb));
transition_pixels effects(.clk(video_clk),.rst(rst_video),.vs(gamma_vs),.de(gamma_de),
 .x(gamma_x),.rgb(gamma_rgb),.effect_mode(running_effect),
 .fade_level(fade_level),.slide_offset(slide_offset),
 .out_vs(transition_vs),.out_de(transition_de),.out_rgb(transition_rgb));
caption_overlay #(.ADAPTIVE(1)) captions(.mode_800(mode_video),.clk(video_clk),.rst(rst_video),.vs(transition_vs),.de(transition_de),
 .rgb(transition_rgb),.enable(video_captions),.scroll_enable(video_scroll),
 .slogan_select(video_slogan),.transition_mode(video_effect),
 .out_vs(caption_vs),.out_de(caption_de),.out_rgb(caption_rgb));
status_osd #(.ENHANCED_UI(1),.ADAPTIVE(1),.PIPELINED(1),.BOARD_UI(1),.AUDIO_UI(1),.AUDIO_DIAGNOSTICS(1)) osd(.out_vs(osd_vs),.out_de(osd_de),.mode_800(mode_video),.clk(video_clk),.rst(rst_video),.vs(caption_vs),.de(caption_de),.rgb(caption_rgb),
 .enable(video_osd),.auto_play(video_auto),.image_index(video_index),.image_count(video_count),
 .volume(video_volume),.mute(video_mute),.busy(video_busy),
 .error(video_error | memory_underflow | memory_overflow_video[1]),.edid_ok(edid_good_vff[1]),
 .result(osd_rgb),.pixel_x(),.pixel_y(),
 .brightness(frame_brightness),.contrast(frame_contrast),.edit_mode(frame_edit_mode),
 .source_width(frame_source_width),.source_height(frame_source_height),
 .menu_open(frame_ui[0]),.menu_item(frame_ui[3:1]),.gamma_enable(frame_ui[4]),
 .debug_enable(frame_ui[5]),.debug_page(frame_ui[7:6]),
 .audio_ready(frame_audio_status[0]),.audio_error(|frame_audio_error_code),
 .audio_error_code(frame_audio_error_code),.audio_underflow(frame_audio_underflow));
// 音频流有效标志单独整体跨域，不等待显示帧锁存；错误同时清空队列。
cdc_snapshot #(.WIDTH(2)) audio_state_cdc(.src_clk(sd_card_clk),.src_rst(rst_sd),
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
wire audio_src_valid;
wire [23:0] audio_src_left,audio_src_right;
audio_playback #(.ADAPTIVE(1)) audio_source(.clk(video_clk),.rst(rst_video),.volume(video_volume),
 .mute(video_mute),.mode_800(mode_video),.stream_ok(audio_stream_video[0] && !audio_stream_video[1] && !video_mute),
 .fifo_empty(audio_fifo_empty),.fifo_used(audio_rd_used),.fifo_data(audio_fifo_data),.fifo_rd_en(audio_fifo_read),
 .valid(audio_src_valid),.left_pcm(audio_src_left),.right_pcm(audio_src_right),.underflow(audio_underflow),.pcm_valid(audio_pcm_valid));
`ifdef AUDIO_EFFECTS_ENABLED_BUILD
    // Optional fixed build profile; no runtime controls or CDC are added.
    audio_effects #(.BASS_GAIN(16'sd3276),.TREBLE_GAIN(16'sd3276),
     .ECHO_FEEDBACK(16'sd22938)) fx(.clk(video_clk),.rst(rst_video),
`else
    audio_effects fx(.clk(video_clk),.rst(rst_video),
`endif
 .src_valid(audio_src_valid),.src_left(audio_src_left),.src_right(audio_src_right),
 .out_valid(audio_valid),.out_left(audio_left),.out_right(audio_right));
edid_display_mode edid_check(.clk(boot_clk),.rst(rst_boot),.start(edid_trig),
 .valid(edid_valid_boot),.data(edid_data_boot),.done(mode_done),.good(edid_good),
 .mode_800(mode_800),.fallback(mode_fallback));
assign edid_done=mode_done;

endmodule
