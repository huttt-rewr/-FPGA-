`timescale 1ns/1ps
module tb_picture_gamma;
 reg clk=0,rst=1,vs=1,de=0,en=0;always #5 clk=~clk;
 reg [9:0] x=0;reg [23:0] rgb=0;
 wire ov,od;wire [9:0] ox,oy;wire [23:0] result;
 integer i,j,seen=0,errors=0;
 reg [35:0] expected=0,previous=0;
 picture_gamma dut(clk,rst,vs,de,x,rgb,en,ov,od,ox,result,10'd0,oy);
 function [7:0] reference;
  input [7:0] n;real r;integer ten,eight;
  begin
   r=n/255.0;ten=$rtoi(1023.0*(r**(1.0/2.2))+0.5);
   eight=(ten+2)/4;reference=(eight>255)?255:eight;
  end
 endfunction
 always @(posedge clk)if(!rst)begin
  previous=expected;
  expected={vs,de,x,de?(en?{reference(rgb[23:16]),reference(rgb[15:8]),reference(rgb[7:0])}:rgb):24'd0};
  #1;
  if(seen>0 && {ov,od,ox,result}!==previous)begin
   if(errors<5)$display("FAILED gamma actual=%h expected=%h",{ov,od,ox,result},previous);
   errors=errors+1;
  end
  seen=seen+1;
 end
 initial begin
  repeat(4)@(negedge clk);rst=0;
  for(j=0;j<3;j=j+1)for(i=0;i<256;i=i+1)begin
   en=(j==1 || (j==2 && i%2==0));
   rgb={i[7:0],8'd255-i[7:0],i[7:0]};x=i;vs=(i%11!=0);de=(i%7!=0);
   @(negedge clk);
  end
  repeat(4)@(negedge clk);
  if(errors==0)$display("ALL PASS tb_picture_gamma: independent real-power reference, 256 values, bypass/enabled, mixed controls, RGB/VS/DE/X alignment");
  else $display("FAILED tb_picture_gamma %0d",errors);
  $finish;
 end
endmodule
