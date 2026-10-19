// Two fixed pipeline stages. Every input pixel is consumed, including covered pixels.
// Right translation: output(x)=input(x-offset) when x>=offset, black otherwise.
// This only reads pixels already written in THIS row; offset=0 bypasses RAM collision.
// One 1024x24 simple dual-port synchronous line store; never reset its contents.
module transition_pixels(input clk,input rst,input vs,input de,
    input [9:0] x,input [23:0] rgb,input [1:0] effect_mode,
    input [5:0] fade_level,input [9:0] slide_offset,
    output reg out_vs,output reg out_de,output reg [23:0] out_rgb);
    reg [23:0] line_mem [0:1023];
    reg [23:0] line_q,direct_q;
    wire [9:0] read_addr=x-slide_offset;
    // Separate unreset synchronous RAM process permits block RAM inference.
    always @(posedge clk) begin
        if(de) line_mem[x]<=rgb;
        line_q<=line_mem[read_addr];
    end
    reg vs_q,de_q,shift_q,covered_q;
    reg [5:0] level_q;
    wire [23:0] shifted_rgb=covered_q?24'd0:(shift_q?line_q:direct_q);
    wire [13:0] r_product=shifted_rgb[23:16]*level_q;
    wire [13:0] g_product=shifted_rgb[15:8]*level_q;
    wire [13:0] b_product=shifted_rgb[7:0]*level_q;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            direct_q<=0;vs_q<=0;de_q<=0;shift_q<=0;covered_q<=0;level_q<=32;
            out_vs<=0;out_de<=0;out_rgb<=0;
        end else begin
            vs_q<=vs;de_q<=de;direct_q<=rgb;
            shift_q<=(effect_mode==2 && slide_offset!=0);
            covered_q<=(effect_mode==2 && x<slide_offset);
            level_q<=(effect_mode==1)?fade_level:6'd32;
            out_vs<=vs_q;out_de<=de_q;
            out_rgb<=de_q?{r_product[12:5],g_product[12:5],b_product[12:5]}:24'd0;
        end
    end
endmodule
