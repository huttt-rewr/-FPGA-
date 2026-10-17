from pathlib import Path
import re
R=Path(__file__).resolve().parents[2]
p=R/'src/modules/osd/caption_overlay.v';s=p.read_text(encoding='utf-8')
s=s.replace('parameter ADAPTIVE=0)(','parameter ADAPTIVE=0,parameter PIPELINED=0)(')
s=s.replace('    wire in_banner=(y>=432', '''    // Split scroll arithmetic, 40-character selection and font/alpha into
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
    wire in_banner=(yy>=432''')
s=s.replace('&& y<472','&& yy<472')
s=s.replace('wire in_clock=(x>=448 && x<624 && y>=16 && y<48);',
 'wire in_clock=(xx>=448 && xx<624 && yy>=16 && yy<48);')
s=s.replace('clock_x=x-10\'d448','clock_x=cx-10\'d448').replace('clock_y=y-10\'d20','clock_y=yy-10\'d20').replace('banner_y=y-10\'d444','banner_y=yy-10\'d444')
s=s.replace('wire [7:0] moving_char=(text_x<640)?(slogan >> ((39-text_x[9:4])*8)):8\'h20;',
 '''wire [9:0] select_x=PIPELINED?tx1:text_x;
    wire [7:0] moving_char=(select_x<640)?(slogan >> ((39-select_x[9:4])*8)):8'h20;
    wire [9:0] glyph_clock_x=xx-10'd448;
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
    end endgenerate''')
s=s.replace('moving_font(moving_char,','moving_font(PIPELINED?moving_char2:moving_char,')
s=s.replace('clock_font(clock_char,','clock_font(PIPELINED?clock_char2:clock_char,')
s=s.replace('y>=444 && y<458 && text_x[3:1]<5 && moving_glyph[4-text_x[3:1]]',
 'yy>=444 && yy<458 && moving_x[3:1]<5 && moving_glyph[4-moving_x[3:1]]')
s=s.replace('y>=20 && y<34 && clock_x[3:1]<5 && clock_glyph[4-clock_x[3:1]]',
 'yy>=20 && yy<34 && glyph_clock_x[3:1]<5 && clock_glyph[4-glyph_clock_x[3:1]]')
s=s.replace('rgb[','background[')
s=s.replace('(selected_mode==','(draw_mode==')
s=s.replace('composed=rgb;','composed=background;').replace('if(enabled && de)','if(draw_enabled && draw_de)')
s=s.replace('y>=432 && y<434','yy>=432 && yy<434').replace('if(x>=632 && y>=436 && y<440)', 'if(xx>=632 && yy>=436 && yy<440)')
s=s.replace('composed=scrolling?','composed=draw_scroll?')
s=s.replace('out_vs<=vs;out_de<=de;out_rgb<=de?', 'out_vs<=draw_vs;out_de<=draw_de;out_rgb<=draw_de?')
p.write_text(s,encoding='utf-8')
p=R/'src/top.v';s=p.read_text(encoding='utf-8').replace('caption_overlay #(.ADAPTIVE(1))','caption_overlay #(.ADAPTIVE(1),.PIPELINED(1))');p.write_text(s,encoding='utf-8')
p=R/'src/modules/video/bmp_scale_loader.v';s=p.read_text(encoding='utf-8')
s=s.replace('localparam [23:0] IDLE=', 'localparam [24:0] IDLE=')
s=s.replace("CONFIG_CHECK=24'h800000;", "CONFIG_CHECK=24'h800000,ROW_PROBE=25'h1000000;")
s=s.replace('reg [23:0] state;', 'reg [24:0] state;\n reg row0_hit,row1_hit;\n always @(posedge clk or posedge rst)begin\n  if(rst)begin row0_hit<=0;row1_hit<=0;end\n  else begin\n   row0_hit<=row_y0[0]?(tags_valid[1] && tag1==row_y0):(tags_valid[0] && tag0==row_y0);\n   row1_hit<=row_y1[0]?(tags_valid[1] && tag1==row_y1):(tags_valid[0] && tag0==row_y1);\n  end\n end')
s=s.replace('state<=CHECK_ROWS;', 'state<=ROW_PROBE;')
s=s.replace('    state[5]: begin', '    state[24]:state<=CHECK_ROWS;\n    state[5]: begin')
s=s.replace('!(row_y0[0]?(tags_valid[1] && tag1==row_y0):(tags_valid[0] && tag0==row_y0))','!row0_hit')
s=s.replace('!(row_y1[0]?(tags_valid[1] && tag1==row_y1):(tags_valid[0] && tag0==row_y1))','!row1_hit')
p.write_text(s,encoding='utf-8')
p=R/'scripts/run_tests.ps1';s=p.read_text(encoding='utf-8')
needle=" $mergeTests += @('tb_video_mode_control','tb_mode_reload')"
assert needle in s;s=s.replace(needle,needle+"\n $mergeTests += @('tb_caption_pipeline')")
p.write_text(s,encoding='utf-8')
print('Pipelined caption scroll/character/font with aligned RGB VS DE; predecoded scaler row hits')
