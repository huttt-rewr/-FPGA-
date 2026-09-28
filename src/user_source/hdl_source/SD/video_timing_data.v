module video_timing_data(input video_clk,input rst,output reg read_req,
    input read_req_ack,output hs,output vs,output de,output vblank);
    reg vs_d;
    reg [7:0] blank_delay;
    (* async_reg="true" *) reg [2:0] ack_ff;
    assign vblank=vs_d && !vs;
    color_bar timing(.clk(video_clk),.rst(rst),.hs(hs),.vs(vs),.de(de),
        .rgb_r(),.rgb_g(),.rgb_b());
    always @(posedge video_clk or posedge rst) begin
        if(rst) begin vs_d<=1;blank_delay<=0;read_req<=0;ack_ff<=0;end
        else begin
            vs_d<=vs;ack_ff<={ack_ff[1:0],read_req_ack};
            blank_delay<={blank_delay[6:0],vblank};
            if(blank_delay[7]) read_req<=1;
            else if(ack_ff[2]) read_req<=0;
        end
    end
endmodule
