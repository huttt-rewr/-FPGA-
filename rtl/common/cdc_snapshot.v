// Bundled-data handshake; held bus is stable until acknowledgement.
// Both domains must reset together.
module cdc_snapshot #(parameter WIDTH=8)(
    input src_clk,input src_rst,input [WIDTH-1:0] src_data,
    input dst_clk,input dst_rst,output reg [WIDTH-1:0] dst_data);
    reg [WIDTH-1:0] held;
    reg req,ack;
    (* async_reg="true" *) reg [2:0] ack_ff,req_ff;
    always @(posedge src_clk or posedge src_rst) begin
        if(src_rst) begin held<=0;req<=0;ack_ff<=0;end
        else begin
            ack_ff<={ack_ff[1:0],ack};
            if(ack_ff[2]==req) begin held<=src_data;req<=~req;end
        end
    end
    always @(posedge dst_clk or posedge dst_rst) begin
        if(dst_rst) begin dst_data<=0;ack<=0;req_ff<=0;end
        else begin
            req_ff<={req_ff[1:0],req};
            if(req_ff[2]!=ack) begin dst_data<=held;ack<=req_ff[2];end
        end
    end
endmodule
