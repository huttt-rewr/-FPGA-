`timescale 1ns/1ps
module tb_sd_waits;
 reg clk=0,rst=1,read_req=0,write_req=0,spi_ack=0;
 reg [7:0] received=8'hff;
 wire request,cmd_ack,cmd_error,read_ack,write_ack,read_valid;
 integer errors=0,read_bytes=0,boot_bytes=0,pauses=0,i;
 reg pause_d=0;
 always #5 clk=~clk;
 sd_card_cmd #(.WAIT_TIMEOUT_CYCLES(32)) dut(
  .sys_clk(clk),.rst(rst),.spi_clk_div(16'd0),.cmd_req(1'b0),
  .cmd_req_ack(cmd_ack),.cmd_req_error(cmd_error),.cmd(48'd0),.cmd_r1(8'd0),
  .cmd_data_len(16'd0),.block_read_req(read_req),.block_read_req_ack(read_ack),
  .block_read_valid(read_valid),.block_write_req(write_req),.block_write_data(8'ha5),
  .block_write_req_ack(write_ack),.spi_wr_req(request),.spi_wr_ack(spi_ack),
  .spi_data_out(received));
 // A byte-level SPI peer. FF means absent token, FE starts a read.
 always @(negedge clk) begin
  if(rst)spi_ack=0;else spi_ack=request && !spi_ack;
 end
 always @(posedge clk)begin
  if(!rst && dut.state==dut.S_INIT && spi_ack)boot_bytes=boot_bytes+1;
  if(!rst && read_valid)read_bytes=read_bytes+1;
 end
 // Exercise the real wrapper with an absent card; retry must reset lower layers.
 wire init_fail;
 sd_card_top #(.SPI_LOW_SPEED_DIV(0),.INIT_TIMEOUT_CYCLES(100),.INIT_PAUSE_CYCLES(20)) wrapper(
  .clk(clk),.rst(rst),.SD_MISO(1'b1),.sd_init_error(init_fail),
  .sd_sec_read(1'b0),.sd_sec_read_addr(32'd0),.sd_sec_write(1'b0),
  .sd_sec_write_addr(32'd0),.sd_sec_write_data(8'd0));
 always @(negedge clk)begin
  if(!rst)begin
   if(init_fail && !pause_d)pauses=pauses+1;
   if(init_fail && (wrapper.sd_card_cmd_m0.state!=wrapper.sd_card_cmd_m0.S_IDLE || wrapper.spi_wr_req))errors=errors+1;
   pause_d=init_fail;
  end
 end
 task wait_idle;begin wait(dut.state==dut.S_WAIT);@(negedge clk);end endtask
 task expect_error;begin
  wait(cmd_ack && cmd_error);@(negedge clk);
  if(read_ack || write_ack)errors=errors+1;
  read_req=0;write_req=0;wait_idle;
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;wait_idle;
  if(boot_bytes!=11 || dut.byte_cnt!=0)errors=errors+1;
  read_req=1;received=8'hff;expect_error;
  // A subsequent normal sector still delivers exactly 512 payload bytes.
  read_bytes=0;read_req=1;received=8'hfe;
  wait(dut.state==dut.S_READ && dut.byte_cnt==512);@(negedge clk);received=8'h9c;
  wait(dut.byte_cnt==513);@(negedge clk);received=8'h0f;
  wait(read_ack);@(negedge clk);read_req=0;
  if(read_bytes!=512 || cmd_error)errors=errors+1;
  wait_idle;
  write_req=1;received=8'hff;expect_error; // missing write response
  write_req=1;received=8'h05;
  wait(dut.state==dut.S_WRITE_BUSY);@(negedge clk);received=0;
  expect_error; // card remains busy
  if(pauses<2)errors=errors+1;
  if(errors==0)$display("ALL PASS tb_sd_waits: startup count, token/write waits, read recovery, wrapper retries");
  else $display("FAILED tb_sd_waits %0d bytes=%0d boot=%0d pauses=%0d",errors,read_bytes,boot_bytes,pauses);
  $finish;
 end
 initial begin #200000;$display("FAILED watchdog tb_sd_waits");$finish;end
endmodule
