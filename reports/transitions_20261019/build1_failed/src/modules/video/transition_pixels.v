// Two fixed pipeline stages. Every input pixel is consumed, including covered pixels.
// Right translation: output(x)=input(x-offset) when x>=offset, black otherwise.
// This only reads pixels already written in THIS row; offset=0 bypasses RAM collision.
// One 1024x24 simple dual-port synchronous line store; never reset its contents.
module transition_pixels(input clk,input rst,input vs,input de,
    input [9:0] x,input [23:0] rgb,input [2:0] effect_mode,
    input [5:0] fade_level,input [9:0] slide_offset,
    output reg out_vs,output reg out_de,output reg [23:0] out_rgb,
    input [9:0] y,input mode_800);
    reg [23:0] line_mem [0:1023];
    reg [23:0] line_q,direct_q;
    wire [9:0] read_addr=x-slide_offset;
    // Separate unreset synchronous RAM process permits block RAM inference.
    always @(posedge clk) begin
        if(de) line_mem[x]<=rgb;
        line_q<=line_mem[read_addr];
    end
    // All geometry stays in video_clk. No extra line stores or SDRAM reads.
    // 0 bypass, 1 fade, 2 translated slide, 3 wipe, 4 circular iris, 5 checker.
    wire [9:0] cx=mode_800?10'd400:10'd320;
    wire [9:0] cy=mode_800?10'd300:10'd240;
    wire [9:0] dx=(x>=cx)?x-cx:cx-x;
    wire [9:0] dy=(y>=cy)?y-cy:cy-y;
    wire [19:0] dx_square=dx*dx,dy_square=dy*dy;
    wire [20:0] distance_square={1'b0,dx_square}+{1'b0,dy_square};
    wire iris_cover=(fade_level==0) ||
                    ((fade_level<32) && distance_square>{3'd0,radius_square(fade_level,mode_800)});
    // A checker appears halfway through; each 32-pixel tile fills monotonically.
    // Changing only checker frequency would leave half the frame exposed at handoff.
    wire [5:0] progress=6'd32-fade_level;
    wire odd_tile=x[5]^y[5];
    wire [5:0] tile_threshold={1'b0,progress[3:0],1'b0};
    wire tile_strip=({1'b0,x[4:0]}<tile_threshold);
    wire checker_cover=(fade_level==0) ||
                       (odd_tile ? (progress>=16 && tile_strip) : (progress>=16 || tile_strip));
    reg cover;
    always @* begin
        case(effect_mode)
            3'd2,3'd3: cover=(x<slide_offset);
            3'd4: cover=iris_cover;
            3'd5: cover=checker_cover;
            default: cover=0;
        endcase
    end
    function [17:0] radius_square;
        input [5:0] level;
        input svga;
        begin
            case(level)
                6'd0: radius_square=svga?18'd0:18'd0;
                6'd1: radius_square=svga?18'd225:18'd144;
                6'd2: radius_square=svga?18'd961:18'd625;
                6'd3: radius_square=svga?18'd2116:18'd1369;
                6'd4: radius_square=svga?18'd3844:18'd2500;
                6'd5: radius_square=svga?18'd6084:18'd3844;
                6'd6: radius_square=svga?18'd8649:18'd5625;
                6'd7: radius_square=svga?18'd11881:18'd7569;
                6'd8: radius_square=svga?18'd15625:18'd10000;
                6'd9: radius_square=svga?18'd19600:18'd12544;
                6'd10: radius_square=svga?18'd24336:18'd15625;
                6'd11: radius_square=svga?18'd29241:18'd18769;
                6'd12: radius_square=svga?18'd34969:18'd22500;
                6'd13: radius_square=svga?18'd41209:18'd26244;
                6'd14: radius_square=svga?18'd47524:18'd30625;
                6'd15: radius_square=svga?18'd54756:18'd34969;
                6'd16: radius_square=svga?18'd62500:18'd40000;
                6'd17: radius_square=svga?18'd70225:18'd44944;
                6'd18: radius_square=svga?18'd78961:18'd50625;
                6'd19: radius_square=svga?18'd87616:18'd56169;
                6'd20: radius_square=svga?18'd97344:18'd62500;
                6'd21: radius_square=svga?18'd107584:18'd68644;
                6'd22: radius_square=svga?18'd117649:18'd75625;
                6'd23: radius_square=svga?18'd128881:18'd82369;
                6'd24: radius_square=svga?18'd140625:18'd90000;
                6'd25: radius_square=svga?18'd152100:18'd97344;
                6'd26: radius_square=svga?18'd164836:18'd105625;
                6'd27: radius_square=svga?18'd177241:18'd113569;
                6'd28: radius_square=svga?18'd190969:18'd122500;
                6'd29: radius_square=svga?18'd205209:18'd131044;
                6'd30: radius_square=svga?18'd219024:18'd140625;
                6'd31: radius_square=svga?18'd234256:18'd149769;
                6'd32: radius_square=svga?18'd250000:18'd160000;
                default: radius_square=0;
            endcase
        end
    endfunction
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
            covered_q<=cover;
            level_q<=(effect_mode==1)?fade_level:6'd32;
            out_vs<=vs_q;out_de<=de_q;
            out_rgb<=de_q?{r_product[12:5],g_product[12:5],b_product[12:5]}:24'd0;
        end
    end
endmodule
