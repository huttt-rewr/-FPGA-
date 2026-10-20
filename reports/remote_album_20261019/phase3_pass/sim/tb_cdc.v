`timescale 1ns/1ps
module tb_cdc;
reg sc=0,dc=0,rst=1;always #5 sc=~sc;always #7 dc=~dc;
reg [15:0] src=0;wire [15:0] dst,encoded_dst;
integer i,errors=0;
cdc_snapshot #(.WIDTH(16)) dut(sc,rst,src,dc,rst,dst);
cdc_snapshot #(.WIDTH(16),.ENCODE_HOLD(1)) coded(sc,rst,src,dc,rst,encoded_dst);
always @(posedge dc)begin
 #1;if(encoded_dst!==dst)begin
  $display("FAILED polarity-coded CDC differs: %h %h",encoded_dst,dst);errors=errors+1;
 end
end
initial begin
 #53;rst=0;
 for(i=1;i<100;i=i+1) begin @(negedge sc);src=i*257;end
 #1000;
 if(dst!==src) errors=errors+1;
 rst=1;#1;if(dst!==0) errors=errors+1;#53;src=16'ha55a;rst=0;#1000;
 if(dst!==src) errors=errors+1;
 if(errors==0) $display("ALL PASS tb_cdc");else $display("FAILED tb_cdc %0d",errors);
 $finish;
end
always @(posedge dc) if(!rst && dst[15:8]!==dst[7:0] && dst!==16'ha55a) begin
 $display("FAILED torn CDC word %h",dst);errors=errors+1;end
endmodule
