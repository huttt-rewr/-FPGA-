"""Build a pin-level peer/test for the isolated CMD6 candidate."""
from pathlib import Path
R=Path(__file__).resolve().parents[2];D=Path(__file__).resolve().parent/'highspeed'
s=(R/'sim/sd_native_card_model.v').read_text(encoding='utf-8')
s=s.replace('parameter integer IMAGE_MODE=0','parameter integer IMAGE_MODE=0,parameter integer DOUT_DELAY=0')
s=s.replace(' input ccs,input [3:0] fault,',' input ccs,input [3:0] fault,input [3:0] hs_mode,')
s=s.replace('assign SD_CMD=','assign #(DOUT_DELAY) SD_CMD=').replace('assign SD_DAT=','assign #(DOUT_DELAY) SD_DAT=')
s=s.replace('integer cmd_bits=0,', 'integer payload_length=512;reg switch_block=0;reg switched=0;\n integer cmd_bits=0,')
s=s.replace('for(i=0;i<512;i=i+1)begin','for(i=0;i<payload_length;i=i+1)begin')
s=s.replace('if(IMAGE_MODE!=0)begin','if(IMAGE_MODE!=0 && !switch_block)begin')
s=s.replace('if(IMAGE_MODE==0)payload[i]=pattern(i,arg);', 'if(IMAGE_MODE==0 && !switch_block)payload[i]=pattern(i,arg);')
a=s.index('    6:begin');b=s.index('    16:begin',a)
s=s[:a]+'''    6:begin
     if(app)begin
      if(!selected || arg!=2)errors=errors+1;
      app=0;wide=1;reply(6,32'h900);
     end else begin
      if(!selected || !wide || (arg!=32'h00fffff1 && arg!=32'h80fffff1))errors=errors+1;
      payload_length=64;switch_block=1;
      for(i=0;i<64;i=i+1)payload[i]=0;
      if(hs_mode!=0)payload[13]=2;
      if(hs_mode==2)payload[29]=2;
      if(arg[31] && hs_mode!=3)begin payload[16]=1;switched=1;end
      if(arg[31] && hs_mode==8)payload[29]=2;
      prepare_data;
      if((hs_mode==4 && !arg[31]) || (hs_mode==5 && arg[31]))data_crc[2]=data_crc[2]^16'h0100;
      reply(6,32'h900);
      data_pending=!((arg[31] && hs_mode==6) || hs_mode==9);
      if(hs_mode==7)resp_frame[5]=!resp_frame[5];
     end
    end
'''+s[b:]
s=s.replace('reads=reads+1;last_read_argument=arg;prepare_data;', 'payload_length=512;switch_block=0;reads=reads+1;last_read_argument=arg;prepare_data;')
s=s.replace('0:begin app=0;selected=0;wide=0;attempts=0;end', '0:begin app=0;selected=0;wide=0;attempts=0;switched=0;end')
s=s.replace('data_pos<=1024', 'data_pos<=payload_length*2').replace('data_pos<=1040','data_pos<=payload_length*2+16').replace('[1040-data_pos]', '[payload_length*2+16-data_pos]').replace('data_pos==1041','data_pos==payload_length*2+17')
(D/'sd_native_card_model.v').write_text(s,encoding='utf-8')
test='''`timescale 1ns/1ps
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
'''
(D/'tb_sd_highspeed.v').write_text(test,encoding='utf-8')
print('Prepared isolated CMD6 pin peer and nine recovery scenarios, with 6ns card output delay')
