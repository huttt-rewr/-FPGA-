`timescale 1ns/1ps
// Real reader/scaler, bounded unbackpressured sector peer, delayed writer/commit.
// Transport uses one byte per 40 control cycles plus 100 cycles/sector command.
module tb_sd_av;
 reg clk=0,rst=1,toggle_play=0,sd_error=0,wa=0,finish=0;
 always #5 clk=~clk;
 reg [7:0] data=0;
 reg valid=0,se=0,ready=0;
 wire read,wr,we,request,bank,awe,playing,error,ended,busy,ack;
 wire [1:0] active;wire visible,buffering,audio_valid;
 wire [23:0] left,right;
 reg [20:0] video_counter=0;reg vblank=0;
 always @(posedge clk or posedge rst)begin
  if(rst)begin video_counter<=0;vblank<=0;end
  else begin
   video_counter<=(video_counter==1679999)?0:video_counter+1'b1;
   vblank<=video_counter==1679999;
  end
 end
 wire [31:0] address,wd;wire [1:0] wb;wire [10:0] aa;wire [15:0] ad;wire [3:0] state;
 reg [7:0] disk[0:180223];
 integer i,f,j,p,cycle=0,transport=0,pos=0,delay_count=0,base=0;
 integer reads=0,pixels=0,audios=0,commits=0,drain_delay=0,audio_ticks=0;
 integer red,green,blue,expected_audio,start_cycle=0,last_cycle=0,last_ack_cycle=0;
 integer limit=512;
 reg last_req=0,last_ack=0;
 sd_av_reader #(.WATCHDOG(4000000)) dut(.clk(clk),.rst(rst),.mode_800(1'b0),.toggle_play(toggle_play),
  .sd_ready(1'b1),.sd_error(sd_error),.sector_read(read),.sector_address(address),
  .sector_data(data),.sector_valid(valid),.sector_end(se),.write_req(wr),.write_req_ack(wa),
  .write_finish_toggle(finish),.write_en(we),.write_data(wd),.pixel_ready(ready),.write_bank(wb),
  .request_toggle(request),.requested_bank(bank),.ack_toggle(ack),.audio_we(awe),
  .audio_address(aa),.audio_data(ad),.playing(playing),.error(error),.ended(ended),.busy(busy),.state_code(state));
 av_sync_player #(.VGA_HZ(100000000),.SAMPLES(800)) player(
  .clk(clk),.rst(rst),.mode_800(1'b0),.vblank(vblank),
  .request_toggle(request),.requested_bank(bank),.play(playing),.failed(error),.ended(ended),
  .ack_toggle(ack),.active_buffer(active),.visible(visible),.buffering(buffering),
  .write_clk(clk),.audio_we(awe),.audio_address(aa),.audio_data(ad),
  .audio_valid(audio_valid),.left_pcm(left),.right_pcm(right));
 task put32;input integer offset;input [31:0] value;begin
  disk[offset]=value[7:0];disk[offset+1]=value[15:8];
  disk[offset+2]=value[23:16];disk[offset+3]=value[31:24];
 end endtask
 task reset_dut;begin
  @(negedge clk);rst=1;sd_error=0;
  repeat(6)@(negedge clk);rst=0;
 end endtask
 always @(negedge clk)begin
  cycle=cycle+1;valid=0;se=0;
  ready=!rst && !wr && cycle%13<9;
  wa=wr;
  if(rst)begin
   transport=0;reads=0;pixels=0;audios=0;commits=0;audio_ticks=0;finish=0;
   last_req=0;last_ack=0;drain_delay=0;start_cycle=cycle;last_cycle=cycle;last_ack_cycle=cycle;
  end else begin
   case(transport)
    0:if(read)begin
     if(address!==reads)$fatal(1,"FAILED nonsequential sector got=%d expected=%d",address,reads);
     reads=reads+1;base=address*512;pos=0;delay_count=100;transport=1;
    end
    1:if(delay_count>0)delay_count=delay_count-1;
      else begin
       data=disk[base+pos];valid=1;pos=pos+1;delay_count=39;
       if(pos==limit)transport=2;
      end
    2:begin se=1;transport=3;end
    3:if(!read)transport=0;
   endcase
   if(drain_delay>0)begin
    drain_delay=drain_delay-1;
    if(drain_delay==0)finish=!finish;
   end
   if(request!=last_req)begin
    if(drain_delay || pixels!=(commits+1)*307200 || audios!=(commits+1)*800)
     $fatal(1,"FAILED premature publication");
    if(bank!==commits[0])$fatal(1,"FAILED bank order");
    // Even with a full 16.8 ms blanking wait, the next load must fit in 50 ms.
    if(commits>0 && cycle-last_ack_cycle>3320000)
     $fatal(1,"FAILED 20 fps load budget: %0d control cycles",cycle-last_ack_cycle);
    $display("frame %0d published in %0d control cycles (%0d us)",commits,cycle-last_cycle,(cycle-last_cycle)/100);
    if(commits>0)$display("frame %0d ACK-to-publish load: %0d us",commits,(cycle-last_ack_cycle)/100);
    last_cycle=cycle;last_req=request;
   end
   if(ack!=last_ack)begin
    if(active!=={1'b0,commits[0]})$fatal(1,"FAILED vblank commit bank=%d",active);
    last_ack=ack;last_ack_cycle=cycle;commits=commits+1;
   end
   if(visible && !ended && buffering)$fatal(1,"FAILED video underrun at 20 fps");
   if(audio_valid && visible)begin
    if(audio_ticks<7200)begin
     expected_audio=(audio_ticks/2400)*1000+((audio_ticks%2400)/3)+1;
     if(left!=={expected_audio[15:0],8'd0} || right!==left)
      $fatal(1,"FAILED synchronized PCM tick=%0d got=%h expected=%h",audio_ticks,left,expected_audio);
     audio_ticks=audio_ticks+1;
    end
   end
  end
 end
 always @(posedge clk)if(!rst)begin
  if(awe)begin
   expected_audio=(audios/800)*1000+audios%800+1;
   if(aa!==(((audios/800)%2)*1024+audios%800) || ad!==expected_audio[15:0])
    $fatal(1,"FAILED PCM write n=%d addr=%d data=%d",audios,aa,ad);
   audios=audios+1;
  end
  if(we)begin
   if(!ready)$fatal(1,"FAILED write under backpressure");
   f=pixels/307200;p=pixels%307200;
   red=((p%640)/4+f)&255;green=(p/640)/4;blue=((p%640)/4+green)&255;
   if(wd!=={red[7:0],green[7:0],blue[7:0],8'd0} || wb!=={1'b0,f[0]})
    $fatal(1,"FAILED video write n=%d data=%h bank=%d",pixels,wd,wb);
   pixels=pixels+1;
   if(pixels%307200==0)drain_delay=250;
  end
 end
 initial begin
  for(i=0;i<180224;i=i+1)disk[i]=0;
  put32(0,32'h36315641);put32(4,32'h0030324b);put32(8,3);
  put32(12,32'h007800a0);put32(16,32'h3e800014);put32(20,117);
  for(j=0;j<3;j=j+1)begin
   for(i=0;i<800;i=i+1)begin
    disk[(1+j*117)*512+i*2]=(j*1000+i+1)&255;
    disk[(1+j*117)*512+i*2+1]=(j*1000+i+1)>>8;
   end
   for(i=0;i<19200;i=i+1)begin
    disk[(5+j*117)*512+i*3]=(i%160+i/160)&255;
    disk[(5+j*117)*512+i*3+1]=i/160;
    disk[(5+j*117)*512+i*3+2]=(i%160+j)&255;
   end
  end
  reset_dut;wait(ended);wait(player.exhausted);#1;
  if(error || commits!=3 || reads!=352 || pixels!=921600 || audios!=2400)
   $fatal(1,"FAILED complete reader counts");
  repeat(3000)@(negedge clk);
  if(read || we || awe || busy || buffering || left!=0 || audio_ticks!=7200)
   $fatal(1,"FAILED activity after EOF audio_ticks=%0d",audio_ticks);
  // Reject a malformed value in every header word, including high bytes of
  // frame count and reserved. This catches truncated/reversed field assembly.
  for(j=0;j<7;j=j+1)begin
   put32(0,32'h36315641);put32(4,32'h0030324b);put32(8,3);
   put32(12,32'h007800a0);put32(16,32'h3e800014);put32(20,117);put32(24,0);
   case(j)
    0:put32(0,0);
    1:put32(4,32'h0130324b);
    2:put32(8,32'h01000003);
    3:put32(12,32'h007800a1);
    4:put32(16,32'h3e800015);
    5:put32(20,32'h00010075);
    6:put32(24,32'h01020304);
   endcase
   reset_dut;wait(error);#1;
   if(request || wr || pixels || audios || playing)$fatal(1,"FAILED bad header word %0d accepted",j);
  end
  put32(24,0);limit=100;reset_dut;wait(error);#1;
  if(request || pixels || audios)$fatal(1,"FAILED short header accepted");
  limit=512;reset_dut;sd_error=1;repeat(3)@(negedge clk);
  if(!error || playing || read || wr)$fatal(1,"FAILED SD error not latched");
  $display("ALL PASS tb_sd_av: 3 frames, exact PCM/pixels, 20 fps deadlines, sequential sectors, delayed completion, EOF, all header words/SD errors");$finish;
 end
 initial begin #230000000;$fatal(1,"FAILED tb_sd_av timeout");end
endmodule
