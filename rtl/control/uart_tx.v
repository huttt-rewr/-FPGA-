module uart_tx #(parameter CLK_FREQ=100000000,parameter BAUD=115200)(
 input clk,input rst,input [7:0] i_data,input i_send,output reg o_tx,output reg o_busy);
 localparam DIV=CLK_FREQ/BAUD;
 reg [15:0] count;reg [3:0] bit_idx;reg [9:0] shift;
 always @(posedge clk or posedge rst) begin
  if(rst) begin count<=0;bit_idx<=0;shift<=1023;o_tx<=1;o_busy<=0;end
  else if(!o_busy) begin
   o_tx<=1;
   if(i_send) begin shift<={1'b1,i_data,1'b0};o_tx<=0;o_busy<=1;count<=0;bit_idx<=0;end
  end else if(count==DIV-1) begin
   count<=0;
   if(bit_idx==9) begin o_busy<=0;o_tx<=1;end
   else begin bit_idx<=bit_idx+1'b1;shift<={1'b1,shift[9:1]};o_tx<=shift[1];end
  end else count<=count+1'b1;
 end
endmodule
