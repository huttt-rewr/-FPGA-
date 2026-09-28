// Fixed 40x4 status panel; no uninitialized text RAM.
module status_osd(input clk,input rst,input vs,input de,input [23:0] rgb,
    input enable,input auto_play,input [1:0] image_index,input [2:0] image_count,
    input [4:0] volume,input mute,input busy,input error,input edid_ok,
    output [23:0] result,output [9:0] pixel_x,output [9:0] pixel_y);
    reg [9:0] x,y;
    reg de_d;
    always @(posedge clk or posedge rst) begin
        if(rst) begin x<=0;y<=0;de_d<=0;end
        else begin
            de_d<=de;
            if(!vs) begin x<=0;y<=0;end
            else begin
                if(de) x <= x==639 ? 10'd0 : x+1'b1;else x<=0;
                if(de_d && !de) y<=y+1'b1;
            end
        end
    end
    assign pixel_x=x;assign pixel_y=y;
    wire inside_panel=enable && de && x>=16 && x<336 && y>=16 && y<80;
    wire [9:0] lx=x-16,ly=y-16;
    wire [5:0] col=lx[8:3];wire [1:0] row=ly[5:4];
    reg [319:0] line_text;
    reg [7:0] ascii;
    always @* begin
        case(row)
            0:line_text="EG4S20 HDMI PLAYER  640X480             ";
            1:line_text="PLAY:OFF IMG:1/4 LOAD:- EDID:-          ";
            2:line_text="VOL:08/16 MUTE:Y TEST AUDIO             ";
            3:line_text="N:NEXT B:PREV P:PLAY +/-:VOL M:MUTE     ";
        endcase
        ascii=(col<40)?(line_text >> ((39-col)*8)):8'h20;
        if(row==1) begin
            if(col==5) ascii="O";
            if(col==6) ascii=auto_play?"N":"F";
            if(col==7) ascii=auto_play?" ":"F";
            if(col==13) ascii="1"+image_index;
            if(col==15) ascii="0"+image_count;
            if(col==22) ascii=error?"E":(busy?"B":"-");
            if(col==29) ascii=edid_ok?"Y":"-";
        end
        if(row==2) begin
            if(col==4) ascii="0"+(volume>=10);
            if(col==5) ascii="0"+((volume>=10)?volume-10:volume);
            if(col==15) ascii=mute?"Y":"N";
        end
    end
    wire [7:0] glyph;
    osd_char_rom font(.i_ascii(ascii),.i_row(ly[3:0]),.o_row_data(glyph));
    wire lit=(lx[2:0]<5) && glyph[4-lx[2:0]];
    wire [23:0] dark={1'b0,rgb[23:17],1'b0,rgb[15:9],1'b0,rgb[7:1]};
    assign result=inside_panel ? (lit?24'h60ffb0:dark) : rgb;
endmodule
