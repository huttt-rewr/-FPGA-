`timescale 1ns/1ps
module tb_sd_highspeed #(parameter integer CARD_DELAY=6);
 reg clk=0,rst=1,req=0;always #5 clk=~clk;
 reg [3:0] mode=1;reg [31:0] addr=0;
 tri1 cmd,d0,d1,d2,d3;wire sclk,init,ie,err,dv,de;wire [7:0] data;wire [31:0] pe;
 integer errors=0,bytes=0,n,k,cycles=0,start_cycle,total,ticks=0,cmd6=0;
 time edge_time=0;reg clock_check=0,fast_expected=0;
 sd_card_top_native #(.ENABLE_HIGH_SPEED(1),.SPI_LOW_SPEED_DIV(0),
  .WAIT_TIMEOUT_CYCLES(12000),.INIT_TIMEOUT_CYCLES(1000000),.INIT_PAUSE_CYCLES(200)) dut(
 .clk(clk),.rst(rst),.SD_CLK(sclk),.SD_CMD(cmd),.SD_DAT0(d0),.SD_DAT1(d1),.SD_DAT2(d2),.SD_DAT3(d3),
 .sd_init_done(init),.sd_init_error(ie),.sd_transfer_error(err),.sd_sec_read(req),.sd_sec_read_addr(addr),
 .sd_sec_read_data(data),.sd_sec_read_data_valid(dv),.sd_sec_read_end(de),
 .sd_sec_write(1'b0),.sd_sec_write_addr(32'd0),.sd_sec_write_data(8'd0),.sd_sec_write_data_req(),.sd_sec_write_end());
 sd_native_card_model #(.DOUT_DELAY(CARD_DELAY)) card(.rst(rst),.SD_CLK(sclk),.SD_CMD(cmd),
 .SD_DAT({d3,d2,d1,d0}),.ccs(1'b1),.fault(4'd0),.hs_mode(mode),.last_read_argument(),.commands(),.reads(),.errors(pe));
 task check;input ok;input [511:0] msg;begin
 if(ok!==1)begin errors=errors+1;$display("FAIL highspeed mode=%0d %0s",mode,msg);end
 end endtask
 always @(posedge clk)begin
 cycles=cycles+1;
 if(!rst && dv)begin
  check(data===card.pattern(bytes,addr),"byte/lane order with delayed card outputs");bytes=bytes+1;
 end
 if(!rst && de)check(bytes==512,"complete sector after CRC");
 if(!rst && err)check(0,"unexpected sector error");
 end
 always @(sclk)begin
 if(clock_check)begin
  if(edge_time!=0)check($time-edge_time==(fast_expected?10:20),"selected line clock half-period");
  edge_time=$time;
 end else edge_time=0;
 end
 task boot;input [3:0] scenario;begin
 @(negedge clk);rst=1;clock_check=0;req=0;mode=scenario;
 repeat(8)@(negedge clk);rst=0;wait(init);repeat(15)@(negedge clk);
 check(!ie,"initialization/fallback completes");
 fast_expected=(scenario==1);check(dut.high_speed_50==fast_expected,"50MHz only after successful CMD6");
 check(card.switched==fast_expected,"card/host agree on mode after recovery");
 check(pe==0,"peer rejected command frame or argument");clock_check=1;
 end endtask
 task sector;input integer index;begin
 @(negedge clk);bytes=0;addr=index;req=1;wait(de || err);
 repeat(2)@(negedge clk);req=0;repeat(4)@(negedge clk);
 end endtask
 initial begin
 boot(1);start_cycle=cycles;
 for(n=0;n<16;n=n+1)sector(100+n);
 total=cycles-start_cycle;check(total<45511,"sustained SDR50 >=18MB/s including CMD17/CRC/handshake");
 $display("SDR50 logical peer: 8192B/%0d host cycles = %0f MB/s; card output delay=%0dns",total,819200.0/total,CARD_DELAY);
 for(k=0;k<=9;k=k+1)if(k!=1)begin boot(k);sector(77+k);end
 if(errors==0)$display("ALL PASS tb_sd_highspeed: CMD6 support/check/switch/busy/reject, four-lane status CRC, timeout/response error reinit25, delayed pin peer and 50MHz throughput");
 else $display("FAILED highspeed errors=%0d",errors);
 $finish;
 end
 initial begin #20000000;$display("FAILED highspeed watchdog state=%0d step=%0d mode=%0d",dut.controller.state,dut.controller.step,mode);$finish;end
endmodule
