`timescale 1ns/1ps
module tb_picture_controls;
 reg clk=0,rst=1;reg [2:0] keys=0;always #5 clk=~clk;
 wire n,p;wire signed [7:0] b;wire [3:0] c;wire [1:0] mode;
 integer errors=0,nexts=0,toggles=0,i;
 picture_controls #(.DEBOUNCE_CYCLES(4)) dut(clk,rst,keys[0],keys[1],keys[2],n,p,b,c,mode);
 always @(posedge clk)begin if(n)nexts=nexts+1;if(p)toggles=toggles+1;end
 task wait_keys;begin repeat(12)@(negedge clk);end endtask
 task press;input integer k;begin keys[k]=0;wait_keys;keys[k]=1;wait_keys;end endtask
 task check;input ok;begin if(ok!==1)begin errors=errors+1;$display("FAILED controls b=%d c=%d mode=%d",b,c,mode);end end endtask
 initial begin
  wait_keys;rst=0;wait_keys;check(nexts==0 && toggles==0 && mode==0);
  keys=7;wait_keys;keys[0]=0;@(negedge clk);keys[0]=1;wait_keys;check(nexts==0);
  press(0);press(1);check(nexts==1 && toggles==1);
  press(2);check(mode==1);
  for(i=0;i<12;i=i+1)press(1);check(b==64 && toggles==1);
  for(i=0;i<20;i=i+1)press(0);check(b== -64 && nexts==1);
  press(2);check(mode==2);
  for(i=0;i<10;i=i+1)press(1);check(c==8);
  for(i=0;i<12;i=i+1)press(0);check(c==2);
  keys[1]=0;wait_keys;repeat(100)@(negedge clk);check(c==3);keys[1]=1;wait_keys;
  press(2);check(mode==0);press(0);check(nexts==2);
  rst=1;wait_keys;rst=0;wait_keys;check(b==0 && c==4 && mode==0);
  if(errors==0)$display("ALL PASS tb_picture_controls: reset-held suppression, bounce, modes, bounded adjustments, one action per press");
  else $display("FAILED tb_picture_controls %0d",errors);
  $finish;
 end
endmodule
