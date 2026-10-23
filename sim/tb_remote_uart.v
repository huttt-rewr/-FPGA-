`timescale 1ns/1ps
module tb_remote_uart;
 reg clk=0,vclk=0,rst=1,rx=1,vs=1;
 always #5 clk=~clk;
 always #7 vclk=~vclk;
 wire tx,overflow,np,pp,tp,ts,auto_enh,slide,zh,clock_big;
 wire [23:0] time_bcd;
 wire [7:0] seq,reply;
 wire rv;
 wire [32:0] snapshot;
 integer errors=0,n=0,p=0,b=0,count=0;
 reg [7:0] replies[0:31];
 remote_controls #(.CLK_HZ(1600000),.BAUD(100000),.TIMEOUT_CYCLES(500)) dut(
 clk,rst,rx,tx,overflow,np,pp,tp,time_bcd,seq,ts,1'b1,auto_enh,slide,zh,clock_big);
 uart_rx #(.CLK_FREQ(1600000),.BAUD(100000)) monitor(clk,rst,tx,reply,rv);
 cdc_snapshot #(.WIDTH(33)) cdc(clk,rst,{ts,seq,time_bcd},vclk,rst,snapshot);
 caption_overlay #(.CLK_HZ(100)) caption(.clk(vclk),.rst(rst),.vs(vs),.de(1'b0),.rgb(24'd0),
 .enable(1'b0),.scroll_enable(1'b0),.slogan_select(2'd0),.transition_mode(2'd0),.mode_800(1'b0),
 .large_clock(1'b0),.time_set(snapshot[32]),.time_seq(snapshot[31:24]),.time_bcd(snapshot[23:0]));
 always @(posedge clk)if(!rst)begin
  if(np)n=n+1;if(pp)p=p+1;if(tp)b=b+1;
  if(rv)begin replies[count]=reply;count=count+1;end
 end
 task check;input ok;input [511:0]msg;begin
  if(ok!==1)begin errors=errors+1;$display("FAILED %s",msg);end
 end endtask
 task byte;input [7:0]value;integer k;begin
  @(negedge clk);rx=0;repeat(16)@(negedge clk);
  for(k=0;k<8;k=k+1)begin rx=value[k];repeat(16)@(negedge clk);end
  rx=1;repeat(16)@(negedge clk);
 end endtask
 task blank;begin @(negedge vclk);vs=0;repeat(3)@(negedge vclk);vs=1;repeat(3)@(negedge vclk);end endtask
 initial begin
  repeat(5)@(negedge clk);rst=0;
  byte("n");byte("p");byte("b");byte("z");
  byte("T");byte("2");byte("3");byte("5");byte("9");byte("5");byte("9");
  repeat(40)@(negedge clk);
  check(time_bcd==24'h235959 && seq==1 && ts,"one atomic valid time publication");
  check(caption.displayed_time==0 && !caption.displayed_wall,"visible time and label hold until blank");
  blank;check(caption.displayed_time==24'h235959 && caption.displayed_wall,"coherent time plus BJ label at blank");
  repeat(105)@(negedge vclk);blank;
  check(caption.displayed_time==0,"23:59:59 rolls over at midnight");
  byte("T");byte("2");byte("4");byte("0");byte("0");byte("0");byte("0");
  check(time_bcd==24'h235959 && seq==1,"invalid hours rejected without state update");
  byte("T");byte("n");
  byte("T");byte("1");byte("2");repeat(520)@(negedge clk);
  byte("n");repeat(400)@(negedge clk);
 check(n==0 && p==0 && b==0,"UART media commands no longer trigger playback");
  check(count==4,"time parser replies for valid, range, nondigit and timeout only");
  check({replies[0],replies[1],replies[2],replies[3]}=={"K","?","?","?"},"valid time K; range, nondigit and timeout each return ?");
 byte("a");repeat(200)@(negedge clk);
 check(!auto_enh && count==4,"UART a is ignored and does not control playback");
 byte("a");repeat(200)@(negedge clk);
 check(!auto_enh && count==4,"UART playback path remains disabled");
  byte("s");byte("h");byte("l");repeat(220)@(negedge clk);
 check(!slide && !zh && !clock_big && !auto_enh && count==4,"UART optional media commands are ignored");
  byte("s");byte("h");byte("l");repeat(220)@(negedge clk);
 check(!slide && !zh && !clock_big && count==4,"UART does not toggle optional media controls");
  check(!overflow,"bounded response queue no overflow");
  rst=1;repeat(4)@(negedge clk);
  check(seq==0 && !ts && time_bcd==0,"reset disables wallclock and clears time");
  check(!slide && !zh && !clock_big && !auto_enh,"reset restores all new features to disabled");
  if(errors==0)$display("ALL PASS tb_remote_uart: time-only 8N1 interface, atomic timestamp, range, timeout, recovery, media bytes ignored, CDC, frame latch, midnight");
  else $display("FAILED tb_remote_uart %d",errors);
  $finish;
 end
 initial begin #1000000;$display("FAILED watchdog tb_remote_uart");$finish;end
endmodule
