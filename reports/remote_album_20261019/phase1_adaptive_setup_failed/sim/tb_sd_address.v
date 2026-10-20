`timescale 1ns/1ps
// Command-layer peer: verifies OCR/CCS selection, not electrical SPI timing.
module tb_sd_address;
 reg clk=0,rst=1,ack=0,err=0,rv=0,read=0,write=0;
 reg [7:0] rd=0;reg [31:0] address=123;
 wire init,req,transfer_error,sector_end;wire [47:0] cmd;wire [15:0] div,len;wire [7:0] r1;
 integer errors=0;
 always #5 clk=~clk;
 sd_card_sec_read_write #(.SPI_HIGH_SPEED_DIV(3)) dut(
  .clk(clk),.rst(rst),.sd_init_done(init),.sd_sec_read(read),.sd_sec_read_addr(address),
  .transfer_error(transfer_error),.sd_sec_read_end(sector_end),
  .sd_sec_write(write),.sd_sec_write_addr(address),.sd_sec_write_data(8'd0),
  .spi_clk_div(div),.cmd_req(req),.cmd_req_ack(ack),.cmd_req_error(err),
  .response_valid(rv),.response_data(rd),.cmd(cmd),.cmd_r1(r1),.cmd_data_len(len),
  .block_read_valid(1'b0),.block_read_data(8'd0),.block_read_req_ack(1'b0),
  .block_write_data_rd(1'b0),.block_write_req_ack(1'b0));
 task finish_cmd;input [7:0] expected;begin
  wait(req && cmd[47:40]==expected);@(negedge clk);ack=1;@(negedge clk);ack=0;
 end endtask
 task boot;input ccs;begin
  rst=1;read=0;write=0;ack=0;repeat(4)@(negedge clk);rst=0;
  finish_cmd(0);r7(32'h000001aa,4);finish_cmd(55);finish_cmd(41);
  wait(req && cmd[47:40]==58);@(negedge clk);
  if(init || len!=4) errors=errors+1;
  rv=1;rd=ccs?8'hc0:8'h80;@(negedge clk);rd=0;
  repeat(2)@(negedge clk);ack=1; // ack overlaps the last OCR byte, as in sd_card_cmd
  @(negedge clk);rv=0;ack=0;
  if(!ccs) finish_cmd(16);
  wait(init);repeat(3)@(negedge clk);
  if(div!=3)errors=errors+1;
 end endtask
 task r7;input [31:0] value;input integer bytes;integer j;begin
  wait(req && cmd[47:40]==8);@(negedge clk);
  for(j=0;j<bytes;j=j+1)begin
   rv=1;rd=value >> (8*(3-j));ack=(j==bytes-1);@(negedge clk);
  end
  rv=0;ack=0;
 end endtask
 task reject_r7;input [31:0] value;input integer bytes;integer j;begin
  rst=1;read=0;write=0;ack=0;rv=0;repeat(4)@(negedge clk);rst=0;
  finish_cmd(0);r7(value,bytes);
  repeat(15)begin @(negedge clk);if(init || (req && cmd[47:40]==55))errors=errors+1;end
  if(!req || cmd[47:40]!=0)errors=errors+1;
 end endtask
 initial begin
  reject_r7(32'h000002aa,4); // wrong accepted voltage
  reject_r7(32'h000001ab,4); // wrong echo
  reject_r7(32'h000001aa,3); // short response
  boot(1);read=1;wait(req && cmd[47:40]==17);#1;
  if(cmd[39:8]!=123)errors=errors+1;
  @(negedge clk);ack=1;err=1;@(negedge clk);ack=0;err=0;read=0;
  if(!transfer_error || sector_end)errors=errors+1;
  repeat(3)@(negedge clk);
  read=1;wait(req && cmd[47:40]==17);
  @(negedge clk);ack=1;@(negedge clk);ack=0;
  wait(dut.block_read_req);@(negedge clk);ack=1;err=1;
  @(negedge clk);ack=0;err=0;read=0;
  if(!transfer_error || sector_end || dut.block_read_req)errors=errors+1;
  boot(0);write=1;wait(req && cmd[47:40]==24);#1;
  if(cmd[39:8]!=(123*512))errors=errors+1;
  if(errors==0)$display("ALL PASS tb_sd_address: R7/OCR, addressing, command and token errors propagated");
  else $display("FAILED tb_sd_address %0d",errors);
  $finish;
 end
 initial begin #100000;$display("FAILED watchdog tb_sd_address");$finish;end
endmodule
