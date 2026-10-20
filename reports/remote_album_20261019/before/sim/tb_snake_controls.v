`timescale 1ns/1ps
module tb_snake_controls;
 reg src_clk=0,clk=0,rst=1,valid=0,release_key=0,extended=0,rx_error=0,vs=1;
 reg [7:0] code=0;
 wire enabled,u,d,l,r,n,p,vu,vd,on,tick;
 wire [4:0] controls;wire [1:0] dir;
 integer errors=0,events=0,ticks=0,i;
 always #5 src_clk=~src_clk;always #13 clk=~clk;
 ps2_controls decoder(.clk(src_clk),.rst(rst),.scan_code(code),.key_valid(valid),
  .key_release(release_key),.key_extended(extended),.receive_error(rx_error),
  .game_enable(enabled),.held_up(u),.held_down(d),.held_left(l),.held_right(r),
  .ev_next(n),.ev_prev(p),.ev_vol_up(vu),.ev_vol_dn(vd));
 cdc_snapshot #(.WIDTH(5)) cdc(.src_clk(src_clk),.src_rst(rst),.src_data({enabled,u,d,l,r}),
  .dst_clk(clk),.dst_rst(rst),.dst_data(controls));
 snake_frame_control cadence(.clk(clk),.rst(rst),.vs(vs),.controls(controls),.game_on(on),.dir_req(dir),.tick(tick));
 always @(posedge src_clk)if(n||p||vu||vd)events=events+1;
 always @(posedge clk)if(tick)begin ticks=ticks+1;if(vs)begin errors=errors+1;$display("FAIL tick outside vertical blank");end end
 task check;input ok;input [511:0] msg;begin
  if(ok!==1)begin errors=errors+1;$display("FAIL snake controls %0s",msg);end
 end endtask
 task key;input [7:0] c;input ex,br;begin
  @(negedge src_clk);code=c;extended=ex;release_key=br;valid=1;
  @(negedge src_clk);valid=0;repeat(5)@(negedge src_clk);
 end endtask
 task settle;begin repeat(60)@(negedge clk);end endtask
 task frame;begin
  @(negedge clk);vs=0;repeat(4)@(negedge clk);vs=1;repeat(8)@(negedge clk);
 end endtask
 initial begin
  repeat(5)@(negedge clk);rst=0;
  key(8'h74,1,0);check(r,"held right make");key(8'h74,1,1);check(!r && events==1,"normal media arrow unchanged");
  repeat(3)key(8'h34,0,0);settle;check(enabled && !on,"G typematic toggles once, frame waits");
  frame;check(on && ticks==0,"enable at frame edge");key(8'h34,0,1);
  key(8'h75,1,0);settle;check(u && dir==0,"up held crosses domains");
  key(8'h72,1,0);key(8'h6b,1,0);key(8'h74,1,0);settle;check(dir==0,"up priority");
  key(8'h75,1,1);settle;check(dir==2,"down priority");
  key(8'h72,1,1);settle;check(dir==3,"left priority");
  key(8'h6b,1,1);settle;check(dir==1,"right held");
  key(8'h74,1,1);settle;check(dir==1,"direction persists on release");
  check(events==1,"game arrows do not switch images or change volume");
  for(i=0;i<5;i=i+1)frame;check(ticks==0,"no early tick");
  frame;check(ticks==1,"six frames per movement");
  repeat(6)frame;check(ticks==2,"periodic frame cadence");
  key(8'h75,1,0);@(negedge src_clk);rx_error=1;@(negedge src_clk);rx_error=0;settle;
  check(!u && enabled,"receive error clears held state without exiting game");
  key(8'h34,0,0);key(8'h34,0,1);settle;check(!enabled && on,"exit waits for frame boundary");
  frame;check(!on && dir==1,"exit resets cadence/direction");
  key(8'h72,1,0);key(8'h72,1,1);check(events==2,"media arrows restored on exit");
  if(errors==0)$display("ALL PASS tb_snake_controls: G make/break, held arrows, CDC, priority, six-frame tick, media isolation");
  else $display("FAILED tb_snake_controls errors=%0d",errors);
  $finish;
 end
 initial begin #1000000;$display("FAILED snake controls watchdog");$finish;end
endmodule
