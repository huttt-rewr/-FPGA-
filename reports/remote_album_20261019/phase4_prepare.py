from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
root=Path(__file__).resolve().parents[2]
def edit(path,pairs):
 p=root/path;s=p.read_text(encoding='utf-8-sig')
 for old,new in pairs:
  assert old in s,(path,old);s=s.replace(old,new)
 p.write_text(s,encoding='utf-8')
chars='欢迎光临电子相册参赛作品多媒体展示'
font=ImageFont.truetype('C:/Windows/Fonts/simhei.ttf',16)
rows=[];preview=Image.new('RGB',(len(chars)*32,32),'black')
for k,ch in enumerate(chars):
 image=Image.new('1',(16,16));draw=ImageDraw.Draw(image)
 draw.text((0,0),ch,font=font,fill=1,anchor='lt')
 preview.paste(image.convert('RGB').resize((32,32)),(32*k,0))
 for y in range(16):
  row=0
  for x in range(16):row=(row<<1)|image.getpixel((x,y))
  rows.append(row)
rows+= [0]*(512-len(rows))
preview.save(root/'reports/remote_album_20261019/zh_preview.png')
(root/'src/modules/osd/zh_font.mem').write_text(''.join(f'{r:04x}\n' for r in rows),encoding='ascii')
rom='''// SimHei 16x16 fixed message. Generated from Windows installed font.
// Embedded initialization avoids working-directory dependent readmemh paths.
module zh_font_rom(input clk,input [4:0] char_idx,input [3:0] row,output reg [15:0] bits);
 (* ram_style="bram" *) reg [15:0] mem[0:511];
 initial begin
'''
for n,r in enumerate(rows):rom+=f"  mem[{n}]=16'h{r:04x};\n"
rom+=' end\n always @(posedge clk)bits<=mem[{char_idx,row}];\nendmodule\n'
(root/'src/modules/osd/zh_font_rom.v').write_text(rom,encoding='utf-8')
(root/'src/modules/osd/zh_overlay.v').write_text('''// Two-stage synchronous font fetch and registered alpha/text composition.
// Coordinates are the logical 640x480 viewport in either output mode.
module zh_overlay #(parameter WIN_X=32,WIN_Y=384,CHARS=19)(
 input clk,rst,vs,de,input [9:0] x,y,input [23:0] rgb,input enable,
 output reg out_vs,out_de,output reg [9:0] out_x,out_y,output reg [23:0] out_rgb);
 reg vs_last,enabled;
 wire [9:0] local_x=x-WIN_X,local_y=y-WIN_Y;
 wire in_window=(x>=WIN_X && x<WIN_X+CHARS*16 && y>=WIN_Y && y<WIN_Y+16);
 wire [15:0] glyph;
 zh_font_rom font(clk,local_x[8:4],local_y[3:0],glyph);
 reg v1,d1,draw1;reg [9:0]x1,y1;reg [23:0]rgb1;reg [3:0]column1;
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   vs_last<=1;enabled<=0;v1<=0;d1<=0;draw1<=0;x1<=0;y1<=0;rgb1<=0;column1<=0;
   out_vs<=0;out_de<=0;out_x<=0;out_y<=0;out_rgb<=0;
  end else begin
   vs_last<=vs;if(vs_last && !vs)enabled<=enable;
   v1<=vs;d1<=de;x1<=x;y1<=y;rgb1<=rgb;column1<=local_x[3:0];draw1<=enabled && in_window;
   out_vs<=v1;out_de<=d1;out_x<=x1;out_y<=y1;
   if(!d1)out_rgb<=0;
   else if(draw1 && glyph[15-column1])out_rgb<=24'hffe090;
   else if(draw1)out_rgb<={1'b0,rgb1[23:17],1'b0,rgb1[15:9],1'b0,rgb1[7:1]};
   else out_rgb<=rgb1;
  end
 end
endmodule
'''.replace('CHARS=19',f'CHARS={len(chars)}'),encoding='utf-8')
(root/'src/modules/control/slideshow_timer.v').write_text('''// Optional independent album cadence. A registered terminal keeps the wide
// comparator away from the 100MHz counter-reset/output path. Busy saturates.
module slideshow_timer #(parameter PERIOD=500000000)(
 input clk,rst,enable,input busy,output reg next_pulse);
 localparam CW=(PERIOD<2)?1:$clog2(PERIOD);
 reg [CW-1:0] count;
 reg due;
 always @(posedge clk or posedge rst)begin
  if(rst)begin count<=0;due<=0;next_pulse<=0;end
  else begin
   next_pulse<=0;
   if(!enable)begin count<=0;due<=0;end
   else if(due || PERIOD<=1)begin
    if(!busy)begin count<=0;due<=0;next_pulse<=1;end
   end else begin
    count<=count+1'b1;
    if(count==PERIOD-2)due<=1;
   end
  end
 end
endmodule
''',encoding='utf-8')
edit('src/modules/control/player_control.v',[
 ('output reg auto_enh_en);','output reg auto_enh_en,output reg slide_enable,zh_enable,large_clock);'),
 ('auto_enh_en<=0;','auto_enh_en<=0;slide_enable<=0;zh_enable<=0;large_clock<=0;'),
 ('"a":auto_enh_en<=~auto_enh_en;', '"a":auto_enh_en<=~auto_enh_en;\n                    "s":slide_enable<=~slide_enable;\n                    "h":zh_enable<=~zh_enable;\n                    "l":large_clock<=~large_clock;')])
