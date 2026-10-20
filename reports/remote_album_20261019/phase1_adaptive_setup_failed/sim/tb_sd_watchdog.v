`timescale 1ns/1ps
// Bounded init failure, quiet retry pause, then successful reinitialization.
module tb_sd_watchdog;
 reg clk=0,rst=1,ack=0,err=0,rv=0;
 reg [7:0] rd=0;
 wire init,init_err,req;wire [47:0] cmd;wire [15:0] div,len;wire [7:0] r1;
 integer errors=0;
 always #5 clk=~clk;
 sd_card_sec_read_write #(.INIT_TIMEOUT_CYCLES(100),.INIT_PAUSE_CYCLES(500)) dut(
  .clk(clk),.rst(rst),.sd_init_done(init),.init_error(init_err),
  .sd_sec_read(1'b0),.sd_sec_read_addr(32'd0),
  .sd_sec_write(1'b0),.sd_sec_write_addr(32'd0),.sd_sec_write_data(8'd0),
  .spi_clk_div(div),.cmd_req(req),.cmd_req_ack(ack),.cmd_req_error(err),
  .response_valid(rv),.response_data(rd),.cmd(cmd),.cmd_r1(r1),.cmd_data_len(len),
  .block_read_valid(1'b0),.block_read_data(8'd0),.block_read_req_ack(1'b0),
  .block_write_data_rd(1'b0),.block_write_req_ack(1'b0));
 task finish_cmd;input [7:0] expected;begin
  wait(req && cmd[47:40]==expected);@(negedge clk);ack=1;@(negedge clk);ack=0;
 end endtask
 task r7;input [31:0] value;input integer bytes;integer j;begin
  wait(req && cmd[47:40]==8);@(negedge clk);
  for(j=0;j<bytes;j=j+1)begin
   rv=1;rd=value >> (8*(3-j));ack=(j==bytes-1);@(negedge clk);
  end
  rv=0;ack=0;
 end endtask
 initial begin
  rst=1;repeat(4)@(negedge clk);rst=0;
  finish_cmd(0);       // CMD0 -> CMD8
  r7(32'h000001aa,4);  // CMD8 valid R7 -> CMD55
  finish_cmd(55);      // CMD55 -> CMD41
  // Drive the CMD55<->CMD41 loop: CMD41 always error-acked, never ready.
  repeat(400) begin
   @(negedge clk);
   if (req && cmd[47:40]==41) begin ack=1; err=1; end
   else if (req && cmd[47:40]==55) begin ack=1; err=0; end
   else begin ack=0; err=0; end
  end
  if(!init_err) errors=errors+1;  // watchdog must have tripped
  if(req) errors=errors+1;        // and cmd_req must be released
  wait(!init_err);
  finish_cmd(0);r7(32'h000001aa,4);finish_cmd(55);finish_cmd(41);
  wait(req && cmd[47:40]==58);@(negedge clk);
  rv=1;rd=8'hc0;@(negedge clk);rd=0;
  repeat(2)@(negedge clk);ack=1;@(negedge clk);rv=0;ack=0;
  wait(init);repeat(120)@(negedge clk);
  if(init_err || !init)errors=errors+1;
  if(errors==0) $display("ALL PASS tb_sd_watchdog: bounded failure, quiet pause, successful retry");
  else $display("FAILED tb_sd_watchdog %0d",errors);
  $finish;
 end
 initial begin #20000;$display("FAILED watchdog tb_sd_watchdog (timeout)");$finish;end
endmodule
