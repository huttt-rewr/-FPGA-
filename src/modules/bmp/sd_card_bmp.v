
module sd_card_bmp #(
    parameter integer INDEXED=0,parameter integer MAX_FILES=64,
    parameter integer CLK_FREQ_HZ       = 100_000_000,
    parameter [31:0]  SCAN_START_SECTOR = 32'd0,
    parameter [31:0]  SCAN_MAX_SECTOR   = 32'd131071,
    parameter [2:0]   SCAN_TARGET_COUNT = 3'd4,
    parameter integer READ_STALL_CYCLES = 67_108_864,
    parameter ADAPTIVE = 0,
    parameter ENABLE_SCALING = 0,
    parameter ENABLE_AUDIO = 0,
    parameter [31:0] AUDIO_START_SECTOR = 131072,
    parameter FAT32_ENABLE = 0,
    parameter MAX_BMP = 4
)(
    input                       clk,
    input                       rst,
    input                       key_next,
    input                       key_auto,
    input                       cmd_next,
    input                       cmd_prev,
    input                       cmd_toggle,
    input                       commit_ack_toggle,
    output reg                  commit_req_toggle,
    output reg [1:0]            commit_buffer,
    output                      status_auto,
    output [1:0]                status_index,
    output [2:0]                status_count,
    output                      status_busy,
    output reg                  status_error,
    input  [15:0]               bmp_width,
    input  [15:0]               bmp_height,
    output reg                  display_valid,
    output      [3:0]           state_code,

    input                       write_finish_toggle,
    output reg [1:0]            write_buf_idx,
    output reg [1:0]            disp_buf_idx,

    output                      write_req,
    input                       write_req_ack,
    output                      write_en,
    output [31:0]               write_data,
    output                      SD_nCS,
    output                      SD_DCLK,
    output                      SD_MOSI,
    input                       SD_MISO,
    input                       pixel_ready,
    output reg [11:0]            image_width,image_height,
    output [3:0]                debug_sd_status,
    input audio_enable,input audio_sample_ready,input audio_sector_room,
    output audio_sample_valid,output [23:0] audio_sample,
    output audio_error,audio_ready,output reg audio_stream_reset,
    output [3:0] audio_error_code,
    input [7:0] image_select_index,audio_select_index,
    input image_select_valid,audio_select_valid,
    output [6:0] media_image_index,media_image_count,media_audio_index,media_audio_count,
    output media_truncated
);

wire fat_done,fat_error,fat_wav_found;
wire [6:0] fat_audio_count;wire fat_audio_idle;
reg [6:0]        img_found_count;
reg [5:0]        img_idx;
wire [11:0] source_width,source_height;
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

wire key_next_press;
wire key_auto_press;

wire             sd_sec_read;
wire [31:0]      sd_sec_read_addr;
wire [7:0]       sd_sec_read_data;
wire             sd_sec_read_data_valid;
wire             sd_sec_read_end;
wire [3:0]       state_code_i;
wire             bmp_data_wr_en;
wire [23:0]      bmp_data;
wire             sd_init_done;
wire             sd_init_error;
wire             sd_transfer_error;
wire raw_transfer_error,transport_reset;
reg load_abort;
wire bmp_grant,bmp_transfer_error;
wire card_read,card_valid,card_end;
wire [31:0] card_addr;
wire [7:0] card_data;
wire aud_req,aud_valid,aud_end,aud_read_error;
wire [31:0] aud_addr;
wire [7:0] aud_data;
// 必须在generate实例之前声明，避免TD把前向引用当作局部隐式wire。
reg [5:0] load_idx;

wire [(INDEXED?7:3)-1:0] fat_count;

