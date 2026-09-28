module video_enhance(input [23:0] rgb,input signed [7:0] brightness,output [23:0] result);
    function [7:0] adjust;
        input [7:0] c;input signed [7:0] b;
        reg signed [9:0] sum;
        begin
            sum=$signed({2'b00,c})+$signed({{2{b[7]}},b});
            adjust=(sum<0)?8'd0:((sum>255)?8'd255:sum[7:0]);
        end
    endfunction
    assign result={adjust(rgb[23:16],brightness),adjust(rgb[15:8],brightness),adjust(rgb[7:0],brightness)};
endmodule
