// Pixel-domain layers: incoming picture -> half-transparent banner -> text/shadow.
// One output register, with VS/DE delayed identically. Controls/time latch in blank.
// Time defaults to uptime; accepted UART HHMMSS selects a 24-hour wall clock.
module caption_overlay #(parameter CLK_HZ=25000000,parameter ADAPTIVE=0,parameter PIPELINED=0)(
    input clk,input rst,input vs,input de,input [23:0] rgb,
    input enable,input scroll_enable,input [1:0] slogan_select,
    input [1:0] transition_mode,
    output reg out_vs,output reg out_de,output reg [23:0] out_rgb,input mode_800,
    input [7:0] time_seq,input [23:0] time_bcd,input time_set,input large_clock);
    function [7:0] char40;
        input [319:0] text;input [5:0] index;
        reg [319:0] reversed;integer k;
        begin
            for(k=0;k<40;k=k+1)reversed[k*8+:8]=text[(39-k)*8+:8];
            char40=reversed[index*8+:8];
        end
    endfunction
    wire [9:0] x,y;
    viewport_coordinates coords(clk,rst,vs,de,(ADAPTIVE && mode_800),x,y,,);
    reg vs_d,enabled,scrolling;
    reg [1:0] selected,selected_mode;
    wire frame_start=vs_d && !vs;
    reg [25:0] second_count;
    reg [3:0] sec_units,sec_tens,min_units,min_tens,hour_units,hour_tens;
    reg [23:0] displayed_time;
    reg [7:0] last_seq;
    reg wall_clock,displayed_wall,clock_large;
    wire load_time=(time_set===1'b1) && (!wall_clock || time_seq!=last_seq);
    reg [9:0] scroll_x;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            vs_d<=1;enabled<=0;scrolling<=1;selected<=0;selected_mode<=1;
            second_count<=0;sec_units<=0;sec_tens<=0;min_units<=0;min_tens<=0;
            hour_units<=0;hour_tens<=0;displayed_time<=0;scroll_x<=0;last_seq<=0;wall_clock<=0;displayed_wall<=0;clock_large<=0;
        end else begin
            vs_d<=vs;
            if(load_time)begin
                last_seq<=time_seq;wall_clock<=1;second_count<=0;
                sec_units<=time_bcd[3:0];sec_tens<=time_bcd[7:4];
                min_units<=time_bcd[11:8];min_tens<=time_bcd[15:12];
                hour_units<=time_bcd[19:16];hour_tens<=time_bcd[23:20];
            end else if(second_count==((ADAPTIVE && mode_800)?40000000:CLK_HZ)-1) begin
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
                                if(wall_clock && hour_tens==2 && hour_units==3)begin hour_units<=0;hour_tens<=0;end
                                else if(hour_units!=9) hour_units<=hour_units+1'b1;
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
                displayed_time<=load_time?time_bcd:{hour_tens,hour_units,min_tens,min_units,sec_tens,sec_units};
                displayed_wall<=wall_clock || load_time;clock_large<=(large_clock===1'b1);
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
    // Split scroll arithmetic, 40-character selection and font/alpha into
    // three stages. Legacy profiles retain one output register.
    reg [9:0] x1,y1,tx1,x2,y2,tx2;
    reg [23:0] rgb1,rgb2;
    reg vs1,de1,vs2,de2,en1,en2,scroll1,scroll2;
    reg [1:0] mode1,mode2;
    reg [7:0] moving_char2,clock_char2;
    wire [9:0] cx=PIPELINED?x1:x,cy=PIPELINED?y1:y;
    wire [9:0] xx=PIPELINED?x2:x,yy=PIPELINED?y2:y;
    wire [9:0] moving_x=PIPELINED?tx2:text_x;
    wire [23:0] background=PIPELINED?rgb2:rgb;
    wire draw_de=PIPELINED?de2:de,draw_vs=PIPELINED?vs2:vs;
    wire draw_enabled=PIPELINED?en2:enabled,draw_scroll=PIPELINED?scroll2:scrolling;
    wire [1:0] draw_mode=PIPELINED?mode2:selected_mode;
    wire in_banner=(yy>=432 && yy<472);
    wire in_clock=clock_large?(xx>=144 && xx<496 && yy>=96 && yy<160):(xx>=448 && xx<624 && yy>=16 && yy<48);
    wire [9:0] clock_x=cx-(clock_large?10'd144:10'd448);
    wire [3:0] clock_index=clock_large?clock_x[8:5]:clock_x[7:4];
    wire [9:0] clock_y=yy-(clock_large?10'd104:10'd20);
    wire [3:0] clock_row=clock_large?clock_y[5:2]:clock_y[4:1];
    wire [9:0] banner_y=yy-10'd444;
    reg [7:0] clock_char;
    always @* begin
        case(clock_index)
            0:clock_char=displayed_wall?"B":"U";1:clock_char=displayed_wall?"J":"P";2:clock_char=" ";
            3:clock_char="0"+displayed_time[23:20];
            4:clock_char="0"+displayed_time[19:16];5:clock_char=":";
            6:clock_char="0"+displayed_time[15:12];
            7:clock_char="0"+displayed_time[11:8];8:clock_char=":";
            9:clock_char="0"+displayed_time[7:4];
            10:clock_char="0"+displayed_time[3:0];
            default:clock_char=" ";
        endcase
    end
    wire [9:0] select_x=PIPELINED?tx1:text_x;
    wire [7:0] moving_char=(select_x<640)?char40(slogan,select_x[9:4]):8'h20;
    wire [9:0] glyph_clock_x=xx-(clock_large?10'd144:10'd448);
    wire [2:0] clock_column=clock_large?glyph_clock_x[4:2]:glyph_clock_x[3:1];
    generate if(PIPELINED)begin:font_pipeline
      always @(posedge clk or posedge rst)begin
        if(rst)begin
          x1<=0;y1<=0;tx1<=0;x2<=0;y2<=0;tx2<=0;rgb1<=0;rgb2<=0;
          vs1<=0;de1<=0;vs2<=0;de2<=0;en1<=0;en2<=0;
          scroll1<=0;scroll2<=0;mode1<=0;mode2<=0;moving_char2<=32;clock_char2<=32;
        end else begin
          x1<=x;y1<=y;tx1<=text_x;rgb1<=rgb;vs1<=vs;de1<=de;
          en1<=enabled;scroll1<=scrolling;mode1<=selected_mode;
          x2<=x1;y2<=y1;tx2<=tx1;rgb2<=rgb1;vs2<=vs1;de2<=de1;
          en2<=en1;scroll2<=scroll1;mode2<=mode1;
          moving_char2<=moving_char;clock_char2<=clock_char;
        end
      end
    end endgenerate
    wire [7:0] moving_glyph,clock_glyph;
    osd_char_rom moving_font(PIPELINED?moving_char2:moving_char,banner_y[4:1],moving_glyph);
    osd_char_rom clock_font(PIPELINED?clock_char2:clock_char,clock_row,clock_glyph);
    wire moving_lit=in_banner && yy>=444 && yy<458 && moving_x[3:1]<5 && moving_glyph[4-moving_x[3:1]];
    wire clock_lit=in_clock && (clock_large?(yy>=104 && yy<132):(yy>=20 && yy<34)) && clock_column<5 && clock_glyph[4-clock_column];
    // alpha=1/2: each channel average of background and dark blue (0,16,32).
    wire [7:0] br={1'b0,background[23:17]};
    wire [7:0] bg={1'b0,background[15:9]}+8'd8;
    wire [7:0] bb={1'b0,background[7:1]}+8'd16;
    wire [23:0] tint={br,bg,bb};
    // Mode indicator: white=cut, amber=fade, cyan=slide, purple=alternating.
    wire [23:0] mode_color=(draw_mode==0)?24'hffffff:
                           (draw_mode==1)?24'hffb040:
                           (draw_mode==2)?24'h40e0ff:24'hd080ff;
    reg [23:0] composed;
    always @* begin
        composed=background;
        if(draw_enabled && draw_de) begin
            if(in_banner || in_clock) composed=tint;
            if(in_banner && yy>=432 && yy<434) composed=mode_color;
            if(xx>=632 && yy>=436 && yy<440) composed=draw_scroll?24'h40ff80:24'hff6060;
            if(moving_lit) composed=24'hffe090;
            if(clock_lit) composed=24'hffffff;
        end
    end
    always @(posedge clk or posedge rst) begin
        if(rst) begin out_vs<=0;out_de<=0;out_rgb<=0;end
        else begin out_vs<=draw_vs;out_de<=draw_de;out_rgb<=draw_de?composed:24'd0;end
    end
endmodule
