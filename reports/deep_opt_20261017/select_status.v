// Fixed 40x4 status panel; no uninitialized text RAM.
module status_osd #(parameter ENHANCED_UI=1,parameter ADAPTIVE=1,parameter PIPELINED=1,parameter BOARD_UI=1,parameter AUDIO_UI=1,parameter AUDIO_DIAGNOSTICS=1,parameter FILE_UI=1,parameter RATE_UI=1)(input clk,input rst,input vs,input de,input [23:0] rgb,
    input enable,input auto_play,input [1:0] image_index,input [2:0] image_count,
    input [4:0] volume,input mute,input busy,input error,input edid_ok,
    output [23:0] result,output [9:0] pixel_x,output [9:0] pixel_y,
    input signed [7:0] brightness,input [3:0] contrast,input [1:0] edit_mode,
    input [11:0] source_width,source_height,input mode_800,output out_vs,output out_de,
    input menu_open,input [2:0] menu_item,input gamma_enable,input debug_enable,input [1:0] debug_page,
    input audio_ready,input audio_error,input [3:0] audio_error_code,input audio_underflow,
    input [6:0] file_image_index,file_image_count,file_audio_index,file_audio_count,
    input file_table_truncated,input [3:0] slide_rate_mode,input slide_rate_limited,input [1:0] requested_res_mode);
    wire expanded=ADAPTIVE && mode_800;
    function [7:0] char40;
        input [319:0] text;input [5:0] index;
        reg [319:0] reversed;integer k;
        begin
            for(k=0;k<40;k=k+1)reversed[k*8+:8]=text[(39-k)*8+:8];
            char40=reversed[index*8+:8];
        end
    endfunction
    wire [9:0] x,y,raw_x,raw_y;
    viewport_coordinates coords(clk,rst,vs,de,expanded,x,y,raw_x,raw_y);
    assign pixel_x=raw_x;assign pixel_y=raw_y;
    wire inside_panel=enable && de && x>=16 && x<336 && y>=16 && y<80;
    wire [9:0] lx=x-16,ly=y-16;
    wire [5:0] col=lx[8:3];wire [1:0] row=ly[5:4];
    reg [319:0] line_text;
    reg [7:0] ascii;
    wire [7:0] magnitude=brightness[7]?-brightness:brightness;
    // Resolution metadata is stable for a frame. Register decimal conversion
    // separately so source-width division is not on the per-pixel glyph path.
    reg [3:0] w0,w1,w2,w3,h0,h1,h2,h3;
    // Shift/add-3 conversion has exact 0..4095 coverage without constant
    // divider/modulo networks repeated for each decimal digit.
    function [15:0] bcd12;
        input [11:0] binary;integer bit_index,digit;reg [15:0] bcd;
        begin
            bcd=0;
            for(bit_index=11;bit_index>=0;bit_index=bit_index-1)begin
                for(digit=0;digit<4;digit=digit+1)
                    if(bcd[digit*4+:4]>=5)bcd[digit*4+:4]=bcd[digit*4+:4]+4'd3;
                bcd={bcd[14:0],binary[bit_index]};
            end
            bcd12=bcd;
        end
    endfunction
    wire [15:0] width_decimal=bcd12(source_width),height_decimal=bcd12(source_height);
    always @(posedge clk or posedge rst)begin
        if(rst)begin w0<=0;w1<=0;w2<=0;w3<=0;h0<=0;h1<=0;h2<=0;h3<=0;end
        else begin
            {w0,w1,w2,w3}<=width_decimal;
            {h0,h1,h2,h3}<=height_decimal;
        end
    end
    reg [7:0] contrast_tens,contrast_units;
    always @* begin
        case(contrast[1:0])
            0:begin contrast_tens="0";contrast_units="0";end
            1:begin contrast_tens="2";contrast_units="5";end
            2:begin contrast_tens="5";contrast_units="0";end
            3:begin contrast_tens="7";contrast_units="5";end
        endcase
    end
    always @* begin
        case(row)
            0:line_text="EG4S20 HDMI PLAYER  640X480             ";
            1:line_text="PLAY:OFF IMG:1/4 LOAD:- EDID:-          ";
            2:line_text="VOL:08/16 MUTE:Y TEST AUDIO             ";
            3:line_text="K1:NEXT K2:PLAY SW:CAP/SCROLL/FX        ";
        endcase
        ascii=(col<40)?char40(line_text,col):8'h20;
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
        if(ENHANCED_UI)begin
            if(row==0)line_text="SRC:0000X0000 ->640X480 FIT BILINEAR    ";
            if(row==2)line_text="BRI:+00 CON:1.00 MODE:PLAY              ";
            if(row==3)line_text=(edit_mode==0)?"K3:MODE K1:NEXT K2:AUTO                 ":"K3:MODE K1:MINUS K2:PLUS                ";
            if(row!=1)ascii=(col<40)?char40(line_text,col):8'h20;
            if(row==0)begin
                case(col)
                    16:if(expanded)ascii="8";
                    17:if(expanded)ascii="0";
                    18:if(expanded)ascii="0";
                    20:if(expanded)ascii="6";
                    21:if(expanded)ascii="0";
                    22:if(expanded)ascii="0";
                    4:ascii="0"+w0;
                    5:ascii="0"+w1;
                    6:ascii="0"+w2;
                    7:ascii="0"+w3;
                    9:ascii="0"+h0;
                    10:ascii="0"+h1;
                    11:ascii="0"+h2;
                    12:ascii="0"+h3;
                endcase
            end
            if(row==2)begin
                case(col)
                    4:ascii=brightness[7]?"-":"+";
                    5:ascii="0"+magnitude/10;
                    6:ascii="0"+magnitude%10;
                    12:ascii="0"+(contrast>>2);
                    14:ascii=contrast_tens;
                    15:ascii=contrast_units;
                    22:ascii=(edit_mode==0)?"P":((edit_mode==1)?"B":"C");
                    23:ascii=(edit_mode==0)?"L":((edit_mode==1)?"R":"O");
                    24:ascii=(edit_mode==0)?"A":((edit_mode==1)?"I":"N");
                    25:ascii=(edit_mode==0)?"Y":((edit_mode==1)?"G":"T");
                endcase
            end
        end
    end
    // Metadata decimal conversion stays off the per-pixel font lookup path.
    reg [7:0] it,iu,ct,cu,at,au,nt,nu;
    wire [6:0] image_number=(file_image_count==0)?7'd0:file_image_index+7'd1;
    wire [6:0] audio_number=(file_audio_count==0)?7'd0:file_audio_index+7'd1;
    always @(posedge clk or posedge rst)begin
        if(rst)begin it<=48;iu<=48;ct<=48;cu<=48;at<=48;au<=48;nt<=48;nu<=48;end
        else begin
            it<=48+image_number/10;iu<=48+image_number%10;
            ct<=48+file_image_count/10;cu<=48+file_image_count%10;
            at<=48+audio_number/10;au<=48+audio_number%10;
            nt<=48+file_audio_count/10;nu<=48+file_audio_count%10;
        end
    end
    function [15:0] rate_digits;
        input [3:0] rate_mode;
        begin case(rate_mode)
            1:rate_digits="02";2:rate_digits="05";3:rate_digits="10";
            4:rate_digits="15";5:rate_digits="30";default:rate_digits="01";
        endcase end
    endfunction
    wire [15:0] rate_chars=rate_digits(slide_rate_mode);
    wire [7:0] rate_tens=rate_chars[15:8],rate_units=rate_chars[7:0];
    reg [319:0] menu_text;
    reg [7:0] board_ascii;
    always @* begin
        menu_text=320'd0;
        board_ascii=ascii;
        if(FILE_UI && row==1)begin
            menu_text="PLAY:OFF IMG:00/00 AUD:00/00 LOAD:-     ";
            board_ascii=(col<40)?char40(menu_text,col):8'h20;
            case(col)
                5:board_ascii="O";6:board_ascii=auto_play?"N":"F";7:board_ascii=auto_play?" ":"F";
                13:board_ascii=it;14:board_ascii=iu;16:board_ascii=ct;17:board_ascii=cu;
                23:board_ascii=at;24:board_ascii=au;26:board_ascii=nt;27:board_ascii=nu;
                34:board_ascii=error?"E":(busy?"B":"-");
                39:board_ascii=file_table_truncated?"T":" ";
            endcase
        end
        if(RATE_UI && row==0 && col>=24)begin
            case(col)
                24:board_ascii="T";25:board_ascii="A";26:board_ascii="R";27:board_ascii="G";
                28:board_ascii="E";29:board_ascii="T";30:board_ascii=":";
                31:board_ascii=rate_tens;32:board_ascii=rate_units;
                33:board_ascii=slide_rate_limited?"L":" ";
                35:board_ascii="R";36:board_ascii=":";37:board_ascii="0"+requested_res_mode;
                default:board_ascii=" ";
            endcase
        end
        if(BOARD_UI)begin
            // ÒôÆµ×´Ì¬£ºE´íÎó¡¢M¾²Òô¡¢RÒÑ½âÎö£¬-ÉÐÎ´×¼±¸¡£
            if(AUDIO_UI && !menu_open && row==3 && col>=28)begin
                case(col)
                    28:board_ascii="A";29:board_ascii=":";
                    30:board_ascii=audio_error?"E":(mute?"M":(audio_ready?"R":"-"));
                    31:board_ascii=" ";32:board_ascii="V";33:board_ascii=":";
                    34:board_ascii="0"+volume/10;35:board_ascii="0"+volume%10;
                    default:board_ascii=" ";
                endcase
                if(AUDIO_DIAGNOSTICS)begin
                    case(col)
                        31:board_ascii=audio_error?("0"+audio_error_code):"-";
                        32:board_ascii=" ";33:board_ascii="V";34:board_ascii=":";
                        35:board_ascii="0"+volume/10;36:board_ascii="0"+volume%10;
                        37:board_ascii=" ";38:board_ascii="U";39:board_ascii=audio_underflow?"1":"0";
                    endcase
                end
            end
            // No extra overlay pipeline: reuse this existing panel and font.
            if(!menu_open && row==2)begin
                case(col)
                    28:board_ascii="G";
                    29:board_ascii=":";
                    30:board_ascii=gamma_enable?"1":"0";
                    32:board_ascii="D";
                    33:board_ascii=":";
                    34:board_ascii=debug_enable?"1":"0";
                    36:board_ascii="P";
                    37:board_ascii=":";
                    38:board_ascii="0"+debug_page;
                endcase
            end
            if(menu_open && row>=2)begin
                if(row==3)menu_text="K1:UP K2:DOWN K3:OK HOLD3:EXIT          ";
                else case(menu_item)
                    0:menu_text="MENU >PLAY / PAUSE                      ";
                    1:menu_text="MENU >GAMMA:OFF (SHADOW LIFT)           ";
                    2:menu_text="MENU >DIAG:OFF (7-SEGMENT)              ";
                    3:menu_text="MENU >DIAG PAGE:0                       ";
                    4:menu_text="MENU >AUDIO MUTE:ON                     ";
                    5:menu_text="MENU >VOLUME DOWN:08                    ";
                    6:menu_text="MENU >VOLUME UP:08                      ";
                    default:menu_text="MENU >PLAY / PAUSE                      ";
                endcase
                board_ascii=(col<40)?char40(menu_text,col):8'h20;
                if(row==2 && menu_item==1)begin
                    if(col==12)board_ascii="O";
                    if(col==13)board_ascii=gamma_enable?"N":"F";
                    if(col==14)board_ascii=gamma_enable?" ":"F";
                end
                if(row==2 && menu_item==2)begin
                    if(col==11)board_ascii="O";
                    if(col==12)board_ascii=debug_enable?"N":"F";
                    if(col==13)board_ascii=debug_enable?" ":"F";
                end
                if(row==2 && menu_item==3 && col==16)board_ascii="0"+debug_page;
                if(AUDIO_UI && row==2 && menu_item==4)begin
                    if(col==18)board_ascii=mute?"N":"F";
                    if(col==19)board_ascii=mute?" ":"F";
                end
                if(AUDIO_UI && row==2 && menu_item==5)begin
                    if(col==18)board_ascii="0"+volume/10;
                    if(col==19)board_ascii="0"+volume%10;
                end
                if(AUDIO_UI && row==2 && menu_item==6)begin
                    if(col==16)board_ascii="0"+volume/10;
                    if(col==17)board_ascii="0"+volume%10;
                end
            end
        end
    end
    wire [7:0] glyph;
    reg [7:0] ascii_q;reg [2:0] gx_q;reg [3:0] gy_q;
    reg [23:0] rgb_q;reg inside_q,vs_q,de_q;
    always @(posedge clk or posedge rst)begin
        if(rst)begin ascii_q<=32;gx_q<=0;gy_q<=0;rgb_q<=0;inside_q<=0;vs_q<=0;de_q<=0;end
        else begin
            ascii_q<=board_ascii;gx_q<=lx[2:0];gy_q<=ly[3:0];rgb_q<=rgb;
            inside_q<=inside_panel;vs_q<=vs;de_q<=de;
        end
    end
    wire [2:0] gx=PIPELINED?gx_q:lx[2:0];
    wire [23:0] background=PIPELINED?rgb_q:rgb;
    osd_char_rom font(.i_ascii(PIPELINED?ascii_q:board_ascii),.i_row(PIPELINED?gy_q:ly[3:0]),.o_row_data(glyph));
    wire lit=(gx<5) && glyph[4-gx];
    wire [23:0] dark={1'b0,background[23:17],1'b0,background[15:9],1'b0,background[7:1]};
    assign result=(PIPELINED?inside_q:inside_panel) ? (lit?24'h60ffb0:dark) : background;
    assign out_vs=PIPELINED?vs_q:vs;
    assign out_de=PIPELINED?de_q:de;
endmodule
