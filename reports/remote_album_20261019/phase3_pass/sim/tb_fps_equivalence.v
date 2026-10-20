`timescale 1ns/1ps
module tb_fps_equivalence;
 wire [4:0] done;
 wire [31:0] e0,e1,e2,e3,e4;
 fps_equivalence_case #(1) c0(done[0],e0);
 fps_equivalence_case #(2) c1(done[1],e1);
 fps_equivalence_case #(17) c2(done[2],e2);
 fps_equivalence_case #(3000) c3(done[3],e3);
 fps_equivalence_case #(100000000) c4(done[4],e4);
 initial begin
  wait(&done);
  if((e0|e1|e2|e3|e4)==0)
   $display("ALL PASS tb_fps_equivalence: cycle-exact original reference, frequencies 1/2/17/3000/100M, deadlines, busy, mode bounce, reset and enable");
  else $display("FAILED fps equivalence errors=%0d",e0+e1+e2+e3+e4);
  $finish;
 end
 initial begin #3000000;$display("FAILED fps equivalence timeout");$finish;end
endmodule

module fps_equivalence_case #(parameter FREQ=3000)(output reg done=0,output reg [31:0] errors=0);
 reg clk=0,rst=1,enable=0,busy=0;
 reg [3:0] mode=0;
 always #5 clk=~clk;
 wire tick,limited,ref_tick,ref_limited;
 wire [5:0] fps,ref_fps;
 integer i,m,span,cycles=0;
 reg [31:0] rng=32'h29ab591d;
 fps_control #(.CLK_FREQ_HZ(FREQ)) dut(clk,rst,enable,busy,mode,tick,limited,fps);
 fps_control_reference #(.CLK_FREQ_HZ(FREQ)) reference(clk,rst,enable,busy,mode,ref_tick,ref_limited,ref_fps);
 always @(posedge clk)begin
  #1;
  if(!done)begin
   cycles=cycles+1;
   if({tick,limited,fps,dut.elapsed,dut.last_cycle}!==
      {ref_tick,ref_limited,ref_fps,reference.elapsed,reference.last_cycle})begin
    errors=errors+1;
    if(errors<8)$display("FAILED fps equivalence FREQ=%0d cycle=%0d mode=%0d",FREQ,cycles,mode);
   end
   if(!rst && dut.previous_mode==mode && dut.elapsed>dut.last_cycle)begin
    errors=errors+1;$display("FAILED fps no-overshoot invariant FREQ=%0d cycle=%0d",FREQ,cycles);
   end
  end
 end
 initial begin
  repeat(3)@(negedge clk);rst=0;enable=1;
  // Real terminal counts for small parameters, all valid and default modes.
  for(m=0;m<16;m=m+1)begin
   mode=m;busy=0;
   span=(FREQ<10000)?FREQ*2+5:100;
   repeat(span)@(negedge clk);
   busy=1;repeat(span)@(negedge clk);
   busy=0;repeat(3)@(negedge clk);
  end
  // Same-edge mode/enable/busy changes exercise the registered deadline.
  for(i=0;i<12000;i=i+1)begin
   @(negedge clk);
   rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
   if(rng[7:0]<12)mode=rng[11:8];
   if(rng[15:12]==0)enable=~enable;
   busy=rng[16];rst=(rng[23:16]==8'h37);
  end
  @(negedge clk);rst=1;repeat(3)@(negedge clk);done=1;
 end
endmodule

// The unmodified baseline reference is appended by prepare.py, with only
// its module name changed. Do not derive reference outputs from the DUT.

// Target slide cadence. Time spent loading/committing counts toward the target
// period; a late frame never queues another request while busy. Thus the real
// commit rate is bounded by measured pipeline service time, not a bandwidth guess.
module fps_control_reference #(parameter integer CLK_FREQ_HZ=100000000)(
 input clk,rst,enable,busy,input [3:0] mode,
 output reg tick,output reg limited,output [5:0] requested_fps);
 localparam CW=(CLK_FREQ_HZ<2)?1:$clog2(CLK_FREQ_HZ+1);
 reg [CW-1:0] elapsed;
 reg [3:0] previous_mode;
 reg [CW-1:0] period_cycles;
 reg [CW-1:0] last_cycle;
 reg [5:0] fps;
 assign requested_fps=fps;
 always @*begin
  case(mode)
   0:begin fps=1;period_cycles=CLK_FREQ_HZ;end
   1:begin fps=2;period_cycles=(CLK_FREQ_HZ+1)/2;end
   2:begin fps=5;period_cycles=(CLK_FREQ_HZ+4)/5;end
   3:begin fps=10;period_cycles=(CLK_FREQ_HZ+9)/10;end
   4:begin fps=15;period_cycles=(CLK_FREQ_HZ+14)/15;end
   5:begin fps=30;period_cycles=(CLK_FREQ_HZ+29)/30;end
   default:begin fps=1;period_cycles=CLK_FREQ_HZ;end
  endcase
 end
 always @(posedge clk or posedge rst)begin
  if(rst)begin elapsed<=0;previous_mode<=0;tick<=0;limited<=0;last_cycle<=CLK_FREQ_HZ-1;end
  else begin
   // A mode update clears elapsed below while this registered deadline
   // settles. Avoid a six-way period mux and subtract on the counter path.
   last_cycle<=period_cycles-1'b1;
   tick<=0;previous_mode<=mode;
   if(!enable || mode!=previous_mode)begin elapsed<=0;limited<=0;end
   else if(elapsed>=last_cycle)begin
    if(busy)limited<=1;
    else begin tick<=1;elapsed<=0;end
   end else elapsed<=elapsed+1'b1;
  end
 end
endmodule