wire [3:0] fat_error_code;
wire [MAX_BMP*32-1:0] fat_sizes;
wire [31:0] fat_wav_size;
wire phy_bmp_req,phy_bmp_valid,phy_bmp_end,phy_bmp_error,phy_bmp_grant;
wire [31:0] phy_bmp_addr;
wire [7:0] phy_bmp_data;
wire phy_aud_req,phy_aud_valid,phy_aud_end,phy_aud_error;
wire [31:0] phy_aud_addr;
wire [7:0] phy_aud_data;
generate if(FAT32_ENABLE)begin: filesystem
 sd_fat32 #(.MAX_BMP(MAX_BMP),.INDEXED(INDEXED),.MAX_FILES(MAX_FILES)) fat(.clk(clk),.rst(rst),.sd_init_done(sd_init_done),
  .mount_done(fat_done),.mount_error(fat_error),.mount_error_code(fat_error_code),
  .bmp_count(fat_count),.wav_found(fat_wav_found),.bmp_size(fat_sizes),.wav_size(fat_wav_size),
  .bmp_req(sd_sec_read),.bmp_file_idx(INDEXED?{1'b0,load_idx}:load_idx[2:0]),.bmp_rel_sector(sd_sec_read_addr),
  .bmp_data(sd_sec_read_data),.bmp_valid(sd_sec_read_data_valid),.bmp_end(sd_sec_read_end),
  .bmp_error(bmp_transfer_error),.bmp_grant(bmp_grant),.bmp_abort(load_abort),
  .aud_req(aud_req),.aud_file_idx(audio_active),.aud_abort(audio_switching),.aud_idle(fat_audio_idle),
  .wav_count(fat_audio_count),.files_truncated(media_truncated),.aud_rel_sector(aud_addr),.aud_data(aud_data),.aud_valid(aud_valid),
  .aud_end(aud_end),.aud_error(aud_read_error),
  .arb_bmp_req(phy_bmp_req),.arb_bmp_addr(phy_bmp_addr),.arb_bmp_data(phy_bmp_data),
  .arb_bmp_valid(phy_bmp_valid),.arb_bmp_end(phy_bmp_end),.arb_bmp_error(phy_bmp_error),.arb_bmp_grant(phy_bmp_grant),
  .arb_aud_req(phy_aud_req),.arb_aud_addr(phy_aud_addr),.arb_aud_data(phy_aud_data),
  .arb_aud_valid(phy_aud_valid),.arb_aud_end(phy_aud_end),.arb_aud_error(phy_aud_error));
end else begin: raw_compatibility
 assign fat_audio_count=0;assign fat_audio_idle=1;assign media_truncated=0;
 assign fat_done=0;assign fat_error=0;assign fat_count=0;assign fat_wav_found=0;
 assign fat_sizes=0;assign fat_wav_size=0;assign fat_error_code=0;
 assign phy_bmp_req=sd_sec_read;assign phy_bmp_addr=sd_sec_read_addr;
 assign sd_sec_read_data=phy_bmp_data;assign sd_sec_read_data_valid=phy_bmp_valid;
 assign sd_sec_read_end=phy_bmp_end;assign bmp_transfer_error=phy_bmp_error;assign bmp_grant=phy_bmp_grant;
 assign phy_aud_req=aud_req;assign phy_aud_addr=aud_addr;assign aud_data=phy_aud_data;
 assign aud_valid=phy_aud_valid;assign aud_end=phy_aud_end;assign aud_read_error=phy_aud_error;
end endgenerate
assign sd_transfer_error=(ENABLE_AUDIO || FAT32_ENABLE)?bmp_transfer_error:raw_transfer_error;
// Register the shared flush at its source. Global reset still asserts at once;
// local abort/error/switch requests take one SD clock, before any new stream
// can parse a header or enqueue PCM. The FIFO/effects release locally per clock.
always @(posedge clk or posedge rst)begin
 if(rst)audio_stream_reset<=1'b1;
 else audio_stream_reset<=load_abort || audio_switching || transport_reset || !sd_init_done || audio_error;
end
assign audio_error=|audio_error_code;
generate if(ENABLE_AUDIO || FAT32_ENABLE)begin: wav_enabled
 sd_read_arbiter #(.TIMEOUT_CYCLES(READ_STALL_CYCLES)) arbiter(
  .clk(clk),.rst(rst | (load_abort && !FAT32_ENABLE)),.sd_ready(sd_init_done),
  .bmp_req(phy_bmp_req),.bmp_addr(phy_bmp_addr),.bmp_data(phy_bmp_data),
  .bmp_valid(phy_bmp_valid),.bmp_end(phy_bmp_end),
  .bmp_error(phy_bmp_error),.bmp_grant(phy_bmp_grant),
  .aud_req(phy_aud_req),.aud_addr(phy_aud_addr),.aud_data(phy_aud_data),
  .aud_valid(phy_aud_valid),.aud_end(phy_aud_end),.aud_error(phy_aud_error),
  .sd_req(card_read),.sd_addr(card_addr),.sd_data(card_data),
  .sd_valid(card_valid),.sd_end(card_end),.sd_error(raw_transfer_error),
  .transport_reset(transport_reset));
 audio_wav #(.START_SECTOR(AUDIO_START_SECTOR),.FILESYSTEM(FAT32_ENABLE)) wav(
  .clk(clk),.rst(rst | load_abort | audio_switching),.sd_init_done(sd_init_done),
  .enable(ENABLE_AUDIO && audio_enable && (!FAT32_ENABLE || (fat_done && fat_wav_found))),.sector_room(audio_sector_room),.sample_ready(audio_sample_ready),
  .req(aud_req),.addr(aud_addr),.data(aud_data),.data_valid(aud_valid),
  .sector_end(aud_end),.read_error(aud_read_error),
  .sample_valid(audio_sample_valid),.sample(audio_sample),.error(),.error_code(audio_error_code),.ready(audio_ready));
