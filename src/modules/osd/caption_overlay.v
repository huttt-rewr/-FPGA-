// Pixel-domain layers: incoming picture -> half-transparent banner -> text/shadow.
// One output register, with VS/DE delayed identically. Controls/time latch in blank.
// Time is elapsed powered-on time, NOT wall clock. Text uses the existing ASCII font.
module caption_overlay #(parameter CLK_HZ=25000000,parameter ADAPTIVE=0)(
    input clk,input rst,input vs,input de,input [23:0] rgb,
    input enable,input scroll_enable,input [1:0] slogan_select,
    input [1:0] transition_mode,
    output reg out_vs,output reg out_de,output reg [23:0] out_rgb,input mode_800);
    wire [9:0] x,y;
    viewport_coordinates coords(clk,rst,vs,de,(ADAPTIVE && mode_800),x,y,,);
    reg vs_d,enabled,scrolling;
    reg [1:0] selected,selected_mode;
    wire frame_start=vs_d && !vs;
    reg [25:0] second_count;
    reg [3:0] sec_units,sec_tens,min_units,min_tens,hour_units,hour_tens;
    reg [23:0] displayed_time;
    reg [9:0] scroll_x;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            vs_d<=1;enabled<=0;scrolling<=1;selected<=0;selected_mode<=1;
            second_count<=0;sec_units<=0;sec_tens<=0;min_units<=0;min_tens<=0;
            hour_units<=0;hour_tens<=0;displayed_time<=0;scroll_x<=0;
        end else begin
            vs_d<=vs;
            if(second_count==((ADAPTIVE && mode_800)?40000000:CLK_HZ)-1) begin
                second_count<=0;
                if(sec_units!=9) sec_units<=sec_units+1'b1;
                else begin
                    sec_units<=0;
                    if(sec_tens!=5) sec_tens<=sec_tens+1'b1;
                    else begin
                        sec_tens<=0;
                        if(min_units!=9) min_units<=min_units+1'b1;
                        else begin
                            min_units<=0;
                            if(min_tens!=5) min_tens<=min_tens+1'b1;
                            else begin
                                min_tens<=0;
                                if(hour_units!=9) hour_units<=hour_units+1'b1;
                                else begin
                                    hour_units<=0;
                                    hour_tens<=(hour_tens==9)?0:hour_tens+1'b1;
                                end
                            end
                        end
                    end
                end
            end else second_count<=second_count+1'b1;
            if(frame_start) begin
                enabled<=enable;scrolling<=scroll_enable;
                selected<=slogan_select;selected_mode<=transition_mode;
                displayed_time<={hour_tens,hour_units,min_tens,min_units,sec_tens,sec_units};
                if(selected!=slogan_select) scroll_x<=0;
                else if(enable && scroll_enable) scroll_x<=(scroll_x==639)?0:scroll_x+1'b1;
            end
        end
    end
    // 40 character cells * 16 pixels = 640; circular pixel motion, no character jumps.
    reg [319:0] slogan;
    always @* begin
        case(selected)
            1:slogan="     LEARN FPGA - BUILD YOUR IDEAS!      ";
            2:slogan="     ENJOY EVERY PICTURE AND MOMENT      ";
            default:slogan="     WELCOME TO THE FPGA PHOTO SHOW      ";
        endcase
    end
    wire [10:0] scroll_sum={1'b0,x}+{1'b0,scroll_x};
    wire [9:0] text_x=(scroll_sum>=640)?scroll_sum-11'd640:scroll_sum[9:0];
    wire in_banner=(y>=432 && y<472);
    wire in_clock=(x>=448 && x<624 && y>=16 && y<48);
    wire [9:0] clock_x=x-10'd448;
    wire [9:0] clock_y=y-10'd20;
    wire [9:0] banner_y=y-10'd444;
    reg [7:0] clock_char;
    always @* begin
        case(clock_x[7:4])
            0:clock_char="U";1:clock_char="P";2:clock_char=" ";
            3:clock_char="0"+displayed_time[23:20];
            4:clock_char="0"+displayed_time[19:16];5:clock_char=":";
            6:clock_char="0"+displayed_time[15:12];
            7:clock_char="0"+displayed_time[11:8];8:clock_char=":";
            9:clock_char="0"+displayed_time[7:4];
            10:clock_char="0"+displayed_time[3:0];
            default:clock_char=" ";
        endcase
    end
    wire [7:0] moving_char=(text_x<640)?(slogan >> ((39-text_x[9:4])*8)):8'h20;
    wire [7:0] moving_glyph,clock_glyph;
    osd_char_rom moving_font(moving_char,banner_y[4:1],moving_glyph);
    osd_char_rom clock_font(clock_char,clock_y[4:1],clock_glyph);
    wire moving_lit=in_banner && y>=444 && y<458 && text_x[3:1]<5 && moving_glyph[4-text_x[3:1]];
    wire clock_lit=in_clock && y>=20 && y<34 && clock_x[3:1]<5 && clock_glyph[4-clock_x[3:1]];
    // alpha=1/2: each channel average of background and dark blue (0,16,32).
    wire [7:0] br={1'b0,rgb[23:17]};
    wire [7:0] bg={1'b0,rgb[15:9]}+8'd8;
    wire [7:0] bb={1'b0,rgb[7:1]}+8'd16;
    wire [23:0] tint={br,bg,bb};
    // Mode indicator: white=cut, amber=fade, cyan=slide, purple=alternating.
    wire [23:0] mode_color=(selected_mode==0)?24'hffffff:
                           (selected_mode==1)?24'hffb040:
                           (selected_mode==2)?24'h40e0ff:24'hd080ff;
    reg [23:0] composed;
    always @* begin
        composed=rgb;
        if(enabled && de) begin
            if(in_banner || in_clock) composed=tint;
            if(in_banner && y>=432 && y<434) composed=mode_color;
            if(x>=632 && y>=436 && y<440) composed=scrolling?24'h40ff80:24'hff6060;
            if(moving_lit) composed=24'hffe090;
            if(clock_lit) composed=24'hffffff;
        end
    end
    always @(posedge clk or posedge rst) begin
        if(rst) begin out_vs<=0;out_de<=0;out_rgb<=0;end
        else begin out_vs<=vs;out_de<=de;out_rgb<=de?composed:24'd0;end
    end
endmodule
