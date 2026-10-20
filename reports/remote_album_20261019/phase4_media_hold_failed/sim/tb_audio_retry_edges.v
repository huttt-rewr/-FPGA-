`timescale 1ns/1ps
module tb_audio_retry_edges;
 reg clk=0,rst=1;always #5 clk=~clk;
 wire [2:0] req,err;wire [3:0] c0,c1,c2;
 integer errors=0,n;
 // N=1, N=2 and a non-power-of-two exercise counter width/terminal timing.
 audio_wav #(.RETRY_CYCLES(1)) a(.clk(clk),.rst(rst),.sd_init_done(1'b1),.enable(1'b1),.sector_room(1'b1),.sample_ready(1'b1),.req(req[0]),.data(8'd0),.data_valid(1'b0),.sector_end(1'b0),.read_error(req[0]),.error(err[0]),.error_code(c0));
 audio_wav #(.RETRY_CYCLES(2)) b(.clk(clk),.rst(rst),.sd_init_done(1'b1),.enable(1'b1),.sector_room(1'b1),.sample_ready(1'b1),.req(req[1]),.data(8'd0),.data_valid(1'b0),.sector_end(1'b0),.read_error(req[1]),.error(err[1]),.error_code(c1));
 audio_wav #(.RETRY_CYCLES(13)) c(.clk(clk),.rst(rst),.sd_init_done(1'b1),.enable(1'b1),.sector_room(1'b1),.sample_ready(1'b1),.req(req[2]),.data(8'd0),.data_valid(1'b0),.sector_end(1'b0),.read_error(req[2]),.error(err[2]),.error_code(c2));
 task check;input ok;begin if(ok!==1)begin errors=errors+1;$display("FAILED retry edge n=%0d",n);end end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;
  wait(&err);#1;check(c0==2 && c1==2 && c2==2);
  for(n=1;n<=13;n=n+1)begin @(posedge clk);#1;
   if(n==1)check(!err[0]);
   if(n==2)check(!err[1]);
   check(err[2]==(n<13));
  end
  if(errors==0)$display("ALL PASS tb_audio_retry_edges");else $display("FAILED retry edges");
  $finish;
 end
 initial begin #10000;$display("FAILED retry edges watchdog");$finish;end
endmodule