end else begin: wav_disabled
 assign card_read=phy_bmp_req;assign card_addr=phy_bmp_addr;
 assign phy_bmp_data=card_data;assign phy_bmp_valid=card_valid;assign phy_bmp_end=card_end;
 assign phy_bmp_grant=1'b1;assign phy_bmp_error=raw_transfer_error;
 assign phy_aud_data=0;assign phy_aud_valid=0;assign phy_aud_end=0;assign phy_aud_error=0;
 assign aud_req=0;assign aud_addr=0;
 assign transport_reset=0;assign audio_sample_valid=0;assign audio_sample=0;
 assign audio_error_code=0;assign audio_ready=0;
end endgenerate
assign debug_sd_status={sd_init_done,sd_init_error,sd_transfer_error,status_error};
wire             read_stall;
wire             bmp_ready;
wire scan_done,bmp_scan_done;
assign scan_done=INDEXED?fat_done:bmp_scan_done;
wire scan_found_valid,bmp_scan_found_valid;
assign scan_found_valid=INDEXED?1'b0:bmp_scan_found_valid;
wire [31:0]      scan_found_sector;
wire [2:0]       scan_found_total;

reg              scan_start_pulse;
reg              load_start_pulse;
reg [31:0]       load_sector;
reg              scan_kicked;
reg              first_image_committed;
reg              auto_play_en;
reg [31:0]       auto_cnt;

              // 当前真正显示中的图片编号
reg [1:0]        pending_buf_idx;      // 当前正在写入的目标缓冲区
reg [31:0]       img_sector0;
reg [31:0]       img_sector1;
reg [31:0]       img_sector2;
reg [31:0]       img_sector3;
reg              next_req_pending;
reg              load_busy;
reg [31:0]       load_timeout_cnt;


// bmp_ready 先表示“源文件读取/送 FIFO 完成”；真正切显示要等 write_finish_toggle 同步后
reg              source_done_seen;
reg              write_done_seen;

// 同步 mem_clk 域的 write_finish_toggle
(* async_reg="true" *) reg [2:0] wrfin_tgl_sync;
wire             write_finish_pulse;

reg commit_wait;
reg source_started;
reg prev_requested;
(* async_reg="true" *) reg [2:0] ack_sync;
assign status_auto = auto_play_en;
assign status_index = img_idx[1:0];
assign status_count = img_found_count[2:0];
assign status_busy = load_busy;
wire auto_tick;
wire [5:0] next_from_current;
reg direct_pending;reg [5:0] direct_index;
wire [5:0] requested_next=direct_pending?direct_index:next_from_current;

