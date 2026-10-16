// Registered admission reserves four slots for the ready/sample/write pipeline.
// Full remains the FIFO's final physical write guard. Occupancy is conservative:
// the remote read pointer has already traversed the FIFO's Gray synchronizers.
module audio_fifo_room #(parameter integer ADDRESS_BITS=10)(
 input clk,rst,full,input [ADDRESS_BITS:0] used,output reg sample_ready);
 localparam integer CAPACITY=1<<ADDRESS_BITS;
 always @(posedge clk or posedge rst)begin
  if(rst)sample_ready<=0;
  else sample_ready<=!full && used<=CAPACITY-4;
 end
endmodule
