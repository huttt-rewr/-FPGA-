`timescale 1ns/1ps
module tb_rate_player;
 reg clk=0,rst=1,next_cmd=0,prev_cmd=0,ack=0,finish=0;always #5 clk=~clk;
 reg toggle=0;reg [3:0] rate=0;wire limited,auto_on;integer before_frames;
 reg [7:0] image=0,audio=0;reg image_valid=0,audio_valid=0;
 wire wr,pv,commit,shown,busy,err,sv,aerr,ardy,queue_reset;
 wire [31:0] pixel;wire [23:0] sample;
 wire [6:0] ii,ic,ai,ac;wire truncated;
 // Accelerate only the timer; preserve the player watchdog.
 defparam dut.rate_control.timer.CLK_FREQ_HZ=3000;
 sd_card_bmp #(.RATE_CONTROLS(1),.INDEXED(1),.FAT32_ENABLE(1),.ENABLE_AUDIO(1),.ENABLE_SCALING(1),
 .READ_STALL_CYCLES(8192)) dut(.clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),
 .cmd_next(next_cmd),.cmd_prev(prev_cmd),.cmd_toggle(toggle),
 .image_select_index(image),.audio_select_index(audio),.image_select_valid(image_valid),.audio_select_valid(audio_valid),
 .media_image_index(ii),.media_image_count(ic),.media_audio_index(ai),.media_audio_count(ac),.media_truncated(truncated),
 .commit_ack_toggle(ack),.commit_req_toggle(commit),.commit_buffer(),
 .status_auto(auto_on),.fps_mode(rate),.rate_limited(limited),.status_index(),.status_count(),.status_busy(busy),.status_error(err),
 .bmp_width(16'd640),.bmp_height(16'd480),.display_valid(shown),.state_code(),
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
  if(!rst && pv)begin
   col=pixels%640;id=dut.load_idx;
   if(col<80 || col>=560)expected=0;
   else expected=((240-id*15)<<16)+(20<<8)+id*15;
   if(pixel[31:8]!==expected)begin
    if(errors<5)$display("FAIL indexed RGB idx=%0d pixel=%0d got=%h want=%h",id,pixels,pixel[31:8],expected);
    errors=errors+1;
   end
   pixels=pixels+1;
   if(pixels==307200)begin finish<=~finish;pixels=0;frames=frames+1;end
  end
  if(!rst && sv)begin check(sample==((ai+1)*3000),"PCM from currently committed audio file");samples=samples+1;end
  if(!rst && dut.audio_switching)switch_resets=switch_resets+1;
  ack<=commit;
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
  repeat(5)@(negedge clk);rst=0;wait(shown && !busy);repeat(10)@(negedge clk);
  check(ic==12 && ac==3 && ii==0 && !truncated,"enumeration reaches player");
  // At scaled test time, loading a frame is slower than every target period.
  @(negedge clk);toggle=1;@(negedge clk);toggle=0;
  wait(auto_on);wait(ii==1 && !busy);
  check(shown && !err && pixels==0,"automatic commit produces an entire correct frame");
  wait(busy);repeat(4000)@(negedge clk);
  check(limited && ii==1,"deadline expires during load without early commit");
  // Stop while the next frame is loading: complete that frame, queue no more.
  toggle=1;@(negedge clk);toggle=0;wait(!auto_on);wait(!busy);
  repeat(20)@(negedge clk);before_frames=frames;
  repeat(10000)@(negedge clk);
  check(frames==before_frames && !busy && ii==2,"pause drains one in-flight image and schedules no backlog");
  rate=5;repeat(10)@(negedge clk);
  check(!limited,"rate change clears the previous limit diagnostic");
  if(errors==0)$display("ALL PASS tb_rate_player: real FAT/scaler/player, guarded target cadence, full frames, pause during load, no backlog");
  else $display("FAILED rate player errors=%0d",errors);
  $finish;
 end
 initial begin #2000000000;$display("FAILED indexed player watchdog");$finish;end
endmodule