edit('src/modules/control/remote_controls.v',[
 ('output auto_enh_en);','output auto_enh_en,output slide_enable,zh_enable,large_clock);'),
 ('data=="a")?data','data=="a" || data=="s" || data=="h" || data=="l")?data'),
 ('.auto_enh_en(auto_enh_en));','.auto_enh_en(auto_enh_en),.slide_enable(slide_enable),.zh_enable(zh_enable),.large_clock(large_clock));')])
edit('src/top.v',[
 ('wire auto_enh_en,auto_enh_video;', '''wire auto_enh_en,auto_enh_video,slide_enable,zh_enable,large_clock;
wire [1:0] album_video;
wire slide_next;
wire zh_vs,zh_de;wire [23:0] zh_rgb;wire [9:0] zh_x,zh_y;'''),
 ('|| kb_next || pc_next;', '|| kb_next || pc_next || slide_next;'),
 ('.auto_enh_en(auto_enh_en));','.auto_enh_en(auto_enh_en),.slide_enable(slide_enable),.zh_enable(zh_enable),.large_clock(large_clock));'),
 ('cdc_snapshot #(.WIDTH(33)) time_cdc(','''slideshow_timer #(.PERIOD(500000000)) album_timer(.clk(sd_card_clk),.rst(rst_controls),
 .enable(slide_enable && !status_auto && player_display_valid && media_image_count>1),
 .busy(status_busy || status_error || !sd_init_done),.next_pulse(slide_next));
cdc_snapshot #(.WIDTH(2)) album_cdc(.src_clk(sd_card_clk),.src_rst(rst_controls),
 .src_data({large_clock,zh_enable}),.dst_clk(video_clk),.dst_rst(rst_video),.dst_data(album_video));
cdc_snapshot #(.WIDTH(33)) time_cdc('''),
 ('.time_set(time_video[32]),.time_seq', '.large_clock(album_video[1]),.time_set(time_video[32]),.time_seq'),
 ('status_osd #(.ENHANCED_UI(1),', '''viewport_coordinates chinese_coordinates(video_clk,rst_video,caption_vs,caption_de,mode_video,zh_x,zh_y,,);
zh_overlay chinese(.clk(video_clk),.rst(rst_video),.vs(caption_vs),.de(caption_de),.x(zh_x),.y(zh_y),
 .rgb(caption_rgb),.enable(album_video[0]),.out_vs(zh_vs),.out_de(zh_de),.out_rgb(zh_rgb),.out_x(),.out_y());
status_osd #(.ENHANCED_UI(1),'''),
 ('.vs(caption_vs),.de(caption_de),.rgb(caption_rgb),',
  '.vs(zh_vs),.de(zh_de),.rgb(zh_rgb),')])
