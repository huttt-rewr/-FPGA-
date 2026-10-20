`timescale 1ns/1ps
module tb_fps_control;
 reg clk=0,rst=1,enable=0,busy=0;reg [3:0] mode=0;always #5 clk=~clk;
 wire tick,limited;wire [5:0] fps;
 fps_control #(.CLK_FREQ_HZ(3000)) dut(clk,rst,enable,busy,mode,tick,limited,fps);
 integer errors=0,j,n,ticks=0,last_tick=0,cycle=0,expected,elapsed;
 always @(posedge clk)begin cycle=cycle+1;#1;if(tick)begin ticks=ticks+1;last_tick=cycle;end end
 task check;input ok;input [511:0] msg;begin
  if(ok!==1)begin errors=errors+1;$display("FAIL fps %0s",msg);end
 end endtask
 initial begin
  repeat(5)@(negedge clk);rst=0;
  for(j=0;j<6;j=j+1)begin
   @(negedge clk);enable=0;mode=j;repeat(3)@(negedge clk);
   case(j)0:expected=3000;1:expected=1500;2:expected=600;3:expected=300;4:expected=200;5:expected=100;endcase
   enable=1;n=ticks;elapsed=cycle;
   wait(ticks==n+1);@(negedge clk);check(cycle-elapsed==expected,"first target interval");
   elapsed=last_tick;wait(ticks==n+2);@(negedge clk);check(last_tick-elapsed==expected,"steady target interval");
   check(fps==3000/expected,"requested FPS indication");
  end
  // A delayed frame holds at one expired request: no unbounded pending queue.
  @(negedge clk);busy=1;n=ticks;repeat(350)@(negedge clk);
  check(ticks==n && limited,"late frame busy guard / limit observation");
  busy=0;@(negedge clk);check(ticks==n+1,"ready after slow frame emits one request");
  repeat(10)@(negedge clk);check(ticks==n+1,"no burst catch-up");
  mode=0;repeat(10)@(negedge clk);check(!limited && ticks==n+1,"mode change resets deadline and limited flag");
  enable=0;repeat(3100)@(negedge clk);check(ticks==n+1,"disabled no auto requests");
  if(errors==0)$display("ALL PASS tb_fps_control: six periods, mode update, busy deadline guard, no backlog, target vs limited");
  else $display("FAILED fps errors=%0d",errors);
  $finish;
 end
 initial begin #500000;$display("FAILED fps watchdog");$finish;end
endmodule
