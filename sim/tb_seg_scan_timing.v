`timescale 1ns/1ps
module seg_scan_timing_case #(parameter LIMIT=7)(
 input clk,rst_n,input [47:0] digits,output reg failed,output reg [5:0] seen
);
 wire [5:0] sel;
 wire [7:0] data;
 integer timer,index;
 reg [5:0] expected_sel;
 reg [7:0] expected_data;
 seg_scan #(.SCAN_COUNT(LIMIT)) dut(.clk(clk),.rst_n(rst_n),
  .seg_sel(sel),.seg_data(data),.seg_data_0(digits[7:0]),
  .seg_data_1(digits[15:8]),.seg_data_2(digits[23:16]),
  .seg_data_3(digits[31:24]),.seg_data_4(digits[39:32]),
  .seg_data_5(digits[47:40]));
 initial begin failed=0;seen=0;end
 // Independent binary-selector model of the original cycle-by-cycle contract.
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin timer=0;index=0;expected_sel=6'b111111;expected_data=8'hff;end
  else begin
   expected_sel=~(6'b000001<<index);
   expected_data=(digits>>(index*8));
   seen=seen | (6'b000001<<index);
   if(timer>=LIMIT)begin timer=0;index=(index==5)?0:index+1;end
   else timer=timer+1;
  end
  #1;
  if(sel!==expected_sel || data!==expected_data)begin
   if(!failed)$display("FAILED seg_scan limit=%0d sel=%b/%b data=%h/%h",LIMIT,sel,expected_sel,data,expected_data);
   failed=1;
  end
 end
endmodule

module tb_seg_scan_timing;
 reg clk=0,rst_n=1;
 reg [47:0] digits=0;
 wire [3:0] failed;
 wire [5:0] seen0,seen1,seen2,seen3;
 integer n;
 always #5 clk=~clk;
 seg_scan_timing_case #(.LIMIT(0)) c0(clk,rst_n,digits,failed[0],seen0);
 seg_scan_timing_case #(.LIMIT(1)) c1(clk,rst_n,digits,failed[1],seen1);
 seg_scan_timing_case #(.LIMIT(7)) c2(clk,rst_n,digits,failed[2],seen2);
 seg_scan_timing_case #(.LIMIT(83332)) c3(clk,rst_n,digits,failed[3],seen3);
 initial begin
  #1;rst_n=0;repeat(3)@(negedge clk);rst_n=1;
  for(n=0;n<1100000;n=n+1)begin
   @(negedge clk);digits={$random,$random};
   if(n==113)rst_n=0;
   if(n==115)rst_n=1;
  end
  if(failed==0 && &seen0 && &seen1 && &seen2 && &seen3)
   $display("ALL PASS tb_seg_scan_timing: original cycle equivalence, six digits, zero/one/default period, dynamic data and async reset");
  else $display("FAILED tb_seg_scan_timing failed=%b seen=%b",failed,seen3);
  $finish;
 end
endmodule
