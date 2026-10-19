`timescale 1ns/1ps
module tb_sd_audio_arbiter;
 reg clk=0,rst=1,ready=1,br=1,ar=1,sv=0,se=0,serr=0;always #5 clk=~clk;
 reg [31:0] ba=12,aa=34;reg [7:0] data=8'h5a;
 wire bv,be,ber,bg,av,ae,aer,sr,tr;wire [31:0] sa;wire [7:0] bd,ad;integer errors=0,k;
 sd_read_arbiter #(.TIMEOUT_CYCLES(20)) dut(.clk(clk),.rst(rst),.sd_ready(ready),.bmp_req(br),.bmp_addr(ba),.bmp_data(bd),.bmp_valid(bv),.bmp_end(be),.bmp_error(ber),.bmp_grant(bg),.aud_req(ar),.aud_addr(aa),.aud_data(ad),.aud_valid(av),.aud_end(ae),.aud_error(aer),.sd_req(sr),.sd_addr(sa),.sd_data(data),.sd_valid(sv),.sd_end(se),.sd_error(serr),.transport_reset(tr));
 task check;input ok;input [511:0] msg;begin if(ok!==1)begin errors=errors+1;$display("FAILED arbiter %0s",msg);end end endtask
 task cycle;begin @(negedge clk);end endtask
 initial begin
  repeat(3)cycle;rst=0;cycle;check(sr && sa==34 && !bg,"audio priority");aa=99;ba=98;sv=1;#1;check(av && !bv && ad==data,"routing isolated");repeat(5)cycle;check(sa==34,"locked address");sv=0;se=1;#1;check(ae && !be,"end isolated");cycle;se=0;ar=0;check(!sr,"release gap");repeat(2)cycle;check(!sr,"two gap cycles");cycle;check(sr && sa==98 && bg,"BMP progresses");
  serr=1;#1;check(ber && !aer && !bv,"BMP error isolated");cycle;serr=0;br=0;repeat(3)cycle;ar=1;cycle;check(sr,"retry audio");
  for(k=0;k<25;k=k+1)begin cycle;if(tr)begin check(!sr,"timeout abort");ar=0;end end
  check(!sr,"timeout releases");br=1;cycle;repeat(3)cycle;check(bg,"BMP after timeout");ready=0;#1;check(ber && !aer,"card drop owner error");cycle;br=0;ready=1;repeat(5)cycle;
  if(errors==0)$display("ALL PASS tb_sd_audio_arbiter");else $display("FAILED arbiter %0d",errors);$finish;
 end
 initial begin #100000;$display("FAILED arbiter watchdog");$finish;end
endmodule
