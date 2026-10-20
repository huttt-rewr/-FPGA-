`timescale 1ns/1ps
// 复用实际 sd_card_bmp 调度、原 BMP 缩放和 WAV 解析；只替换物理SD卡。
module tb_sd_native_integrated;
 reg clk=0,rst=1,next_cmd=0,ack=0,finish=0;always #5 clk=~clk;
 wire wr,pv,commit,shown,busy,err,sv,aerr,ardy;wire [31:0] pixel;
 wire [1:0] idx,buffer;wire [2:0] count;wire [23:0] sample;
 wire native_clock;tri1 native_cmd,native_d0,native_d1,native_d2,native_d3;
 wire [3:0] acode;
 sd_card_bmp #(.NATIVE_4BIT(1),.FAT32_ENABLE(1),.MAX_BMP(4),.ENABLE_AUDIO(1),.ENABLE_SCALING(1),
 .CLK_FREQ_HZ(100000000),.READ_STALL_CYCLES(8192)) dut(.clk(clk),.rst(rst),
 .key_next(1'b1),.key_auto(1'b1),.cmd_next(next_cmd),.cmd_prev(1'b0),.cmd_toggle(1'b0),
 .commit_ack_toggle(ack),.commit_req_toggle(commit),.commit_buffer(buffer),
 .status_auto(),.status_index(idx),.status_count(count),.status_busy(busy),.status_error(err),
 .bmp_width(16'd640),.bmp_height(16'd480),.display_valid(shown),.state_code(),
 .write_finish_toggle(finish),.write_buf_idx(),.disp_buf_idx(),.write_req(wr),.write_req_ack(wr),
 .write_en(pv),.write_data(pixel),.SD_nCS(),.SD_DCLK(),.SD_MOSI(),.SD_MISO(1'b1),.SD_CLK(native_clock),.SD_CMD(native_cmd),
 .SD_DAT0(native_d0),.SD_DAT1(native_d1),.SD_DAT2(native_d2),.SD_DAT3(native_d3),
 .pixel_ready(1'b1),.image_width(),.image_height(),.debug_sd_status(),
 .audio_enable(1'b1),.audio_sample_ready(1'b1),.audio_sector_room(1'b1),
 .audio_sample_valid(sv),.audio_sample(sample),.audio_error(aerr),.audio_ready(ardy),
 .audio_stream_reset(),.audio_error_code(acode));
 integer fd,errors=0,pixels=0,frames=0,samples=0,j;
 reg [7:0] wav_bytes[0:4095];
 reg [23:0] expected[0:307199];
 wire native_init,native_init_error,native_error,native_valid,native_done;
 wire [7:0] native_data;
 wire [31:0] model_errors;
 sd_native_card_model #(.IMAGE_MODE(1)) card(.rst(rst),.SD_CLK(native_clock),.SD_CMD(native_cmd),
  .SD_DAT({native_d3,native_d2,native_d1,native_d0}),.ccs(1'b1),.fault(4'd0),
  .last_read_argument(),.commands(),.reads(),.errors(model_errors));
 always @(posedge clk)begin
  if(!rst && pv)begin
   if(pixel[31:8]!==expected[pixels])begin
    if(errors<5)$display("FAILED FAT player frame=%0d pixel=%0d actual=%h expected=%h",frames,pixels,pixel[31:8],expected[pixels]);
    errors=errors+1;
   end
   pixels=pixels+1;
   if(pixels==307200)begin finish<=~finish;pixels=0;end
  end
  if(!rst && sv)begin
   j=44+(samples%2000)*2;
   if(sample!=={{8{wav_bytes[j+1][7]}},wav_bytes[j+1],wav_bytes[j]})begin
    if(errors<5)$display("FAILED FAT player PCM index=%0d got=%h",samples,sample);
    errors=errors+1;
   end
   samples=samples+1;
  end
  ack<=commit;
 end
 initial begin
  fd=$fopen("../reports/fat32_20261015/vectors/super.img","rb");
  if(fd==0)begin $display("FAILED FAT player no image");$finish;end
  $readmemh("../reports/fat32_20261015/vectors/super_SOUND___WAV.hex",wav_bytes);
  $readmemh("../reports/fat32_20261015/vectors/pixels0.hex",expected);
  repeat(5)@(negedge clk);rst=0;
  wait(shown && !busy);repeat(6)@(negedge clk);
  if(count!=4 || idx!=0 || err || aerr || samples<4000 || !ardy)begin errors=errors+1;$display("FAILED FAT player first frame/status count=%0d idx=%0d samples=%0d err=%b audio=%h",count,idx,samples,err,acode);end
  frames=1;
  $readmemh("../reports/fat32_20261015/vectors/pixels1.hex",expected);
  next_cmd=1;@(negedge clk);next_cmd=0;
  wait(busy);wait(!busy);repeat(6)@(negedge clk);
  if(idx!=1 || buffer!=1 || !shown || err || aerr || pixels!=0)begin errors=errors+1;$display("FAILED FAT player second frame");end
  if(model_errors!=0)errors=errors+1;
  if(errors==0)$display("ALL PASS tb_sd_native_integrated: formal native profile without force/real SD pins/real scheduler/two scaled fragmented BMP frames/exact PCM loops/commit");
  else $display("FAILED FAT32 player total=%0d",errors);
  $finish;
 end
 initial begin #1000000000;$display("FAILED FAT32 player watchdog");$finish;end
endmodule
