// Unthrottled raster: HDMI sink must sustain active pixel rate.
module video_rgb_to_axis_640x480(input I_clk,input I_rst,input I_vs,input I_de,
    input [23:0] I_rgb,output reg O_video_user,output reg O_video_valid,
    output reg O_video_last,output reg [23:0] O_video_data);
    reg vs_d,frame_arm;
    reg [9:0] x;
    always @(posedge I_clk or posedge I_rst) begin
        if(I_rst) begin
            vs_d<=1;frame_arm<=1;x<=0;
            O_video_user<=0;O_video_valid<=0;O_video_last<=0;O_video_data<=0;
        end else begin
            vs_d<=I_vs;O_video_valid<=I_de;O_video_data<=I_rgb;
            O_video_user<=0;O_video_last<=0;
            if(vs_d!=I_vs) frame_arm<=1;
            if(I_de) begin
                O_video_user<=frame_arm;frame_arm<=0;O_video_last<=(x==639);
                x <= (x==639) ? 10'd0 : x+1'b1;
            end else x<=0;
        end
    end
endmodule
