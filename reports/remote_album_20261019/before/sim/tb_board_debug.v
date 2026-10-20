`timescale 1ns/1ps
module tb_board_debug;
 reg clk=0,vc=0,mc=0,rst=1,vs=1,hs=1,de=0;
 always #5 clk=~clk;always #13 vc=~vc;always #11 mc=~mc;
 reg [1:0] page=0;reg [19:0] mem_status=20'ha52a5;
 reg [10:0] read_status=11'h5ab;reg [7:0] flags=8'hd7;
 wire [23:0] word;
 integer errors=0,i;
 board_debug #(.UPDATE_CYCLES(10)) dut(clk,rst,vc,rst,mc,rst,
  vs,hs,de,flags,mem_status,read_status,8'h12,4'ha,4'h5,page,word);
 task settle;begin repeat(80)@(negedge clk);end endtask
 task check;input [23:0] expected;begin
  if(word!==expected)begin errors=errors+1;$display("FAILED debug page %d actual=%h expected=%h",page,word,expected);end
 end endtask
 initial begin
  repeat(5)@(negedge clk);rst=0;settle;
  check(24'h000007);
  @(negedge vc);vs=0;@(negedge vc);vs=1;
  for(i=0;i<3;i=i+1)begin @(negedge vc);hs=0;@(negedge vc);hs=1;end
  settle;check(24'h001037);
  page=1;settle;check({4'h1,mem_status});
  page=2;settle;check({4'h2,1'b0,flags,read_status});
  page=3;settle;check(24'h312a50);
  // A new source-domain sample must eventually arrive intact.
  mem_status=20'h13579;page=1;settle;check(24'h113579);
  rst=1;repeat(4)@(negedge clk);check(0);
  rst=0;page=0;settle;check(24'h000007);
  if(errors==0)$display("ALL PASS tb_board_debug: unrelated clocks, coherent buses, frame/line counters, four pages, reset");
  else $display("FAILED tb_board_debug %0d",errors);
  $finish;
 end
 initial begin #100000;$display("FAILED watchdog debug");$finish;end
endmodule