assign write_en   = bmp_data_wr_en;
assign write_data = {bmp_data[23:16], bmp_data[15:8], bmp_data[7:0], 8'b0};
assign auto_tick  = (auto_cnt == (CLK_FREQ_HZ - 1));
assign next_from_current = prev_requested ?
    ((img_idx == 0) ? img_found_count[5:0] - 6'd1 : img_idx - 2'd1) :
    next_index_limited(img_idx, img_found_count);
assign write_finish_pulse = wrfin_tgl_sync[2] ^ wrfin_tgl_sync[1];
// 挂载失败时在原状态数码管显示8+错误码，不增加物理引脚或跨域总线。
assign state_code = (FAT32_ENABLE && fat_error)?(4'd8+fat_error_code):state_code_i;

key_press_debounce #(
    .CLK_FREQ_HZ (CLK_FREQ_HZ),
    .DEBOUNCE_MS (50)
) u_key_next (
    .clk        (clk),
    .rst        (rst),
    .button_in  (key_next),
    .press_pulse(key_next_press)
);

key_press_debounce #(
    .CLK_FREQ_HZ (CLK_FREQ_HZ),
    .DEBOUNCE_MS (50)
) u_key_auto (
    .clk        (clk),
    .rst        (rst),
    .button_in  (key_auto),
    .press_pulse(key_auto_press)
);

