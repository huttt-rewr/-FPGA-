module bmp_read #(
    parameter integer READ_STALL_CYCLES = 67_108_864,
    parameter ADAPTIVE = 0,
    parameter ENABLE_SCALING = 0,
    parameter SHARED_SD = 0,
    parameter FILESYSTEM = 0
)(
    input                       clk,
    input                       rst,
    output                      ready,

    // 上电扫描：从 scan_start_sector 开始，顺序寻找前 scan_target_count 张 BMP
    input                       scan_start,
    input  [31:0]               scan_start_sector,
    input  [31:0]               scan_max_sector,
    input  [2:0]                scan_target_count,
    input                       fs_mount_done,
    input  [2:0]                fs_bmp_count,
    output reg                  scan_done,
    output reg                  scan_found_valid,
    output reg [31:0]           scan_found_sector,
    output reg [2:0]            scan_found_total,

    // 按指定扇区加载一张图到 SDRAM
    input                       load_start,
    input                       load_abort,
    input  [31:0]               load_sector,

    input                       sd_init_done,
    input                       read_granted,
    output reg [3:0]            state_code,
    input  [15:0]               bmp_width,
    input  [15:0]               bmp_height,

    output reg                  write_req,
    input                       write_req_ack,

    output                  sd_sec_read,
    output [31:0]           sd_sec_read_addr,
    input  [7:0]                sd_sec_read_data,
    input                       sd_sec_read_data_valid,
    input                       sd_sec_read_end,

    output                  bmp_data_wr_en,
    output [23:0]           bmp_data,
    output                      read_stall,
    input                       pixel_ready,
    output [11:0]               source_width,source_height
);

reg raw_sd_sec_read,raw_bmp_data_wr_en,raw_stall;
reg [31:0] raw_sd_sec_read_addr;
reg [23:0] raw_bmp_data;
localparam ST_SCALE = 3'd5;
localparam ST_IDLE      = 3'd0;
localparam ST_SCAN      = 3'd1;
localparam ST_LOAD_HDR  = 3'd2;
localparam ST_LOAD_WAIT = 3'd3;
localparam ST_LOAD_DATA = 3'd4;

reg [2:0]  state;
reg [9:0]  rd_cnt;
reg header_byte_valid;
reg [7:0] header_byte;
reg [9:0] header_byte_index;
always @(posedge clk or posedge rst) begin
    if(rst) begin header_byte_valid<=0; header_byte<=0; header_byte_index<=0; end
    else begin
        header_byte_valid<=sd_sec_read_data_valid && ((state==ST_SCAN)||(state==ST_LOAD_HDR));
        header_byte<=sd_sec_read_data;
        header_byte_index<=rd_cnt;
    end
end

reg [7:0]  header_0;
reg [7:0]  header_1;
reg [31:0] file_len;
reg [31:0] pixel_offset;
reg [31:0] dib_size;
reg [15:0] planes;
reg [31:0] width;
reg [31:0] height;
reg [15:0] bit_count;
reg [31:0] compression;

reg [31:0] scan_sector;
reg [31:0] load_sector_latched;
reg [31:0] bmp_len_cnt;
reg [1:0]  bmp_byte_idx;

(* async_reg="true" *) reg [2:0] write_ack_sync;
always @(posedge clk or posedge rst) begin
    if (rst) write_ack_sync <= 0;
    else write_ack_sync <= {write_ack_sync[1:0], write_req_ack};
end
reg header_match;
reg header_format_ok,header_dimensions_ok,header_offset_ok,header_length_ok;
// Count absent sector progress, including a command that never returns.
// Parameterized for fault-injection tests; 0.671 s at 100 MHz by default.
reg [31:0] stall_cnt;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        stall_cnt <= 0;
        raw_stall <= 0;
    end else begin
        raw_stall <= 0;
        if (!sd_sec_read || load_abort || sd_sec_read_data_valid || sd_sec_read_end || (SHARED_SD && !read_granted))
            stall_cnt <= 0;
        else if (stall_cnt >= READ_STALL_CYCLES - 1) begin
            stall_cnt <= 0;
            raw_stall <= 1;
        end else stall_cnt <= stall_cnt + 1'b1;
    end
end
reg [12:0] source_stride;
reg [23:0] source_bytes;
reg [31:0] expected_file_len;
reg [31:0] rounded_file_len;
wire bmp_data_valid;
reg [31:0] file_sector_count;
reg [31:0] next_scan_sector_if_match;
reg scan_match_past_end;
wire [31:0] next_scan_sector_if_miss;

