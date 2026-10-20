`timescale 1ns/1ps
// Byte-level SPI peer; CRC reference is bit-serial and independently fed.
module tb_sd_crc;
 reg clk=0,rst=1,read_req=0,spi_ack=0;
 reg [7:0] received=8'hff;
 wire request,done,ack,error,valid;
 wire [7:0] payload;
 integer errors=0,bytes=0,j,bit_index,trial;
 reg [15:0] reference;
 reg [7:0] b;
 always #5 clk=~clk;
 sd_card_cmd dut(.sys_clk(clk),.rst(rst),.spi_clk_div(16'd0),
  .cmd_req(1'b0),.cmd_req_ack(ack),.cmd_req_error(error),.cmd(48'd0),
  .cmd_r1(8'd0),.cmd_data_len(16'd0),.block_read_req(read_req),
  .block_read_req_ack(done),.block_read_valid(valid),.block_read_data(payload),
  .block_write_req(1'b0),.block_write_data(8'd0),.spi_wr_req(request),
  .spi_wr_ack(spi_ack),.spi_data_out(received));
 always @(posedge clk) if(valid)bytes=bytes+1;
 task byte_transfer;input [7:0] value;begin
  wait(request);@(negedge clk);received=value;spi_ack=1;
  @(negedge clk);spi_ack=0;repeat(2)@(negedge clk);
 end endtask
 task run_sector;input corrupt;begin
  wait(dut.state==dut.S_WAIT);@(negedge clk);bytes=0;read_req=1;
  byte_transfer(8'hfe);reference=0;
  for(j=0;j<512;j=j+1)begin
   b=(j*37+trial*19)&255;
   for(bit_index=7;bit_index>=0;bit_index=bit_index-1)
    reference=(reference<<1)^((reference[15]^b[bit_index])?16'h1021:16'h0000);
   byte_transfer((corrupt && j==127)?(b^8'h01):b);
  end
  byte_transfer(reference[15:8]);
  // Observe the terminal state before it returns to idle.
  wait(request);@(negedge clk);received=reference[7:0];spi_ack=1;
  @(negedge clk);spi_ack=0;read_req=0;
  if(corrupt)begin
   if(done)errors=errors+1;
   wait(ack);if(!error)errors=errors+1;
  end else if(!done || error)errors=errors+1;
  if(bytes!=512)errors=errors+1;
  repeat(5)@(negedge clk);
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;
  for(j=0;j<11;j=j+1)byte_transfer(8'hff);
  for(trial=0;trial<3;trial=trial+1)run_sector(trial==1);
  if(errors==0)$display("ALL PASS tb_sd_crc: valid block, flipped payload bit rejected, next valid block recovers");
  else $display("FAILED tb_sd_crc %0d",errors);
  $finish;
 end
 initial begin #1000000;$display("FAILED watchdog tb_sd_crc");$finish;end
endmodule
