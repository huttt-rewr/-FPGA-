`timescale 1ns/1ps
module tb_mode_reload;
 reg clk=0,power_reset=1,next_cmd=0,prev_cmd=0,ack=0,finish=0;
 reg boot=0;always #20 boot=~boot;
 reg [1:0] requested_mode=1;
 wire mode_ready,mode_800;wire [1:0] active_mode;wire rst;
 video_mode_control #(.QUIET_CYCLES(16),.SETTLE_CYCLES(128)) mode_control(
  .clk(boot),.rst(power_reset),.edid_done(1'b1),.supports_800(1'b1),.requested_mode(requested_mode),
  .ready(mode_ready),.mode_800(mode_800),.active_mode(active_mode),.fallback());
 reset_sync reset_player(.clk(clk),.arst(power_reset | !mode_ready),.rst(rst));always #5 clk=~clk;
 reg [7:0] image=0,audio=0;reg image_valid=0,audio_valid=0;
 wire wr,pv,commit,shown,busy,err,sv,aerr,ardy,queue_reset;
 wire [31:0] pixel;wire [23:0] sample;
 wire [6:0] ii,ic,ai,ac;wire truncated;
 sd_card_bmp #(.INDEXED(1),.FAT32_ENABLE(1),.ENABLE_AUDIO(1),.ENABLE_SCALING(1),.ADAPTIVE(1),
 .READ_STALL_CYCLES(8192)) dut(.clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),
 .cmd_next(next_cmd),.cmd_prev(prev_cmd),.cmd_toggle(1'b0),
 .image_select_index(image),.audio_select_index(audio),.image_select_valid(image_valid),.audio_select_valid(audio_valid),
 .media_image_index(ii),.media_image_count(ic),.media_audio_index(ai),.media_audio_count(ac),.media_truncated(truncated),
 .commit_ack_toggle(ack),.commit_req_toggle(commit),.commit_buffer(),
 .status_auto(),.status_index(),.status_count(),.status_busy(busy),.status_error(err),
 .bmp_width(mode_800?16'd800:16'd640),.bmp_height(mode_800?16'd600:16'd480),.display_valid(shown),.state_code(),
 .write_finish_toggle(finish),.write_buf_idx(),.disp_buf_idx(),.write_req(wr),.write_req_ack(wr),
 .write_en(pv),.write_data(pixel),.SD_nCS(),.SD_DCLK(),.SD_MOSI(),.SD_MISO(1'b1),
 .pixel_ready(1'b1),.image_width(),.image_height(),.debug_sd_status(),
 .audio_enable(1'b1),.audio_sample_ready(1'b1),.audio_sector_room(1'b1),
 .audio_sample_valid(sv),.audio_sample(sample),.audio_error(aerr),.audio_ready(ardy),.audio_stream_reset(queue_reset),.audio_error_code());
 integer fd,seek_result,got,active=0,n=0,errors=0,pixels=0,frames=0,samples=0,switch_resets=0,col,id;
 reg [7:0] sector[0:511];reg [7:0] data=0;reg dv=0,se=0;
 reg [23:0] expected;
 initial begin
  force dut.sd_init_done=1'b1;force dut.sd_init_error=1'b0;force dut.raw_transfer_error=1'b0;
  force dut.card_data=data;force dut.card_valid=dv;force dut.card_end=se;
 end
 task check;input ok;input [511:0] msg;begin
  if(ok!==1)begin errors=errors+1;$display("FAIL indexed player %0s",msg);end
 end endtask
 always @(negedge clk)begin
  dv=0;se=0;
  if(rst)begin active=0;end
  else case(active)
   0:if(dut.card_read)begin
    seek_result=$fseek(fd,dut.card_addr*512,0);got=$fread(sector,fd);n=0;active=1;
    if(seek_result!=0 || got!=512)begin $display("FAILED indexed disk range");$finish;end
   end
   1:begin data=sector[n];dv=1;n=n+1;if(n==512)active=2;end
   2:begin se=1;active=3;end
   3:if(!dut.card_read)active=0;
  endcase
 end
 always @(posedge clk)begin
  if(rst)pixels=0;
  if(!rst && pv)begin
   col=pixels%(mode_800?800:640);id=dut.load_idx;
   if(col<(mode_800?100:80) || col>=(mode_800?700:560))expected=0;
   else expected=((240-id*15)<<16)+(20<<8)+id*15;
   if(pixel[31:8]!==expected)begin
    if(errors<5)$display("FAIL indexed RGB idx=%0d pixel=%0d got=%h want=%h",id,pixels,pixel[31:8],expected);
    errors=errors+1;
   end
   pixels=pixels+1;
   if(pixels==(mode_800?480000:307200))begin finish<=~finish;pixels=0;frames=frames+1;end
  end
  if(!rst && sv)begin check(sample==((ai+1)*3000),"PCM from currently committed audio file");samples=samples+1;end
  if(!rst && dut.audio_switching)switch_resets=switch_resets+1;
  ack<=commit;
 end
 // Mirror top's selected-index feedback; a remount must not overwrite the
 // saved request with the player's reset index before its first commit.
 reg committed_seen=0;reg [6:0] committed_index=0;
 always @(posedge clk)begin
  if(rst)begin committed_seen<=0;committed_index<=0;end
  else if(shown)begin
   if((!committed_seen || ii!=committed_index) && ic!=0 && !busy && !image_valid)image<=ii;
   committed_seen<=1;committed_index<=ii;
  end
 end
 task select_image;input [7:0] index;begin
  @(negedge clk);image=index;image_valid=1;@(negedge clk);image_valid=0;
 end endtask
 task complete_image;input [6:0] index;begin
  wait(busy);wait(!busy);repeat(10)@(negedge clk);
  check(ii==index && shown && !err && pixels==0,"selected image fully committed");
 end endtask
 initial begin
  fd=$fopen("../reports/keyboard_20261016/stage2/media.img","rb");
  if(fd==0)begin $display("FAILED indexed missing media");$finish;end
  repeat(5)@(negedge clk);power_reset=0;
  wait(shown && !busy);repeat(10)@(negedge clk);
  check(ii==0 && !mode_800,"initial VGA frame");
  select_image(3);complete_image(3);
  @(negedge clk);next_cmd=1;@(negedge clk);next_cmd=0;complete_image(4);
  check(image==4,"arrow-selected index fed back before mode restart");
  requested_mode=2;wait(!mode_ready);wait(mode_ready);wait(shown && !busy);repeat(10)@(negedge clk);
  check(ii==4 && mode_800 && !err && pixels==0,"SVGA reload selected image and full 480000 frame");
  requested_mode=1;wait(!mode_ready);wait(mode_ready);wait(shown && !busy);repeat(10)@(negedge clk);
  check(ii==4 && !mode_800 && !err && pixels==0,"return VGA reload selected image and full 307200 frame");
  // A mode change while a partial new frame is being written must abort it.
  select_image(7);wait(busy && pixels>100);requested_mode=0;
  wait(!mode_ready);wait(mode_ready);wait(shown && !busy);repeat(10)@(negedge clk);
  check(ii==7 && !mode_800 && active_mode==0 && !err && pixels==0,"mid-load reset aborts old partial frame, then clean reload");
  if(errors==0)$display("ALL PASS tb_mode_reload: real FAT/BMP/WAV reload across VGA-SVGA-VGA, exact pixels, mid-load abort, same file resume");
  else $display("FAILED mode reload errors=%0d",errors);
  $finish;
 end
 initial begin #2000000000;$display("FAILED indexed player watchdog");$finish;end
endmodule