wire scaled_read,scaled_valid,scaled_done,scaled_error;
wire [31:0] scaled_address;
wire [23:0] scaled_pixel;
wire scale_start=ENABLE_SCALING && state==ST_LOAD_WAIT && write_ack_sync[2];
assign source_width=width[11:0];
assign source_height=height[11:0];
assign sd_sec_read=(ENABLE_SCALING && state==ST_SCALE)?scaled_read:raw_sd_sec_read;
assign sd_sec_read_addr=(ENABLE_SCALING && state==ST_SCALE)?scaled_address:raw_sd_sec_read_addr;
assign bmp_data_wr_en=ENABLE_SCALING?(scaled_valid && pixel_ready):raw_bmp_data_wr_en;
assign bmp_data=ENABLE_SCALING?scaled_pixel:raw_bmp_data;
assign read_stall=raw_stall | (ENABLE_SCALING && scaled_error);
generate if(ENABLE_SCALING)begin: scaling
 bmp_scale_loader #(.ADAPTIVE(ADAPTIVE)) loader(.clk(clk),.rst(rst || load_abort || !sd_init_done),.start(scale_start),
  .source_width(width[11:0]),.source_height(height[11:0]),.pixel_offset(pixel_offset),
  .base_sector(load_sector_latched),.sector_read(scaled_read),.sector_address(scaled_address),
  .sector_data(sd_sec_read_data),.sector_valid(sd_sec_read_data_valid),.sector_end(sd_sec_read_end),
  .pixel(scaled_pixel),.pixel_valid(scaled_valid),.pixel_ready(pixel_ready),
  .done(scaled_done),.error(scaled_error),.busy(),.mode_800(bmp_width==800));
end else begin
 assign scaled_read=0;assign scaled_address=0;assign scaled_pixel=0;
 assign scaled_valid=0;assign scaled_done=0;assign scaled_error=0;
end endgenerate

