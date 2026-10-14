`timescale 1ns/1ps
module tb_transition;
 reg clk=0,rst=1,vblank=0,req=0;always #5 clk=~clk;
 reg [1:0] requested=0,mode=1;
 wire ack,visible,busy;wire [1:0] active,effect;wire [5:0] level;wire [9:0] offset;
 integer errors=0,i;
 frame_swap #(.ENABLE_EFFECTS(1)) swap(.clk(clk),.rst(rst),.vblank(vblank),
  .request_toggle(req),.requested_buffer(requested),.ack_toggle(ack),
  .active_buffer(active),.display_valid(visible),.transition_mode(mode),
  .effect_mode(effect),.fade_level(level),.slide_offset(offset),.transition_busy(busy));
 task check;input ok;input [511:0] msg;begin
  if(!ok)begin errors=errors+1;$display("FAIL %0s",msg);end
 end endtask
 task frame;begin
  @(negedge clk);vblank=1;@(negedge clk);vblank=0;
  repeat(6)@(negedge clk);
 end endtask
 task change;input [1:0] b;begin
  @(negedge clk);requested=b;req=~req;repeat(7)@(negedge clk);
 end endtask
 reg prev_ack;reg [1:0] prev_active,prev_effect;reg [5:0] prev_level;reg [9:0] prev_offset;
 always @(posedge clk) begin
  if(!rst && !vblank)begin
   prev_ack=ack;prev_active=active;prev_effect=effect;prev_level=level;prev_offset=offset;
   #1;
   if({ack,active,effect,level,offset}!=={prev_ack,prev_active,prev_effect,prev_level,prev_offset})begin
    errors=errors+1;$display("FAIL state changed outside blank");end
  end
 end
 task animated_change;input [1:0] kind,target;reg old_ack;reg [1:0] old_active;begin
  mode=kind;old_ack=ack;old_active=active;change(target);
  repeat(12)@(negedge clk);
  check(ack==old_ack && active==old_active,"no early switch");
  frame;
  check(busy && effect==kind && level==31 && offset==20,"begin animation");
  // Mode changes during a transaction must not alter the captured transition.
  mode=0;
  for(i=30;i>=0;i=i-1)begin
   frame;check(level==i && offset==(32-i)*20 && effect==kind,"outbound progression");
   check(ack==old_ack && active==old_active,"old frame retained throughout outbound");
  end
  frame;
  check(active==target && level==0 && offset==640 && ack==old_ack,"switch while fully hidden, no premature ack");
  for(i=1;i<=32;i=i+1)begin
   frame;check(level==i && offset==(32-i)*20 && active==target,"inbound progression");
   if(i<32)check(ack==old_ack && busy && effect==kind,"buffers reserved through inbound");
  end
  check(ack==req && !busy && effect==0,"ack only after complete reveal");
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;
  change(1);check(!visible && !ack,"initial request waits for blank");frame;
  check(visible && ack && active==1 && !busy && level==32,"first frame immediate, no old frame fade");
  animated_change(1,0);animated_change(2,1);
  mode=0;change(0);frame;check(active==0 && ack==req && !busy,"cut mode");
  mode=2;change(1);frame;repeat(3)frame;
  @(negedge clk);rst=1;@(negedge clk);
  check(!visible && !busy && ack==0 && level==32 && offset==0,"reset interrupts animation safely");
  if(errors==0)$display("ALL PASS tb_transition: boundary-only state, full black handoff, held ownership, mode capture, reset");
  else $display("FAILED tb_transition %0d",errors);
  $finish;
 end
 initial begin #100000;$display("FAILED watchdog tb_transition");$finish;end
endmodule
