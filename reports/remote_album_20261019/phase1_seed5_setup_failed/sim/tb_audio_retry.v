`timescale 1ns/1ps
module tb_audio_retry;
 localparam RETRY=37;
 reg clk=0,rst=1,init=1,en=1;
 always #5 clk=~clk;
 wire req,sv,error,ready;wire [3:0] code;wire [31:0] addr;wire [23:0] sample;
 wire sr,av,ae,arerr,tr,bv,be,ber,bg;wire [31:0] sa;wire [7:0] ad,bd;
 reg [7:0] data=0;reg dv=0,done=0,re=0,breq=0;
 reg [7:0] image[0:511];
 integer errors=0,seen=0,reads=0,breads=0,cycle=0,failure_cycle=0;
 integer mode=0,busy=0,idx=0,j,init_wait=0;
 reg owner=0;
 audio_wav #(.START_SECTOR(100),.MAX_BYTES(512),.RETRY_CYCLES(RETRY)) dut(
 .clk(clk),.rst(rst),.sd_init_done(init),.enable(en),.sector_room(1'b1),.sample_ready(1'b1),
 .req(req),.addr(addr),.data(ad),.data_valid(av),.sector_end(ae),.read_error(arerr),
 .sample_valid(sv),.sample(sample),.error(error),.error_code(code),.ready(ready));
 sd_read_arbiter #(.TIMEOUT_CYCLES(16)) arb(
 .clk(clk),.rst(rst),.sd_ready(init),.bmp_req(breq),.bmp_addr(32'd0),
 .bmp_data(bd),.bmp_valid(bv),.bmp_end(be),.bmp_error(ber),.bmp_grant(bg),
 .aud_req(req),.aud_addr(addr),.aud_data(ad),.aud_valid(av),.aud_end(ae),.aud_error(arerr),
 .sd_req(sr),.sd_addr(sa),.sd_data(data),.sd_valid(dv),.sd_end(done),.sd_error(re),
 .transport_reset(tr));
 task check;input ok;input [511:0] msg;begin
  if(ok!==1)begin errors=errors+1;$display("FAILED retry %0s cycle=%0d code=%0d",msg,cycle,code);end
 end endtask
 task u32;input integer p,v;begin
  image[p]=v;image[p+1]=v>>8;image[p+2]=v>>16;image[p+3]=v>>24;
 end endtask
 task make;begin
  for(j=0;j<512;j=j+1)image[j]=0;
  u32(0,32'h46464952);u32(4,44);u32(8,32'h45564157);
  u32(12,32'h20746d66);u32(16,16);image[20]=1;image[22]=1;
  u32(24,48000);u32(28,96000);image[32]=2;image[34]=16;
  u32(36,32'h61746164);u32(40,8);
  for(j=44;j<52;j=j+2)begin image[j]=8'h34;image[j+1]=8'h12;end
 end endtask
 task reset_dut;begin
  rst=1;init=1;en=1;breq=0;repeat(4)@(negedge clk);seen=0;reads=0;breads=0;rst=0;
 end endtask
 task failure;input [3:0] expected;begin
  wait(error);#1;failure_cycle=cycle;
  check(code==expected && !sv,"specific code and no corrupt sample");
  @(negedge clk);breq=1;
 end endtask
 task delay_check;begin
  while(error)begin
   @(posedge clk);#1;
   if(error)check(cycle-failure_cycle<RETRY && !req && !ready && !sv,"quiet retry delay");
  end
  check(cycle-failure_cycle==RETRY,"exact retry period, survives reinit");
  @(negedge clk);breq=0;
 end endtask
 task recover;begin
  @(negedge clk);mode=0;make;
  delay_check;
  wait(seen>=4);check(ready && !error,"automatic PCM recovery without reset");
 end endtask
 always @(posedge clk)begin
  cycle=cycle+1;
  if(!rst && sv)begin
   check(sample==24'h001234 && !error,"correct recovered PCM");seen=seen+1;
  end
  if(!rst && be)breads=breads+1;
  if(!rst && ber)check(0,"audio fault must not route to BMP");
 end
 always @(negedge clk)begin
  dv=0;done=0;re=0;
  if(rst)begin busy=0;idx=0;init_wait=0;end
  else if(tr)begin init=0;init_wait=10;busy=0;end
  else if(init_wait!=0)begin
   init_wait=init_wait-1;if(init_wait==0)init=1;
  end else if(!busy && sr)begin
   idx=0;busy=1;owner=sa==100;if(owner)reads=reads+1;
  end else if(busy==1)begin
   if(owner && mode==6)begin if(!sr)busy=0;end
   else if(idx<(owner && mode==3?511:(owner && mode==4?513:512)))begin
    data=owner?image[idx%512]:8'h55;dv=1;idx=idx+1;
   end else begin
    if(owner && mode==2)re=1;else done=1;busy=2;
   end
  end else if(busy==2 && !sr)busy=0;
 end
 initial begin
  make;image[0]=0;reset_dut;failure(1);recover;
  make;image[22]=2;reset_dut;failure(1);recover;
  make;u32(24,44100);reset_dut;failure(1);recover;
  make;mode=2;reset_dut;failure(2);recover;
  make;mode=3;reset_dut;failure(3);recover;
  make;mode=4;reset_dut;failure(3);recover;
  make;mode=0;u32(40,1000);reset_dut;failure(4);recover;
  make;mode=6;reset_dut;failure(2);
  // Do not remove the stall until the arbiter really reset/reinitialized SD.
  wait(!init);@(negedge clk);mode=0;make;delay_check;
  wait(seen>=4);check(ready && !error,"transport timeout recovers");
  make;image[34]=8;reset_dut;failure(1);en=0;delay_check;
  repeat(700)@(negedge clk);check(!req && !ready && reads==1,"disabled retry parks in IDLE");
  make;en=1;wait(seen>=4);check(!error,"unmute restarts parsing");
  make;mode=2;reset_dut;failure(2);init=0;mode=0;make;delay_check;
  repeat(700)@(negedge clk);check(!req && !ready && reads==1,"SD unavailable parks in IDLE");
  init=1;wait(seen>=4);check(!error,"SD return restarts parsing");
  // Permanent corruption: bounded repeated failures, no tight request loop.
  make;image[0]=0;reset_dut;failure(1);delay_check;
  wait(error);#1;check(reads==2 && seen==0,"permanent bad WAV retries and remains silent");
  failure_cycle=cycle;delay_check;check(breads>0,"BMP progresses while WAV waits");
  if(errors==0)$display("ALL PASS tb_audio_retry");
  else $display("FAILED tb_audio_retry %0d",errors);
  $finish;
 end
 initial begin #1000000;$display("FAILED retry watchdog");$finish;end
endmodule
