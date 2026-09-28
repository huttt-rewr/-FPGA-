// BT.601 limited-range 8-bit YCbCr, one stage; chroma upsampling separate.
module ycbcr_to_rgb(input clk,input rst,input valid,
    input [7:0] y,input [7:0] cb,input [7:0] cr,
    output reg out_valid,output reg [23:0] rgb);
    wire signed [17:0] c=$signed({1'b0,y})-18'sd16;
    wire signed [17:0] d=$signed({1'b0,cb})-18'sd128;
    wire signed [17:0] e=$signed({1'b0,cr})-18'sd128;
    wire signed [19:0] rr=(298*c+409*e+128)>>>8;
    wire signed [19:0] gg=(298*c-100*d-208*e+128)>>>8;
    wire signed [19:0] bb=(298*c+516*d+128)>>>8;
    function [7:0] clip;
        input signed [19:0] v;
        begin clip=v<0?0:(v>255?255:v[7:0]);end
    endfunction
    always @(posedge clk or posedge rst)
        if(rst) begin out_valid<=0;rgb<=0;end
        else begin out_valid<=valid;rgb<={clip(rr),clip(gg),clip(bb)};end
endmodule
