`timescale 1ns/1ps
module tb_shift_equivalence;
 sd_fat32 dut(.clk(1'b0),.rst(1'b1),.sd_init_done(1'b0));
 integer shift,index,seed=20261016,checks=0;
 reg [31:0] value;
 reg [7:0] sectors;
 task check_value;
  input [31:0] v;
  begin
   if(dut.shr_spc(v,sectors)!==(v>>shift) || dut.shl_spc(v,sectors)!==(v<<shift))begin
    $display("FAILED shift=%0d value=%h",shift,v);$finish;
   end
   checks=checks+2;
  end
 endtask
 initial begin
  for(shift=0;shift<8;shift=shift+1)begin
   sectors=1<<shift;
   check_value(0);check_value(32'hffffffff);check_value(32'h80000000);check_value(1);
   for(index=0;index<32;index=index+1)check_value(32'b1<<index);
   for(index=0;index<4096;index=index+1)begin value=$random(seed);check_value(value);end
  end
  $display("ALL PASS shift_equivalence: %0d logical shifts, eight legal cluster sizes",checks);
  $finish;
 end
endmodule