assign ready = (state == ST_IDLE);
always @(posedge clk or posedge rst) begin
    if (rst) begin
        header_match <= 0; expected_file_len <= 0; rounded_file_len <= 0; source_stride<=0; source_bytes<=0;
        header_format_ok<=0;header_dimensions_ok<=0;header_offset_ok<=0;header_length_ok<=0;
    end
    else begin
        source_stride<=((width[11:0]*13'd3+13'd3)>>2)<<2;
        source_bytes<=source_stride*height[11:0];
        expected_file_len <= pixel_offset + (ENABLE_SCALING?{8'd0,source_bytes}:32'd921600);
        rounded_file_len <= file_len + 32'd511;
        // Header fields settle hundreds of byte-times before sector_end.
        // Group validation first; the final acceptance stage has only four bits.
        header_format_ok <= (header_0 == "B") &&
                      (header_1 == "M") &&
                      ((dib_size == 40) || (dib_size == 108) || (dib_size == 124)) &&
                      (planes == 16'd1) &&
                      (bit_count    == 16'd24) &&
                      (compression  == 32'd0);
        header_dimensions_ok <= (ENABLE_SCALING ? (width>=1 && width<=1920 && height>=1 && height<=1080) :
                                (width == {16'd0,bmp_width} && height == {16'd0,bmp_height})) &&
                                (ENABLE_SCALING || ((bmp_width == 640) && (bmp_height == 480)));
        header_offset_ok <= (pixel_offset >= 54) && (pixel_offset <= 4096) &&
                            (pixel_offset >= dib_size + 32'd14);
        header_length_ok <= (file_len == expected_file_len);
        header_match <= header_format_ok && header_dimensions_ok && header_offset_ok && header_length_ok;
    end
end
assign bmp_data_valid = (sd_sec_read_data_valid == 1'b1) &&
                        (bmp_len_cnt >= pixel_offset) &&
                        (bmp_len_cnt <  file_len);
// Header is complete hundreds of byte-times before sector_end.
// Register rounding/zero selection separately from the scan address adder.
always @(posedge clk or posedge rst) begin
    if(rst) file_sector_count <= 32'd1;
    else file_sector_count <= (file_len == 32'd0) ? 32'd1 : (rounded_file_len >> 9);
end
always @(posedge clk or posedge rst) begin
    if(rst) begin next_scan_sector_if_match<=0;scan_match_past_end<=0;end
    else begin
        next_scan_sector_if_match <= scan_sector + file_sector_count;
        scan_match_past_end <= next_scan_sector_if_match > scan_max_sector;
    end
end
assign next_scan_sector_if_miss  = scan_sector + 32'd1;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        rd_cnt <= 10'd0;
    end else if ((state == ST_SCAN) || (state == ST_LOAD_HDR)) begin
        if (sd_sec_read_data_valid)
            rd_cnt <= rd_cnt + 10'd1;
        else if (sd_sec_read_end)
            rd_cnt <= 10'd0;
    end else begin
        rd_cnt <= 10'd0;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        header_0     <= 8'd0;
        header_1     <= 8'd0;
        file_len     <= 32'd0;
        pixel_offset <= 32'd54;
        dib_size     <= 32'd0;
        planes       <= 16'd0;
        width        <= 32'd0;
        height       <= 32'd0;
        bit_count    <= 16'd0;
        compression  <= 32'd0;
    end else if (((state == ST_SCAN) || (state == ST_LOAD_HDR)) && header_byte_valid) begin
        case (header_byte_index)
            10'd0 : header_0 <= header_byte;
            10'd1 : header_1 <= header_byte;

            10'd2 : file_len[7:0] <= header_byte;
            10'd3 : file_len[15:8] <= header_byte;
            10'd4 : file_len[23:16] <= header_byte;
            10'd5 : file_len[31:24] <= header_byte;

            10'd10: pixel_offset[7:0] <= header_byte;
            10'd11: pixel_offset[15:8] <= header_byte;
            10'd12: pixel_offset[23:16] <= header_byte;
            10'd13: pixel_offset[31:24] <= header_byte;

            10'd14: dib_size[7:0] <= header_byte;
            10'd15: dib_size[15:8] <= header_byte;
            10'd16: dib_size[23:16] <= header_byte;
            10'd17: dib_size[31:24] <= header_byte;

            10'd18: width[7:0] <= header_byte;
            10'd19: width[15:8] <= header_byte;
            10'd20: width[23:16] <= header_byte;
            10'd21: width[31:24] <= header_byte;

            10'd22: height[7:0] <= header_byte;
            10'd23: height[15:8] <= header_byte;
            10'd24: height[23:16] <= header_byte;
            10'd25: height[31:24] <= header_byte;

            10'd26: planes[7:0] <= header_byte;
            10'd27: planes[15:8] <= header_byte;

            10'd28: bit_count[7:0] <= header_byte;
            10'd29: bit_count[15:8] <= header_byte;

            10'd30: compression[7:0] <= header_byte;
            10'd31: compression[15:8] <= header_byte;
            10'd32: compression[23:16] <= header_byte;
            10'd33: compression[31:24] <= header_byte;
            default: ;
        endcase
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        bmp_len_cnt <= 32'd0;
    end else if (state == ST_LOAD_DATA) begin
        if (sd_sec_read_data_valid)
            bmp_len_cnt <= bmp_len_cnt + 32'd1;
    end else begin
        bmp_len_cnt <= 32'd0;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        bmp_byte_idx <= 2'd0;
    end else if (state == ST_LOAD_DATA) begin
        if (bmp_data_valid)
            bmp_byte_idx <= (bmp_byte_idx == 2'd2) ? 2'd0 : (bmp_byte_idx + 2'd1);
    end else begin
        bmp_byte_idx <= 2'd0;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        raw_bmp_data_wr_en <= 1'b0;
        raw_bmp_data       <= 24'd0;
    end else if (state == ST_LOAD_DATA) begin
        if (bmp_data_valid) begin
            case (bmp_byte_idx)
                2'd0: begin
                    raw_bmp_data_wr_en <= 1'b0;
                    raw_bmp_data[7:0]  <= sd_sec_read_data;
                end
                2'd1: begin
                    raw_bmp_data_wr_en <= 1'b0;
                    raw_bmp_data[15:8] <= sd_sec_read_data;
                end
                2'd2: begin
                    raw_bmp_data_wr_en  <= 1'b1;
                    raw_bmp_data[23:16] <= sd_sec_read_data;
                end
                default: begin
                    raw_bmp_data_wr_en <= 1'b0;
                end
            endcase
        end else begin
            raw_bmp_data_wr_en <= 1'b0;
        end
    end else begin
        raw_bmp_data_wr_en <= 1'b0;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state             <= ST_IDLE;
        state_code        <= 4'd0;
        raw_sd_sec_read       <= 1'b0;
        raw_sd_sec_read_addr  <= 32'd0;
        write_req         <= 1'b0;
        scan_done         <= 1'b0;
        scan_found_valid  <= 1'b0;
        scan_found_sector <= 32'd0;
        scan_found_total  <= 3'd0;
        scan_sector       <= 32'd0;
        load_sector_latched <= 32'd0;
    end else if (!sd_init_done || load_abort) begin
        state             <= ST_IDLE;
        state_code        <= 4'd0;
        raw_sd_sec_read       <= 1'b0;
        raw_sd_sec_read_addr  <= 32'd0;
        write_req         <= 1'b0;
        scan_done         <= FILESYSTEM && !sd_init_done ? 1'b0:scan_done;
        scan_found_valid  <= 1'b0;
        scan_found_sector <= 32'd0;
        scan_found_total  <= FILESYSTEM && !sd_init_done ? 3'd0:scan_found_total;
        scan_sector       <= 32'd0;
        load_sector_latched <= 32'd0;
    end else begin
        scan_found_valid <= 1'b0;

        case (state)
            ST_IDLE: begin
                state_code  <= 4'd1;
                raw_sd_sec_read <= 1'b0;
                write_req   <= 1'b0;

                if (scan_start) begin
                    scan_done        <= 1'b0;
                    scan_found_total <= 3'd0;
                    scan_sector      <= scan_start_sector;
                    raw_sd_sec_read_addr <= scan_start_sector;
                    state            <= ST_SCAN;
                end else if (load_start) begin
                    load_sector_latched <= FILESYSTEM?32'd0:load_sector;
                    raw_sd_sec_read_addr    <= FILESYSTEM?32'd0:load_sector;
                    state               <= ST_LOAD_HDR;
                end
            end

            ST_SCAN: begin
                state_code  <= 4'd2;
                if(FILESYSTEM)begin
                    // 枚举结果只携带文件索引；不再扫物理扇区寻找 BM。
                    raw_sd_sec_read<=0;
                    if(fs_mount_done)begin
                        if(scan_found_total<fs_bmp_count)begin
                            scan_found_valid<=1;
                            scan_found_sector<={29'd0,scan_found_total};
                            scan_found_total<=scan_found_total+1'b1;
                        end else begin scan_done<=1;state<=ST_IDLE;end
                    end
                end else begin
                raw_sd_sec_read <= 1'b1;

                if (sd_sec_read_end) begin
                    raw_sd_sec_read <= 1'b0;

                    if (header_match && rd_cnt == 10'd512) begin
                        scan_found_valid  <= 1'b1;
                        scan_found_sector <= scan_sector;
                        scan_found_total  <= scan_found_total + 3'd1;

                        if ((scan_found_total + 3'd1 >= scan_target_count) || scan_match_past_end) begin
                            scan_done        <= 1'b1;
                            state            <= ST_IDLE;
                            raw_sd_sec_read_addr <= next_scan_sector_if_match;
                            scan_sector      <= next_scan_sector_if_match;
                        end else begin
                            raw_sd_sec_read_addr <= next_scan_sector_if_match;
                            scan_sector      <= next_scan_sector_if_match;
                        end
                    end else begin
                        if (scan_sector >= scan_max_sector) begin
                            scan_done <= 1'b1;
                            state     <= ST_IDLE;
                        end else begin
                            raw_sd_sec_read_addr <= next_scan_sector_if_miss;
                            scan_sector      <= next_scan_sector_if_miss;
                        end
                    end
                end
                end
            end

            ST_LOAD_HDR: begin
                state_code  <= 4'd2;
                raw_sd_sec_read <= 1'b1;

                if (sd_sec_read_end) begin
                    raw_sd_sec_read <= 1'b0;
                    if (header_match && rd_cnt == 10'd512) begin
                        write_req        <= 1'b1;
                        raw_sd_sec_read_addr <= load_sector_latched;
                        state            <= ST_LOAD_WAIT;
                    end else begin
                        state <= ST_IDLE;
                    end
                end
            end

            ST_LOAD_WAIT: begin
                state_code <= 4'd3;
                if (write_ack_sync[2]) begin
                    write_req <= 1'b0;
                    state     <= ENABLE_SCALING?ST_SCALE:ST_LOAD_DATA;
                end
            end

            ST_SCALE: begin
                state_code<=4'd4;
                raw_sd_sec_read<=0;
                if(scaled_done)state<=ST_IDLE;
            end

            ST_LOAD_DATA: begin
                state_code  <= 4'd4;
                raw_sd_sec_read <= 1'b1;

                if (sd_sec_read_end) begin
                    raw_sd_sec_read <= 1'b0;
                    if (bmp_len_cnt >= file_len) begin
                        state <= ST_IDLE;
                    end else begin
                        raw_sd_sec_read_addr <= raw_sd_sec_read_addr + 32'd1;
                    end
                end
            end

            default: begin
                state       <= ST_IDLE;
                state_code  <= 4'd1;
                raw_sd_sec_read <= 1'b0;
                write_req   <= 1'b0;
            end
        endcase
    end
end

endmodule
