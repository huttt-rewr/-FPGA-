// Target slide cadence. Time spent loading/committing counts toward the target
// period; a late frame never queues another request while busy. Thus the real
// commit rate is bounded by measured pipeline service time, not a bandwidth guess.
module fps_control #(parameter integer CLK_FREQ_HZ=100000000)(
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
