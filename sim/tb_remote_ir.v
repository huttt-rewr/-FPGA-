`timescale 1ns/1ps
module tb_remote_ir;
 reg clk=0,rst=1,ir=1;
 always #5 clk=~clk;
 wire np,pp,tp,tx,overflow;
 wire vu,vd,mt,bu,bd,cu,cd,osd,pat,tr;
 wire [1:0] tm,sl;
 wire enh,album,zh,clock_big,cap,scroll;
 integer errors=0,n=0,p=0,b=0,vc_up=0,vc_dn=0,mc=0,bc_up=0,bc_dn=0,cc_up=0,cc_dn=0,oc=0,pc=0,tc=0;
 remote_controls #(.CLK_HZ(1000000),.BAUD(62500),.IR_ENABLED(1)) dut(
  .clk(clk),.rst(rst),.rx(1'b1),.ir_rx(ir),.tx(tx),.overflow(overflow),
  .next_pulse(np),.prev_pulse(pp),.toggle_pulse(tp),.time_bcd(),.time_seq(),.time_set(),
  .vol_up(vu),.vol_dn(vd),.mute_toggle(mt),.bri_up(bu),.bri_dn(bd),.con_up(cu),.con_dn(cd),
  .osd_toggle(osd),.test_toggle(pat),.transition_toggle(tr),.transition_mode(tm),
  .auto_enh_en(enh),.slide_enable(album),.zh_enable(zh),.large_clock(clock_big),
  .captions_enable(cap),.scroll_enable(scroll),.slogan_select(sl));
 always @(posedge clk)if(!rst)begin
  if(np)n=n+1;if(pp)p=p+1;if(tp)b=b+1;
  if(vu)vc_up=vc_up+1;if(vd)vc_dn=vc_dn+1;if(mt)mc=mc+1;
  if(bu)bc_up=bc_up+1;if(bd)bc_dn=bc_dn+1;if(cu)cc_up=cc_up+1;if(cd)cc_dn=cc_dn+1;
  if(osd)oc=oc+1;if(pat)pc=pc+1;if(tr)tc=tc+1;
 end
 task level;input value;input integer duration;begin
  @(negedge clk);ir=value;repeat(duration)@(negedge clk);
 end endtask
 task byte;input [7:0]data;integer k;begin
  for(k=0;k<8;k=k+1)begin level(0,560);level(1,data[k]?1690:560);end
 end endtask
 task packet;input [7:0]command,complement;begin
  level(0,9000);level(1,4500);byte(0);byte(255);byte(command);byte(complement);
  level(0,560);level(1,100);
 end endtask
 task check;input ok;input [511:0]msg;begin
  if(ok!==1)begin errors=errors+1;$display("FAILED %s",msg);end
 end endtask
 initial begin
  repeat(5)@(negedge clk);rst=0;repeat(10)@(negedge clk);
  packet(8'h09,8'hf6);check(n==1 && p==0 && b==0,"NEC09 right: next through real decoder");
  packet(8'h07,8'hf8);check(n==1 && p==1 && b==0,"NEC07 left: previous without b/p reversal");
  packet(8'h15,8'hea);check(n==1 && p==1 && b==1,"NEC15 gear: toggles autoplay");
  level(0,9000);level(1,2250);level(0,560);level(1,100);
  check(b==1,"hold repeat cannot toggle autoplay repeatedly");
  packet(8'h09,8'h00);check(n==1,"invalid complement rejected");
  packet(8'h43,8'hbc);check(n==1 && p==1 && b==1 && mc==1,"NEC43 E: mute toggle pulse");
  packet(8'h40,8'hbf);check(vc_up==1,"NEC40 up: volume up pulse");
  packet(8'h19,8'he6);check(vc_dn==1,"NEC19 down: volume down pulse");
  packet(8'h5e,8'ha1);check(oc==1,"NEC5E 3: OSD pulse");
  packet(8'h45,8'hba);check(bc_up==1,"NEC45 A: brightness up pulse");
  packet(8'h46,8'hb9);check(bc_dn==1,"NEC46 B: brightness down pulse");
  packet(8'h47,8'hb8);check(cc_up==1,"NEC47 C: contrast up pulse");
  packet(8'h44,8'hbb);check(cc_dn==1,"NEC44 D: contrast down pulse");
  packet(8'h0d,8'hf2);check(enh,"NEC0D F: auto-level toggle");
  packet(8'h16,8'he9);check(album,"NEC16 0: 5-second album toggle");
  packet(8'h0c,8'hf3);check(zh,"NEC0C 1: Chinese overlay toggle");
  packet(8'h18,8'he7);check(clock_big,"NEC18 2: clock-size toggle");
  packet(8'h1c,8'he3);check(pc==1,"NEC1C 5: test-pattern pulse");
  packet(8'h08,8'hf7);check(tc==1 && tm==2,"NEC08 4: transition cycle");
  check(tx && !overflow,"IR does not generate UART replies");
  rst=1;repeat(4)@(negedge clk);rst=0;packet(8'h09,8'hf6);
  check(n==2 && p==1 && b==1,"decode recovers after reset");
  if(errors==0)$display("ALL PASS tb_remote_ir: real NEC pins, mapped next/previous/toggle, bad CRC complement, ignored hold repeats, reset, no UART replies");
  else $display("FAILED tb_remote_ir %d",errors);
  $finish;
 end
 initial begin #30000000;$display("FAILED watchdog tb_remote_ir");$finish;end
endmodule