function [5:0] next_index_limited;
    input [5:0] cur;
    input [6:0] count;
    begin
        next_index_limited=({1'b0,cur}+7'd1>=count)?6'd0:cur+6'd1;
    end
endfunction

function [31:0] sector_lut;
    input [1:0] idx;
    begin
        case (idx)
            2'd0: sector_lut = img_sector0;
            2'd1: sector_lut = img_sector1;
            2'd2: sector_lut = img_sector2;
            2'd3: sector_lut = img_sector3;
            default: sector_lut = img_sector0;
        endcase
    end
endfunction

function [1:0] next_buf_lut;
    input [1:0] cur_disp_buf;
    input       valid_now;
    begin
        if (!valid_now)
            next_buf_lut = 2'd0;                 // 首图固定写 buffer0
        else if (cur_disp_buf == 2'd0)
            next_buf_lut = 2'd1;
        else
            next_buf_lut = 2'd0;
    end
endfunction

always @(posedge clk or posedge rst) begin
    if (rst) begin
        image_width<=0;image_height<=0;
        wrfin_tgl_sync        <= 3'b000;
        ack_sync <= 0;
        commit_wait <= 0;
        source_started <= 0;
        prev_requested <= 0;
        commit_req_toggle <= 0;
        commit_buffer <= 0;
        status_error <= 0;
        scan_start_pulse      <= 1'b0;
        load_start_pulse      <= 1'b0;
        load_sector           <= 32'd0;
        scan_kicked           <= 1'b0;
        first_image_committed <= 1'b0;
        auto_play_en          <= 1'b0;
        auto_cnt              <= 32'd0;
        img_found_count       <= 3'd0;
        img_idx               <= 2'd0;
        load_idx              <= 2'd0;
        pending_buf_idx       <= 2'd0;
        write_buf_idx         <= 2'd0;
        disp_buf_idx          <= 2'd0;
        img_sector0           <= 32'd0;
        img_sector1           <= 32'd0;
        img_sector2           <= 32'd0;
        img_sector3           <= 32'd0;
        next_req_pending      <= 1'b0;direct_pending<=0;direct_index<=0;
        load_busy             <= 1'b0;
        load_timeout_cnt      <= 32'd0;
        load_abort            <= 1'b0;
        source_done_seen      <= 1'b0;
        write_done_seen       <= 1'b0;
        display_valid         <= 1'b0;
    end else begin
        ack_sync <= {ack_sync[1:0], commit_ack_toggle};
        wrfin_tgl_sync   <= {wrfin_tgl_sync[1:0], write_finish_toggle};
        scan_start_pulse <= 1'b0;
        load_start_pulse <= 1'b0;
        load_abort       <= 1'b0;

        if (sd_init_error || fat_error) status_error <= 1'b1;

        if ((read_stall || sd_transfer_error) && !commit_wait) begin
            // Abort an incomplete sector instead of calling it a successful read.
            // A scan restarts after re-init; an indexed load retains the old frame
            // and requires a next/previous command to retry.
            status_error <= 1'b1;
            load_abort <= 1'b1;
            load_busy <= 1'b0;
            load_timeout_cnt <= 0;
            source_started <= 0;
            source_done_seen <= 0;
            write_done_seen <= 0;
            next_req_pending <= 0;
        end else if (!sd_init_done && !scan_done) begin
            scan_kicked           <= 1'b0;
            first_image_committed <= 1'b0;
            auto_play_en          <= 1'b0;
            auto_cnt              <= 32'd0;
            img_found_count       <= 3'd0;
            img_idx               <= 2'd0;
            load_idx              <= 2'd0;
            pending_buf_idx       <= 2'd0;
            write_buf_idx         <= 2'd0;
            disp_buf_idx          <= 2'd0;
            img_sector0           <= 32'd0;
            img_sector1           <= 32'd0;
            img_sector2           <= 32'd0;
            img_sector3           <= 32'd0;
            next_req_pending      <= 1'b0;direct_pending<=0;direct_index<=0;
            load_busy             <= 1'b0;
            load_timeout_cnt      <= 32'd0;
            load_abort            <= 1'b0;
            source_done_seen      <= 1'b0;
            write_done_seen       <= 1'b0;
            display_valid         <= 1'b0;
        end else begin
            if(INDEXED && fat_done)img_found_count<=fat_count;
            if (scan_found_valid) status_error <= 1'b0;
            // 扫描阶段缓存前 4 张图的起始 sector
            if (scan_found_valid) begin
                case (img_found_count)
                    3'd0: img_sector0 <= scan_found_sector;
                    3'd1: img_sector1 <= scan_found_sector;
                    3'd2: img_sector2 <= scan_found_sector;
                    3'd3: img_sector3 <= scan_found_sector;
                    default: ;
                endcase

                if (img_found_count < 3'd4)
                    img_found_count <= img_found_count + 3'd1;
            end

            // 记住 bmp_read 已经把源图送完 FIFO，但还不能切显示，得等整帧写完
            if (load_busy && !bmp_ready) source_started <= 1;
            if (load_busy && source_started && bmp_ready)
                source_done_seen <= 1'b1;

            // 记住写帧完成脉冲，避免“先写完后源结束”导致脉冲丢失而卡死
            if (load_busy && write_finish_pulse)
                write_done_seen <= 1'b1;

            // 只有“源图送完 + 整帧写完”都满足，才提交新图并切换显示缓冲区
            if (load_busy && source_done_seen && write_done_seen && !commit_wait) begin
                commit_buffer <= pending_buf_idx;
                commit_req_toggle <= ~commit_req_toggle;
                commit_wait <= 1;
                load_timeout_cnt <= 0;
            end else if (load_busy && commit_wait && (ack_sync[2] == commit_req_toggle)) begin
                commit_wait <= 0;
                load_busy             <= 1'b0;
                load_timeout_cnt      <= 32'd0;
                source_done_seen      <= 1'b0;
                write_done_seen       <= 1'b0;
                disp_buf_idx          <= pending_buf_idx;
                img_idx               <= load_idx;
                image_width<=source_width;image_height<=source_height;
                display_valid         <= 1'b1;
                first_image_committed <= 1'b1;
                status_error          <= 1'b0;
            end else if (load_busy) begin
                if (!status_error && commit_wait && load_timeout_cnt > CLK_FREQ_HZ * 5) begin
                    // No fabricated ack: quarantine both buffers until a real
                    // (possibly late) ack arrives or the whole design is reset.
                    status_error <= 1'b1;
                end else if (!status_error && !commit_wait && load_timeout_cnt > CLK_FREQ_HZ * (ENABLE_SCALING?15:5)) begin
                    // Abort transport and release the failed load. Keep the displayed buffer.
                    load_busy             <= 1'b0;
                    status_error          <= 1'b1;
                    load_timeout_cnt      <= 32'd0;
                    source_done_seen      <= 1'b0;
                    write_done_seen       <= 1'b0;
                    load_abort            <= 1'b1;
                end else if (!status_error) begin
                    load_timeout_cnt <= load_timeout_cnt + 32'd1;
                end
            end else begin
                load_timeout_cnt <= 32'd0;
            end

            // 上电后自动发起一次“扫描前 4 张 BMP”
            if (!scan_kicked && bmp_ready && sd_init_done) begin
                scan_start_pulse      <= 1'b1;
                scan_kicked           <= 1'b1;
                first_image_committed <= 1'b0;
                auto_play_en          <= 1'b0;
                auto_cnt              <= 32'd0;
                img_found_count       <= 3'd0;
                img_idx               <= 2'd0;
                load_idx              <= 2'd0;
                pending_buf_idx       <= 2'd0;
                write_buf_idx         <= 2'd0;
                disp_buf_idx          <= 2'd0;
                next_req_pending      <= 1'b0;direct_pending<=0;direct_index<=0;
                display_valid         <= 1'b0;
                load_busy             <= 1'b0;
                source_done_seen      <= 1'b0;
                write_done_seen       <= 1'b0;
            end else begin
                // 忙的时候也只记 1 次“下一张”请求，不会累积成连跳两张
                if ((key_next_press || cmd_next || cmd_prev) && scan_done && (img_found_count > 3'd0))
                    begin next_req_pending <= 1'b1; prev_requested <= cmd_prev;direct_pending<=0;end
                if(INDEXED && image_select_valid && scan_done && img_found_count!=0)begin
                    direct_index<=(image_select_index>=img_found_count)?6'd0:image_select_index[5:0];
                    direct_pending<=1;next_req_pending<=1;
                end

                // 自动播放开/关
                if ((key_auto_press || cmd_toggle) && scan_done && (img_found_count > 3'd1)) begin
                    auto_play_en <= ~auto_play_en;
                    auto_cnt     <= 32'd0;
                end

                // 自动播放 1s 计数：只有当前没有写图任务时才计时
                if (scan_done && auto_play_en && display_valid && !load_busy && first_image_committed && (img_found_count > 3'd1)) begin
                    if (auto_tick)
                        auto_cnt <= 32'd0;
                    else
                        auto_cnt <= auto_cnt + 32'd1;
                end else begin
                    auto_cnt <= 32'd0;
                end

                // 首图自动加载到 buffer0
                if (scan_done && sd_init_done && !status_error && !first_image_committed && bmp_ready && !load_busy && (img_found_count != 3'd0)) begin
                    load_idx         <= INDEXED?((image_select_index>=img_found_count)?6'd0:image_select_index[5:0]):6'd0;
                    load_sector      <= INDEXED?0:img_sector0;
                    pending_buf_idx  <= 2'd0;
                    write_buf_idx    <= 2'd0;
                    load_start_pulse <= 1'b1;
                    status_error <= 1'b0;
                    source_started <= 0;
                    prev_requested <= 0;
                    load_busy        <= 1'b1;
                    source_done_seen <= 1'b0;
                    write_done_seen  <= 1'b0;
                    next_req_pending <= 1'b0;direct_pending<=0;
                    auto_cnt         <= 32'd0;
                end
                // 手动下一张优先：写到“非当前显示”的另一块 buffer
                else if (scan_done && sd_init_done && bmp_ready && !load_busy && next_req_pending && (img_found_count != 3'd0)) begin
                    load_idx         <= requested_next;
                    load_sector      <= INDEXED?0:sector_lut(requested_next[1:0]);
                    pending_buf_idx  <= next_buf_lut(disp_buf_idx, display_valid);
                    write_buf_idx    <= next_buf_lut(disp_buf_idx, display_valid);
                    load_start_pulse <= 1'b1;
                    status_error <= 1'b0;
                    source_started <= 0;
                    prev_requested <= 0;
                    load_busy        <= 1'b1;
                    source_done_seen <= 1'b0;
                    write_done_seen  <= 1'b0;
                    next_req_pending <= 1'b0;direct_pending<=0;
                    auto_cnt         <= 32'd0;
                end
                // 自动播放下一张：同样写到“非当前显示”的另一块 buffer
                else if (scan_done && sd_init_done && !status_error && bmp_ready && display_valid && !load_busy && auto_play_en && auto_tick && (img_found_count > 3'd1)) begin
                    load_idx         <= requested_next;
                    load_sector      <= INDEXED?0:sector_lut(requested_next[1:0]);
                    pending_buf_idx  <= next_buf_lut(disp_buf_idx, display_valid);
                    write_buf_idx    <= next_buf_lut(disp_buf_idx, display_valid);
                    load_start_pulse <= 1'b1;
                    status_error <= 1'b0;
                    source_started <= 0;
                    prev_requested <= 0;
                    load_busy        <= 1'b1;
                    source_done_seen <= 1'b0;
                    write_done_seen  <= 1'b0;
                    auto_cnt         <= 32'd0;
                end
            end
        end
    end
end

bmp_read #(.FILESYSTEM(FAT32_ENABLE),.SHARED_SD(ENABLE_AUDIO || FAT32_ENABLE),.READ_STALL_CYCLES(READ_STALL_CYCLES),.ADAPTIVE(ADAPTIVE),.ENABLE_SCALING(ENABLE_SCALING)) bmp_read_m0(
    .clk                    (clk),
    .rst                    (rst),
    .ready                  (bmp_ready),

    .scan_start             (scan_start_pulse),
    .scan_start_sector      (SCAN_START_SECTOR),
    .scan_max_sector        (SCAN_MAX_SECTOR),
    .scan_target_count      (SCAN_TARGET_COUNT),
    .fs_mount_done(fat_done),.fs_bmp_count(INDEXED?3'd0:fat_count[2:0]),
    .scan_done              (bmp_scan_done),
    .scan_found_valid       (bmp_scan_found_valid),
    .scan_found_sector      (scan_found_sector),
    .scan_found_total       (scan_found_total),

    .load_start             (load_start_pulse),
    .load_abort             (load_abort),
    .load_sector            (load_sector),

    .sd_init_done           (sd_init_done),.read_granted(bmp_grant),
    .state_code             (state_code_i),
    .bmp_width              (bmp_width),
    .bmp_height             (bmp_height),
    .write_req              (write_req),
    .write_req_ack          (write_req_ack),
    .sd_sec_read            (sd_sec_read),
    .sd_sec_read_addr       (sd_sec_read_addr),
    .sd_sec_read_data       (sd_sec_read_data),
    .sd_sec_read_data_valid (sd_sec_read_data_valid),
    .sd_sec_read_end        (sd_sec_read_end),
    .bmp_data_wr_en         (bmp_data_wr_en),
    .bmp_data               (bmp_data),
    .read_stall             (read_stall),
    .pixel_ready(pixel_ready),.source_width(source_width),.source_height(source_height)
);

sd_card_top sd_card_top_m0(
    .clk                    (clk),
    .rst                    (rst | (load_abort && !FAT32_ENABLE) | transport_reset),
    .SD_nCS                 (SD_nCS),
    .SD_DCLK                (SD_DCLK),
    .SD_MOSI                (SD_MOSI),
    .SD_MISO                (SD_MISO),
    .sd_init_done           (sd_init_done),
    .sd_init_error              (sd_init_error),
    .sd_transfer_error      (raw_transfer_error),
    .sd_sec_read            (card_read),
    .sd_sec_read_addr       (card_addr),
    .sd_sec_read_data       (card_data),
    .sd_sec_read_data_valid (card_valid),
    .sd_sec_read_end        (card_end),
    .sd_sec_write           (1'b0),
    .sd_sec_write_addr      (32'd0),
    .sd_sec_write_data      (8'd0),
    .sd_sec_write_data_req  (),
    .sd_sec_write_end       ()
);

endmodule

module key_press_debounce #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer DEBOUNCE_MS = 20
)(
    input  wire clk,
    input  wire rst,
    input  wire button_in,    // 默认：松开=1，按下=0
    output reg  press_pulse
);

localparam integer DEBOUNCE_CYCLES = (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;

reg button_sync0;
reg button_sync1;
reg button_stable;
reg [31:0] cnt;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        button_sync0  <= 1'b1;
        button_sync1  <= 1'b1;
        button_stable <= 1'b1;
        cnt           <= 32'd0;
        press_pulse   <= 1'b0;
    end else begin
        button_sync0 <= button_in;
        button_sync1 <= button_sync0;
        press_pulse  <= 1'b0;

        if (button_sync1 == button_stable) begin
            cnt <= 32'd0;
        end else begin
            if (cnt >= DEBOUNCE_CYCLES - 1) begin
                if (button_stable && !button_sync1)
                    press_pulse <= 1'b1;
                button_stable <= button_sync1;
                cnt           <= 32'd0;
            end else begin
                cnt <= cnt + 32'd1;
            end
        end
    end
end

endmodule
