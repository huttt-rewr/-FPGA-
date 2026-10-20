`timescale 1ns/1ps
// Exercise both request engines with lengths that are not burst multiples.
module tb_frame_tail;
 reg clk=0,rst=1,req=0;
 reg [20:0] length=1;
 wire wa,ra,we,re,wf,rf;
 wire [20:0] waddr,raddr;
 integer wn=0,rn=0,errors=0,k;
 reg wdone=0,rdone=0;
 always #5 clk=~clk;
 frame_fifo_write #(.BURST_SIZE(256),.WRITE_V_FLIP(0)) writer(
  .rst(rst),.mem_clk(clk),.Sdr_init_done(1'b1),.Sdr_init_ref_vld(1'b0),.Sdr_busy(1'b0),
  .App_rd_busy(1'b0),.O_wr_busy(),.fifo_aclr(),.App_wr_en(we),.App_wr_addr(waddr),.write_req(req),.write_req_ack(wa),
  .write_finish(wf),.write_addr_0(21'd100),.write_addr_1(21'd0),.write_addr_2(21'd0),
  .write_addr_3(21'd0),.write_addr_index(2'd0),.write_len(length),.rdusedw(9'd511));
 frame_fifo_read #(.BURST_SIZE(256)) reader(
  .rst(rst),.mem_clk(clk),.Sdr_init_done(1'b1),.Sdr_init_ref_vld(1'b0),.Sdr_busy(1'b0),
  .Sdr_rd_en(re),.App_wr_busy(1'b0),.O_rd_busy(),.fifo_aclr(),.App_rd_en(re),.App_rd_addr(raddr),
  .read_req(req),.read_req_ack(ra),.read_finish(rf),.read_addr_0(21'd100),
  .read_addr_1(21'd0),.read_addr_2(21'd0),.read_addr_3(21'd0),
  .read_addr_index(2'd0),.read_len(length),.wrusedw(9'd0));
 always @(posedge clk) if(!rst) begin
  if(we) begin
   if(waddr !== 100+wn || wn>=length) errors=errors+1;
   wn=wn+1;
  end
  if(re) begin
   if(raddr !== 100+rn || rn>=length) errors=errors+1;
   rn=rn+1;
  end
  if(wf) wdone=1;
  if(rf) rdone=1;
 end
 task transfer;
  input [20:0] size;
  begin
   rst=1;req=0;length=size;
   repeat(4) @(negedge clk);
   wn=0;rn=0;wdone=0;rdone=0;rst=0;req=1;
   wait(wa && ra);@(negedge clk);req=0;
   for(k=0;k<2000 && !(wdone && rdone);k=k+1) @(negedge clk);
   if(!wdone || !rdone || wn!=size || rn!=size) begin
    $display("FAILED tail length=%0d write=%0d/%0d read=%0d/%0d",size,wn,wdone,rn,rdone);
    errors=errors+1;
   end
  end
 endtask
 initial begin
  transfer(1);transfer(127);transfer(128);transfer(129);
  transfer(255);transfer(256);transfer(257);transfer(511);transfer(512);transfer(513);
  if(errors==0) $display("ALL PASS tb_frame_tail: exact read/write lengths, tails and completion");
  else $display("FAILED tb_frame_tail %0d",errors);
  $finish;
 end
 initial begin #500000;$display("FAILED watchdog tb_frame_tail");$finish;end
endmodule
