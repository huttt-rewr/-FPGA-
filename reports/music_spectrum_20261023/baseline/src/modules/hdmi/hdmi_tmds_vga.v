// VGA 640x480, 800x525 total, negative HS/VS, 25 MHz (~59.524 Hz).
// DVI-compatible video only: no HDMI audio packets or data islands.
// All overlays enter together through the final vs/de/rgb pixel bundle.
module hdmi_tmds_vga(
    input clk, input rst, input vs, input de, input [23:0] rgb,
    output [9:0] ch0, output [9:0] ch1, output [9:0] ch2,
    output [9:0] clk_ch
);
    reg vs_d,locked;
    reg [9:0] h,v;
    wire frame_start=vs_d && !vs;
    wire [9:0] h_now=frame_start?10'd0:h;
    wire [9:0] v_now=frame_start?10'd0:v;
    wire hs=(h_now>=96);
    wire de_int=(h_now>=144 && h_now<784 && v_now>=35 && v_now<515);
    // Input DE is authoritative: it has precisely the same pipeline delay as
    // RGB. de_int is retained as the explicit raster alignment check in sim.
    wire pixel_de=locked && de;
    always @(posedge clk or posedge rst) begin
        if(rst) begin vs_d<=1;locked<=0;h<=0;v<=0;end
        else begin
            vs_d<=vs;
            if(frame_start) begin
                // This edge CONSUMES pixel (0,0); next edge consumes (1,0).
                // Loading zero here would make recovered HS one pixel late.
                h<=1;v<=0;locked<=1;
            end else if(locked) begin
                if(h==799) begin h<=0;v<=(v==524)?10'd0:v+1'b1;end
                else h<=h+1'b1;
            end
        end
    end
    // Internal HS/VS are active-low; DVI control is active-high, so invert.
    tmds_encoder blue (.clk(clk),.rst(rst),.de(pixel_de),.control({!vs,!hs}),.data(rgb[7:0]),.symbol(ch0));
    tmds_encoder green(.clk(clk),.rst(rst),.de(pixel_de),.control(2'b00),.data(rgb[15:8]),.symbol(ch1));
    tmds_encoder red  (.clk(clk),.rst(rst),.de(pixel_de),.control(2'b00),.data(rgb[23:16]),.symbol(ch2));
    // Five ones, five zeros. Binary 0000011111 is 0x01f, NOT 0x03f.
    assign clk_ch=10'b0000011111;
endmodule

// Cut the compositor/font path before either VGA TMDS or the SVGA AXIS input.
// All three signals advance together; no raster or image dimensions change.
module hdmi_video_stage(
    input clk,input rst,input vs,input de,input [23:0] rgb,
    output reg out_vs,output reg out_de,output reg [23:0] out_rgb
);
    always @(posedge clk or posedge rst)begin
        if(rst)begin out_vs<=1;out_de<=0;out_rgb<=0;end
        else begin out_vs<=vs;out_de<=de;out_rgb<=rgb;end
    end
endmodule
