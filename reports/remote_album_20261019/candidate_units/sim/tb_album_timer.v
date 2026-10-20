`timescale 1ns/1ps
module tb_album_timer;
 reg clk=0,rst=1,en=0,busy=0;always #5 clk=~clk;
 wire p1,p2,p7;integer errors=0,cycles=0,c1=0,c2=0,c7=0,k;
 integer r1=0,r2=0,r7=0;reg e1,e2,e7;reg [31:0] random_state=32'h12345678;
 slideshow_timer #(.PERIOD(1)) a(clk,rst,en,busy,p1);
 slideshow_timer #(.PERIOD(2)) b(clk,rst,en,busy,p2);
 slideshow_timer #(.PERIOD(7)) c(clk,rst,en,busy,p7);
 task model;input integer period;inout integer count;output pulse;begin
  pulse=0;
  if(!en)count=0;
  else if(count>=period-1)begin if(!busy)begin count=0;pulse=1;end end
  else count=count+1;
 end endtask
 always @(posedge clk)begin
  if(rst)begin r1=0;r2=0;r7=0;e1=0;e2=0;e7=0;end
  else begin model(1,r1,e1);model(2,r2,e2);model(7,r7,e7);end
  #1;
  if({p1,p2,p7}!=={e1,e2,e7})begin
   if(errors<5)$display("FAILED timer cycle=%d got=%b want=%b",cycles,{p1,p2,p7},{e1,e2,e7});errors=errors+1;
  end
  if(p1)c1=c1+1;if(p2)c2=c2+1;if(p7)c7=c7+1;cycles=cycles+1;
 end
 initial begin
  repeat(4)@(negedge clk);rst=0;en=1;repeat(70)@(negedge clk);
  if(c1!=70 || c2!=35 || c7!=10)begin errors=errors+1;$display("FAILED exact cadence %d %d %d",c1,c2,c7);end
  busy=1;repeat(40)@(negedge clk);busy=0;repeat(20)@(negedge clk);
  for(k=0;k<2000;k=k+1)begin
   random_state={random_state[30:0],random_state[31]^random_state[21]^random_state[1]^random_state[0]};
   en=(random_state[5:0]!=0);busy=random_state[6];@(negedge clk);
  end
  rst=1;repeat(4)@(negedge clk);rst=0;en=1;busy=0;repeat(30)@(negedge clk);
  if(errors==0)$display("ALL PASS tb_album_timer: exact periods 1/2/7, busy saturation, one pending event, disable/reset, randomized reference");
  else $display("FAILED tb_album_timer %d",errors);$finish;
 end
 initial begin #100000;$display("FAILED watchdog tb_album_timer");$finish;end
endmodule
