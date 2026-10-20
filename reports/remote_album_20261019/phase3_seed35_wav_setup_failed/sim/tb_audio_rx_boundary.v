`timescale 1ns/1ps
// Consumer-boundary regression: dense/gapped data, coalesced/separate end,
// error priority, invalid lengths, PCM backpressure and abort flushing.
module tb_audio_rx_boundary;
 reg clk=0,rst=1,init=1,en=1,accept=1;
 always #5 clk=~clk;
 wire req,sv,error,ready;
 wire [3:0] code;
 wire [31:0] addr;
 wire [23:0] sample;
 reg [7:0] data=0;
 reg dv=0,done=0,re=0;
 reg [7:0] image[0:1535];
 integer errors=0,seen=0,reads=0,cycle=0,mode=0,busy=0,idx=0,base=0,j;
 reg [15:0] expected;
 audio_wav #(.FILESYSTEM(1),.MAX_BYTES(1536),.RETRY_CYCLES(37)) dut(
  .clk(clk),.rst(rst),.sd_init_done(init),.enable(en),
  .sector_room(1'b1),.sample_ready(accept),.req(req),.addr(addr),
  .data(data),.data_valid(dv),.sector_end(done),.read_error(re),
  .sample_valid(sv),.sample(sample),.error(error),.error_code(code),.ready(ready));
 task check;
  input ok;input [511:0] message;
  begin if(ok!==1)begin errors=errors+1;$display("FAILED rx boundary %0s",message);end end
 endtask
 task u32;
  input integer p,v;
  begin image[p]=v;image[p+1]=v>>8;image[p+2]=v>>16;image[p+3]=v>>24;end
 endtask
 task make;
  begin
   for(j=0;j<1536;j=j+1)image[j]=0;
   u32(0,32'h46464952);u32(4,1236);u32(8,32'h45564157);
   u32(12,32'h20746d66);u32(16,16);image[20]=1;image[22]=1;
   u32(24,48000);u32(28,96000);image[32]=2;image[34]=16;
   u32(36,32'h61746164);u32(40,1200);
   for(j=0;j<600;j=j+1)begin
    image[44+j*2]=(j*251)&255;image[45+j*2]=(j*251)>>8;
   end
  end
 endtask
 task reset_dut;
  begin
   @(negedge clk);rst=1;init=1;en=1;
   repeat(4)@(negedge clk);seen=0;reads=0;rst=0;
  end
 endtask
 always @(posedge clk)begin
  cycle=cycle+1;
  if(!rst && sv)begin
   expected=(seen%600)*251;
   check(sample=={{8{expected[15]}},expected},"PCM byte ordering/sign/loop/backpressure");
   check(!error,"failed sector must never publish PCM");
   seen=seen+1;
  end
 end
 always @(negedge clk)begin
  dv=0;done=0;re=0;
  accept=(cycle%7)<3;
  if(rst)begin busy=0;idx=0;end
  else if(!busy && req)begin
   base=addr*512;idx=0;busy=1;reads=reads+1;
   check(base<1536,"valid relative sector address");
  end else if(busy==1 && (mode!=1 || cycle%3==0))begin
   if(idx<(mode==3?511:(mode==4?513:512)))begin
    data=image[(base+(idx%512))%1536];dv=1;idx=idx+1;
    if((mode==0 || mode==2 || mode==3) && idx==(mode==3?511:512))begin
     done=1;re=mode==2;busy=3;
    end
   end else begin done=1;busy=3;end
  end else if(busy==3 && !req)busy=0;
 end
 initial begin
  make;mode=0;reset_dut;
  wait(seen>=1200);check(ready && !error && reads>=6,"dense last-byte plus end across three sectors");
  mode=1;reset_dut;
  wait(seen>=1200);check(ready && !error,"gapped valid and separate end");
  mode=2;reset_dut;
  wait(error);#1;check(code==2 && seen==0,"read error wins over simultaneous last byte and end");
  @(negedge clk);mode=0;
  wait(seen>=600);check(ready && !error,"automatic retry after transport error");
  mode=3;reset_dut;
  wait(error);#1;check(code==3 && seen==0,"511 bytes with coalesced end rejected");
  mode=4;reset_dut;
  wait(error);#1;check(code==3 && seen==0,"513 bytes with separate end rejected");
  mode=0;reset_dut;
  wait(done);#1;rst=1;en=0;
  repeat(4)@(negedge clk);rst=0;
  repeat(20)@(negedge clk);
  check(!req && !sv && !ready && !error && seen==0,"abort flushes buffered terminal byte/end");
  if(errors==0)$display("ALL PASS tb_audio_rx_boundary");
  else $display("FAILED tb_audio_rx_boundary errors=%0d",errors);
  $finish;
 end
 initial begin #4000000;$display("FAILED rx boundary watchdog");$finish;end
endmodule