edit('src/modules/osd/caption_overlay.v',[
 ('input [7:0] time_seq,input [23:0] time_bcd,input time_set);',
  'input [7:0] time_seq,input [23:0] time_bcd,input time_set,input large_clock);'),
 ('reg wall_clock,displayed_wall;', 'reg wall_clock,displayed_wall,clock_large;'),
 ('displayed_wall<=0;', 'displayed_wall<=0;clock_large<=0;'),
 ('displayed_wall<=wall_clock || load_time;', 'displayed_wall<=wall_clock || load_time;clock_large<=(large_clock===1\'b1);'),
 ('wire in_clock=(xx>=448 && xx<624 && yy>=16 && yy<48);',
  'wire in_clock=clock_large?(xx>=144 && xx<496 && yy>=96 && yy<160):(xx>=448 && xx<624 && yy>=16 && yy<48);'),
 ("wire [9:0] clock_x=cx-10'd448;", "wire [9:0] clock_x=cx-(clock_large?10'd144:10'd448);\n    wire [3:0] clock_index=clock_large?clock_x[8:5]:clock_x[7:4];"),
 ("wire [9:0] clock_y=yy-10'd20;", "wire [9:0] clock_y=yy-(clock_large?10'd104:10'd20);\n    wire [3:0] clock_row=clock_large?clock_y[5:2]:clock_y[4:1];"),
 ('case(clock_x[7:4])','case(clock_index)'),
 ("wire [9:0] glyph_clock_x=xx-10'd448;", "wire [9:0] glyph_clock_x=xx-(clock_large?10'd144:10'd448);\n    wire [2:0] clock_column=clock_large?glyph_clock_x[4:2]:glyph_clock_x[3:1];"),
 ('clock_y[4:1],clock_glyph','clock_row,clock_glyph'),
 ('in_clock && yy>=20 && yy<34 && glyph_clock_x[3:1]<5 && clock_glyph[4-glyph_clock_x[3:1]]',
  'in_clock && (clock_large?(yy>=104 && yy<132):(yy>=20 && yy<34)) && clock_column<5 && clock_glyph[4-clock_column]')])
# Positional compatibility tests receive explicit disabled controls.
edit('sim/tb_upgrade.v',[('wire captions,scroll,auto_enh;', 'wire captions,scroll,auto_enh,slide,zh,clock_big;'),
 ('effect,captions,scroll,slogan,auto_enh);','effect,captions,scroll,slogan,auto_enh,slide,zh,clock_big);')])
edit('sim/tb_remote_uart.v',[('wire tx,overflow,np,pp,tp,ts,auto_enh;', 'wire tx,overflow,np,pp,tp,ts,auto_enh,slide,zh,clock_big;'),
 ("time_bcd,seq,ts,1'b1,auto_enh);", "time_bcd,seq,ts,1'b1,auto_enh,slide,zh,clock_big);"),
 ('.time_set(snapshot[32]),.time_seq', ".large_clock(1'b0),.time_set(snapshot[32]),.time_seq")])
for name in ('tb_board_pipeline','tb_effects_pipeline','tb_svga_pipeline','tb_caption_overlay','tb_caption_pipeline'):
 p=root/'sim'/(name+'.v');s=p.read_text(encoding='utf-8-sig').replace(",8'd0,24'd0,1'b0);",",8'd0,24'd0,1'b0,1'b0);")
 p.write_text(s,encoding='utf-8')
edit('scripts/run_tests.ps1',[('$files += @($mergeTests |',"$mergeTests += @('tb_album_timer','tb_zh_overlay','tb_album_clock')\n $files += @($mergeTests |")])
print('Installed optional album timer, larger clock and',len(chars),'Chinese glyphs')
