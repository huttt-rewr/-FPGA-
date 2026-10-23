// Optional independent album cadence. A registered terminal keeps the wide
// comparator away from the 100MHz counter-reset/output path. Busy saturates.
module slideshow_timer #(parameter PERIOD=500000000)(
 input clk,rst,enable,input busy,output reg next_pulse);
 localparam CW=(PERIOD<2)?1:$clog2(PERIOD);
 reg [CW-1:0] count;
 reg due;
 always @(posedge clk or posedge rst)begin
  if(rst)begin count<=0;due<=0;next_pulse<=0;end
  else begin
   next_pulse<=0;
   if(!enable)begin count<=0;due<=0;end
   else if(due || PERIOD<=1)begin
    if(!busy)begin count<=0;due<=0;next_pulse<=1;end
   end else begin
    count<=count+1'b1;
    if(count==PERIOD-2)due<=1;
   end
  end
 end
endmodule
