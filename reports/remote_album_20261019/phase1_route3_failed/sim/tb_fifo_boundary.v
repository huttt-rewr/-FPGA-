`timescale 1ns/1ps
module tb_fifo_boundary;
 reg wc=0,rc=0,rst=1,we=0,re=0;reg [31:0] din=0;
 always #5 wc=~wc;always #7 rc=~rc;
 wire [31:0] dout;wire full,empty;wire [8:0] used_r,used_w;
 integer i,errors=0;
 wfifo_32_32_512 dut(.rst(rst),.clkw(wc),.clkr(rc),.we(we),.di(din),.re(re),
  .dout(dout),.full_flag(full),.empty_flag(empty),.wrusedw(used_w),.rdusedw(used_r));
 initial begin
  repeat(5)@(negedge wc);rst=0;repeat(8)@(negedge wc);
  for(i=0;i<511;i=i+1)begin we=1;din=i;@(negedge wc);end
  we=0;repeat(12)@(negedge rc);
  if(!full || used_w!=511 || used_r!=511)errors=errors+1;
  @(negedge wc);we=1;din=32'hbad;repeat(5)@(negedge wc);we=0;
  repeat(10)@(negedge rc);
  if(used_w!=511 || used_r!=511)errors=errors+1;
  for(i=0;i<511;i=i+1)begin
   @(negedge rc);if(empty || dout!==i)errors=errors+1;re=1;
  end
  @(negedge rc);re=0;repeat(12)@(negedge rc);
  if(!empty || full || used_r!=0)errors=errors+1;
  if(errors==0)$display("ALL PASS tb_fifo_boundary: 511 usable slots, no counter wrap, exact data order");
  else $display("FAILED tb_fifo_boundary %0d",errors);
  $finish;
 end
endmodule
