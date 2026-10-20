`timescale 1ns/1ps
`include "global_def.v"
// Exercise the verbatim PUBLIC refresh logic extracted by prepare_refresh_test.py.
// The encrypted command tail is not simulated; this is not an SDRAM PHY test.
module tb_sdram_refresh;
 reg clk=0,rst=1; wire done,req,refresh;
 integer cycles=0,last_request=0,requests=0,errors=0;
 always #12.5 clk=~clk;
 sdr_init_ref_public_test dut(.Sdr_clk(clk),.Rst(rst),.Sdr_init_req(1'b0),
  .Sdr_init_mode(4'b0010),.Sdr_init_done(done),.App_ref_req(1'b0),
  .Sdr_ref_req(req),.Sdr_ref_ack(req),.Sdr_rw_vld(1'b0),.Sdr_init_ref_vld(refresh),
  .Sdr_init_ref_addr(),.Sdr_init_ref_ba(),.Sdr_init_ref_we(),
  .Sdr_init_ref_cas(),.Sdr_init_ref_ras());
 always @(posedge clk) if(done) begin
  cycles=cycles+1;
  if(req)begin
   if(requests>0 && cycles-last_request!=1250) errors=errors+1;
   last_request=cycles;requests=requests+1;
  end
 end
 initial begin
  $display("SDR_CLK_PERIOD=%0d SELF_REFRESH_INTERVAL=%0d",`SDR_CLK_PERIOD,`SELF_REFRESH_INTERVAL);
  repeat(8)@(negedge clk);rst=0;
  wait(done);repeat(6000)@(negedge clk);
  if(`SDR_CLK_PERIOD!=25 || `SELF_REFRESH_INTERVAL!=1249 || requests<4) errors=errors+1;
  if(errors==0)$display("ALL PASS tb_sdram_refresh: public vendor refresh logic emits periodic requests, %0d requests",requests);
  else $display("FAILED tb_sdram_refresh: %0d errors, %0d requests",errors,requests);
  $finish;
 end
 initial begin #5000000;$display("FAILED watchdog tb_sdram_refresh");$finish;end
endmodule
