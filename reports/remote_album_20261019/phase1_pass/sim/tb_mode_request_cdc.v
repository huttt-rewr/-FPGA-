`timescale 1ns/1ps
// Real two-bit bundled-data CDC followed by the runtime mode controller.
module tb_mode_request_cdc;
 reg sd=0,boot=0,rst=1,edid_done=0,supports=1;
 always #5 sd=~sd;
 always #20 boot=~boot;
 reg [1:0] request=1;
 wire [1:0] received,active;
 wire ready,mode_800,fallback;
 integer errors=0;
 cdc_snapshot #(.WIDTH(2)) transfer(.src_clk(sd),.src_rst(rst),.src_data(request),
  .dst_clk(boot),.dst_rst(rst),.dst_data(received));
 video_mode_control #(.QUIET_CYCLES(4),.SETTLE_CYCLES(16)) control(
  .clk(boot),.rst(rst),.edid_done(edid_done),.supports_800(supports),
  .requested_mode(received),.ready(ready),.mode_800(mode_800),
  .active_mode(active),.fallback(fallback));
 task check;
  input ok;input [511:0] message;
  begin if(ok!==1)begin errors=errors+1;$display("FAILED CDC mode %0s",message);end end
 endtask
 task apply;
  input [1:0] value;input [1:0] expected;input expected_clock;
  begin
   @(negedge sd);request=value;
   wait(received===value);
   wait(ready && active===expected);
   repeat(4)@(negedge boot);
   check(received===value,"all two request bits survive CDC");
   check(active===expected && mode_800===expected_clock,"requested mode applied");
   $display("request=%b received=%b active=%b mode_800=%b",request,received,active,mode_800);
  end
 endtask
 initial begin
  repeat(5)@(negedge boot);rst=0;
  repeat(12)@(negedge boot);check(!ready,"EDID gates mode activation");edid_done=1;
  wait(ready && active==1);
  apply(2,2,1);apply(0,0,0);apply(1,1,0);apply(2,2,1);
  apply(1,1,0);supports=0;apply(2,2,0);check(fallback,"unsupported SVGA fallback");
  apply(3,1,0); // illegal two-bit code is normalized by the existing controller
  @(negedge sd);request=0;wait(received==0);
  @(negedge sd);request=2;supports=1;
  wait(received==2 && active==2 && ready);check(mode_800,"pending request during reset/settle wins");
  rst=1;repeat(4)@(negedge boot);request=2;rst=0;
  wait(received==2 && active==2 && ready);check(mode_800,"bit1 survives reset and restart");
  if(errors==0)$display("ALL PASS tb_mode_request_cdc: two-bit modes 0/1/2/3, EDID fallback, pending request and reset");
  else $display("FAILED CDC mode errors=%0d",errors);
  $finish;
 end
 initial begin #100000;$display("FAILED CDC mode watchdog");$finish;end
endmodule
