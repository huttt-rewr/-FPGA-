`timescale 1ns/1ps
module tb_audio_fifo;
 reg wc=0,rc=0,rst=1,we=0,re=0;always #5 wc=~wc;always #13 rc=~rc;
 reg [23:0] wd=0;wire [23:0] rd;wire full,empty;wire [10:0] wu,ru;
 integer writes=0,reads=0,errors=0,k;reg [23:0] queue[0:20000];reg [23:0] want;
 audio_async_fifo dut(.wr_clk(wc),.rd_clk(rc),.rst(rst),.wr_en(we),.wr_data(wd),.full(full),.rd_en(re),.rd_data(rd),.empty(empty),.wr_used(wu),.rd_used(ru));
 always @(negedge wc)wd=writes*7919;
 always @(posedge wc)if(!rst && we && !full)begin queue[writes]=wd;writes=writes+1;end
 always @(posedge rc)if(!rst && re && !empty)begin want=queue[reads];reads=reads+1;#1;if(rd!==want)begin errors=errors+1;$display("FAILED FIFO order %0d got %h expected %h",reads,rd,want);end end
 task check;input ok;input [511:0] msg;begin if(ok!==1)begin errors=errors+1;$display("FAILED FIFO %0s",msg);end end endtask
 initial begin
  repeat(8)@(negedge wc);rst=0;repeat(8)@(negedge wc);check(empty,"reset empty");we=1;
  repeat(1100)@(negedge wc);check(full && wu==1024 && writes==1024,"exact full / overflow prevented");we=0;re=1;
  wait(reads==1024);repeat(8)@(negedge rc);check(empty,"exact drain / underflow prevented");re=0;
  for(k=0;k<5000;k=k+1)begin @(negedge wc);we=($random&3)!=0;re=($random&3)!=0;end
  we=0;re=1;wait(reads==writes);repeat(8)@(negedge rc);check(empty,"random wrap drain");
  re=0;we=1;repeat(50)@(negedge wc);rst=1;we=0;re=0;repeat(8)@(negedge wc);writes=0;reads=0;rst=0;repeat(8)@(negedge wc);check(empty && wu==0,"reset discards queue");
  we=1;repeat(200)@(negedge wc);we=0;re=1;wait(reads==writes);repeat(8)@(negedge rc);
  if(errors==0)$display("ALL PASS tb_audio_fifo");else $display("FAILED FIFO %0d",errors);$finish;
 end
 initial begin #3000000;$display("FAILED FIFO watchdog");$finish;end
endmodule
