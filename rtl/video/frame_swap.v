// Source holds buffer until ack matches request. vblank precedes next read request.
module frame_swap(input clk,input rst,input vblank,input request_toggle,
    input [1:0] requested_buffer,output reg ack_toggle,
    output reg [1:0] active_buffer,output reg display_valid);
    (* async_reg="true" *) reg [2:0] req_ff;
    reg [1:0] buf_ff1,buf_ff2;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            req_ff<=0;buf_ff1<=0;buf_ff2<=0;
            ack_toggle<=0;active_buffer<=0;display_valid<=0;
        end else begin
            req_ff<={req_ff[1:0],request_toggle};
            buf_ff1<=requested_buffer;buf_ff2<=buf_ff1;
            if(vblank && req_ff[2]!=ack_toggle) begin
                active_buffer<=buf_ff2;display_valid<=1;ack_toggle<=req_ff[2];
            end
        end
    end
endmodule
