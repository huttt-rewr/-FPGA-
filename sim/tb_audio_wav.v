`timescale 1ns/1ps
module tb_audio_wav;
 reg clk=0,rst=1,init=1,en=1,room=1,accept=1;
 always #5 clk=~clk;
 wire req,sv,err,ready;wire [31:0] addr;wire [23:0] sample;
 reg [7:0] data=0;reg dv=0,done=0,re=0;
 reg [7:0] image[0:2047];integer errors=0,seen=0,reads=0,j,off,len,mode=0,busy=0,idx=0,base=0;
 reg [23:0] expected[0:3];
 audio_wav #(.START_SECTOR(100),.MAX_BYTES(2048)) dut(.clk(clk),.rst(rst),.sd_init_done(init),.enable(en),.sector_room(room),.sample_ready(accept),.req(req),.addr(addr),.data(data),.data_valid(dv),.sector_end(done),.read_error(re),.sample_valid(sv),.sample(sample),.error(err),.ready(ready));
 task check;input ok;input [511:0] msg;begin if(ok!==1)begin errors=errors+1;$display("FAILED WAV %0s",msg);end end endtask
 task u32;input integer p,v;begin image[p]=v;image[p+1]=v>>8;image[p+2]=v>>16;image[p+3]=v>>24;end endtask
 task make;input integer junk;begin
  for(j=0;j<2048;j=j+1)image[j]=0;
  u32(0,32'h46464952);u32(8,32'h45564157);off=12;
  if(junk!=0)begin u32(off,32'h4b4e554a);u32(off+4,junk);off=off+8+junk+(junk%2);end
  u32(off,32'h20746d66);u32(off+4,16);image[off+8]=1;image[off+10]=1;u32(off+12,48000);u32(off+16,96000);image[off+20]=2;image[off+22]=16;
  off=off+24;u32(off,32'h61746164);u32(off+4,8);off=off+8;
  image[off]=0;image[off+1]=0;image[off+2]=255;image[off+3]=127;image[off+4]=0;image[off+5]=128;image[off+6]=255;image[off+7]=255;
  len=off+8;u32(4,len-8);
 end endtask
 task reset_dut;begin rst=1;repeat(4)@(negedge clk);seen=0;reads=0;rst=0;end endtask
 // 假SD逐字节返回，end与最后字节分拍；mode模拟短扇区或CRC失败。
 always @(negedge clk)begin
  dv=0;done=0;re=0;
  if(rst)begin busy=0;idx=0;end
  else if(!busy && req)begin base=(addr-100)*512;idx=0;busy=1;reads=reads+1;end
  else if(busy==1)begin
   if(idx<((mode==1)?511:512))begin data=image[base+idx];dv=1;idx=idx+1;end
   else begin if(mode==2)re=1;else done=1;busy=2;end
  end else if(busy==2 && !req)busy=0;
 end
 always @(posedge clk)if(!rst && sv)begin
  if(sample!==expected[seen%4])begin errors=errors+1;$display("FAILED WAV sample %0d got %h",seen,sample);end
  seen=seen+1;
 end
 initial begin
  expected[0]=0;expected[1]=24'h007fff;expected[2]=24'hff8000;expected[3]=24'hffffff;
  make(0);reset_dut;wait(seen>=12);check(ready && !err,"standard header/sign/loop");
  en=0;repeat(20)@(negedge clk);j=seen;repeat(80)@(negedge clk);check(seen==j,"pause");en=1;wait(seen>=16);
  room=0;repeat(20)@(negedge clk);j=seen;repeat(80)@(negedge clk);check(seen==j,"sector backpressure");room=1;
  accept=0;repeat(20)@(negedge clk);j=seen;repeat(80)@(negedge clk);check(seen==j,"sample backpressure");accept=1;
  rst=1;make(467);reset_dut;wait(seen>=12);check(reads>=2 && !err,"odd JUNK and fmt across sector");
  rst=1;make(470);reset_dut;wait(seen>=12);check(!err,"data offset near boundary");
  rst=1;make(0);u32(24,44100);reset_dut;wait(err);check(seen==0 && !ready,"invalid rate");
  rst=1;make(0);image[34]=8;reset_dut;wait(err);check(seen==0,"invalid bits");
  rst=1;make(0);image[22]=2;reset_dut;wait(err);check(seen==0,"invalid channels");
  rst=1;make(0);image[0]=0;reset_dut;wait(err);check(seen==0,"invalid RIFF");
  rst=1;make(0);u32(40,9);reset_dut;wait(err);check(seen==0,"invalid length");
  rst=1;make(0);mode=1;reset_dut;wait(err);check(seen==0,"short sector never released");
  rst=1;mode=2;reset_dut;wait(err);check(seen==0,"CRC failure never released");
  init=0;repeat(5)@(negedge clk);check(!err && !ready,"reinit clears failure");
  if(errors==0)$display("ALL PASS tb_audio_wav");else $display("FAILED tb_audio_wav %0d",errors);$finish;
 end
 initial begin #5000000;$display("FAILED WAV watchdog");$finish;end
endmodule
