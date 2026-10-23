// Bounded reply queue; overflow is sticky and appears in the OSD error status.
module uart_tx_queue #(parameter CLK_FREQ=100000000, BAUD=115200)(
 input clk,input rst,input [7:0] i_data,input i_send,
 output o_tx,output o_busy,output reg overflow);
 reg [7:0] queue [0:15];
 reg [3:0] wr_ptr,rd_ptr;
 reg [4:0] count;
 wire tx_busy;
 wire pop=(count!=0) && !tx_busy;
 wire push=i_send && ((count<16) || pop);
 assign o_busy=tx_busy || (count!=0);
 uart_tx #(.CLK_FREQ(CLK_FREQ),.BAUD(BAUD)) tx(
  .clk(clk),.rst(rst),.i_data(queue[rd_ptr]),.i_send(pop),.o_tx(o_tx),.o_busy(tx_busy));
 always @(posedge clk or posedge rst) begin
  if(rst) begin wr_ptr<=0;rd_ptr<=0;count<=0;overflow<=0;end
  else begin
   if(push) begin queue[wr_ptr]<=i_data;wr_ptr<=wr_ptr+1'b1;end
   if(pop) rd_ptr<=rd_ptr+1'b1;
   case({push,pop})
    2'b10:count<=count+1'b1;
    2'b01:count<=count-1'b1;
    default:;
   endcase
   if(i_send && !push) overflow<=1;
  end
 end
endmodule
