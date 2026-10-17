from pathlib import Path
R=Path(__file__).resolve().parents[2]
files={}
files['pixel_effects.v']=r'''// All modes have three registers of latency; causal Sobel centre (x-1,y-1).
module pixel_effects #(parameter DEPTH=1024,parameter [7:0] EDGE_TH=80)(
 input clk,rst,vs,de,input [9:0] x,input [23:0] rgb,input [1:0] mode_sel,
 output reg out_vs,out_de,output reg [23:0] out_rgb);
 wire [7:0] gray,t0,t1,t2,m0,m1,m2,b0,b1,b2;wire good;
 video_luma_window #(.DEPTH(DEPTH)) window(clk,rst,vs,de,x,rgb,gray,t0,t1,t2,m0,m1,m2,b0,b1,b2,good);
 reg [10:0] xp1,xn1,yp1,yn1;reg [11:0] mag2;
 reg [23:0] rgb1,rgb2;reg [7:0] gray1,gray2;
 reg vs1,vs2,de1,de2,w1,w2,vs_last;reg [1:0] mode1,mode2,frame_mode;
 wire [10:0] xp={3'd0,t2}+{2'd0,m2,1'b0}+{3'd0,b2},xn={3'd0,t0}+{2'd0,m0,1'b0}+{3'd0,b0};
 wire [10:0] yp={3'd0,b0}+{2'd0,b1,1'b0}+{3'd0,b2},yn={3'd0,t0}+{2'd0,t1,1'b0}+{3'd0,t2};
 wire [10:0] ax=(xp1>=xn1)?xp1-xn1:xn1-xp1,ay=(yp1>=yn1)?yp1-yn1:yn1-yp1;
 reg [23:0] thermal;
 always @*case(gray2[7:6])
  0:thermal={8'd0,gray2[5:0],2'b00,8'hff};
  1:thermal={8'd0,8'hff,(8'hff-{gray2[5:0],2'b00})};
  2:thermal={gray2[5:0],2'b00,8'hff,8'd0};
  3:thermal={8'hff,(8'hff-{gray2[5:0],2'b00}),8'd0};
 endcase
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   frame_mode<=0;vs_last<=1;mode1<=0;mode2<=0;xp1<=0;xn1<=0;yp1<=0;yn1<=0;mag2<=0;
   rgb1<=0;rgb2<=0;gray1<=0;gray2<=0;vs1<=0;vs2<=0;de1<=0;de2<=0;w1<=0;w2<=0;out_vs<=0;out_de<=0;out_rgb<=0;
  end else begin
   vs_last<=vs;if(vs_last && !vs)frame_mode<=mode_sel;
   xp1<=xp;xn1<=xn;yp1<=yp;yn1<=yn;mag2<={1'b0,ax}+{1'b0,ay};
   rgb1<=rgb;rgb2<=rgb1;gray1<=gray;gray2<=gray1;vs1<=vs;vs2<=vs1;de1<=de;de2<=de1;w1<=good;w2<=w1;
   mode1<=frame_mode;mode2<=mode1;out_vs<=vs2;out_de<=de2;
   if(!de2)out_rgb<=0;
   else case(mode2)
    0:out_rgb<=rgb2;1:out_rgb<=~rgb2;
    2:out_rgb<=(w2 && mag2>{4'd0,EDGE_TH})?24'hffffff:24'd0;
    3:out_rgb<=thermal;
   endcase
  end
 end
endmodule

// TD ram_style="dram" means LUT distributed RAM, never SDRAM/BRAM.
// No RAM reset/initialization. Mask the first two rows/columns EVERY frame.
module video_luma_window #(parameter DEPTH=1024)(
 input clk,rst,vs,de,input [9:0] x,input [23:0] rgb,
 output [7:0] gray,t0,t1,t2,m0,m1,m2,b0,b1,b2,output valid);
 (* dsp_style="no" *) wire [15:0] weighted=rgb[23:16]*16'd77+rgb[15:8]*16'd150+rgb[7:0]*16'd29;
 assign gray=weighted[15:8];
 (* ram_style="dram" *) reg [7:0] row1[0:DEPTH-1];
 (* ram_style="dram" *) reg [7:0] row2[0:DEPTH-1];
 wire ok=x<DEPTH;wire [7:0] p1=ok?row1[x]:8'd0,p2=ok?row2[x]:8'd0;
 reg [7:0] ta,tb,ma,mb,ba,bb;reg de_last;reg [1:0] rows;
 assign t0=tb;assign t1=ta;assign t2=p2;assign m0=mb;assign m1=ma;assign m2=p1;
 assign b0=bb;assign b1=ba;assign b2=gray;
 assign valid=de && vs && ok && rows==2 && x>=2;
 always @(posedge clk)if(!rst && vs && de && ok)begin row1[x]<=gray;row2[x]<=p1;end
 always @(posedge clk or posedge rst)begin
  if(rst)begin ta<=0;tb<=0;ma<=0;mb<=0;ba<=0;bb<=0;rows<=0;de_last<=0;end
  else begin
   de_last<=de;if(!vs)rows<=0;else if(de_last && !de && rows!=2)rows<=rows+1'b1;
   if(!de || !vs)begin ta<=0;tb<=0;ma<=0;mb<=0;ba<=0;bb<=0;end
   else begin ta<=p2;tb<=(x==0)?8'd0:ta;ma<=p1;mb<=(x==0)?8'd0:ma;ba<=gray;bb<=(x==0)?8'd0:ba;end
  end
 end
endmodule
'''
files['glass_osd.v']=r'''// Six registers: luma box blur -> retained chroma -> dark glass -> shadow/text.
module glass_osd #(parameter DEPTH=1024,parameter [9:0] WIN_X=120,WIN_Y=80,WIN_W=400,WIN_H=320)(
 input clk,rst,vs,de,input [9:0] x,y,input [23:0] rgb,input [7:0] ascii_char,input osd_enable,
 output reg out_vs,out_de,output reg [23:0] out_rgb);
 wire [9:0] raw_x,raw_y;video_coordinates physical_coordinates(clk,rst,vs,de,raw_x,raw_y);
 wire [7:0] gray,t0,t1,t2,m0,m1,m2,b0,b1,b2;wire good;
 video_luma_window #(.DEPTH(DEPTH)) window(clk,rst,vs,de,raw_x,rgb,gray,t0,t1,t2,m0,m1,m2,b0,b1,b2,good);
 wire panel=(x>=WIN_X && {1'b0,x}<{1'b0,WIN_X}+WIN_W && y>=WIN_Y && {1'b0,y}<{1'b0,WIN_Y}+WIN_H);
 wire [9:0] tx=x-WIN_X-10'd16,ty=y-WIN_Y-10'd16,sx=tx-10'd2,sy=ty-10'd2;
 wire [7:0] glyph,shadow_glyph;
 osd_char_rom font(ascii_char,ty[4:1],glyph);osd_char_rom shadow_font(ascii_char,sy[4:1],shadow_glyph);
 wire text_band=panel && x>=WIN_X+16 && {1'b0,x}<{1'b0,WIN_X}+WIN_W-16 && y>=WIN_Y+16 && y<WIN_Y+30;
 wire shadow_band=panel && x>=WIN_X+18 && {1'b0,x}<{1'b0,WIN_X}+WIN_W-14 && y>=WIN_Y+18 && y<WIN_Y+32;
 wire lit=text_band && tx[2:0]<5 && glyph[4-tx[2:0]],shade=shadow_band && sx[2:0]<5 && shadow_glyph[4-sx[2:0]];
 reg enabled,vs_last;reg [9:0] sumt1,summ1,sumb1;reg [11:0] sum2;
 (* dsp_style="no" *) wire [24:0] ninth=sum2*13'd7282;
 // floor(sum/9), exact for 0..2295, using reciprocal/shift.
 reg [7:0] blur3,gray1,gray2,gray3;reg [23:0] rgb1,rgb2,rgb3,rgb4,rgb5,recolor4,dark5;
 reg [4:0] vp,dp,pp,lp,sp;
 function [7:0] corrected;
  input [7:0] c,g,a;reg signed [9:0] v;
  begin v=$signed({2'd0,c})+$signed({2'd0,a})-$signed({2'd0,g});corrected=v<0?8'd0:(v>255?8'd255:v[7:0]);end
 endfunction
 function [7:0] darken;input [7:0] c;reg [15:0] p;begin p=c*16'd153;darken=p[15:8];end endfunction
 function [7:0] blend;input [7:0] a,b;reg [15:0] v;begin v=a*16'd153+b*16'd103;blend=v[15:8];end endfunction
 wire [23:0] mixed={blend(dark5[23:16],rgb5[23:16]),blend(dark5[15:8],rgb5[15:8]),blend(dark5[7:0],rgb5[7:0])};
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   enabled<=0;vs_last<=1;sumt1<=0;summ1<=0;sumb1<=0;sum2<=0;blur3<=0;
   rgb1<=0;rgb2<=0;rgb3<=0;rgb4<=0;rgb5<=0;gray1<=0;gray2<=0;gray3<=0;recolor4<=0;dark5<=0;
   vp<=0;dp<=0;pp<=0;lp<=0;sp<=0;out_vs<=0;out_de<=0;out_rgb<=0;
  end else begin
   vs_last<=vs;if(vs_last && !vs)enabled<=osd_enable;
   sumt1<={2'd0,t0}+{2'd0,t1}+{2'd0,t2};summ1<={2'd0,m0}+{2'd0,m1}+{2'd0,m2};sumb1<={2'd0,b0}+{2'd0,b1}+{2'd0,b2};
   sum2<={2'd0,sumt1}+{2'd0,summ1}+{2'd0,sumb1};blur3<=ninth[23:16];
   rgb1<=rgb;rgb2<=rgb1;rgb3<=rgb2;rgb4<=rgb3;rgb5<=rgb4;gray1<=gray;gray2<=gray1;gray3<=gray2;
   recolor4<={corrected(rgb3[23:16],gray3,blur3),corrected(rgb3[15:8],gray3,blur3),corrected(rgb3[7:0],gray3,blur3)};
   dark5<={darken(recolor4[23:16]),darken(recolor4[15:8]),darken(recolor4[7:0])};
   vp<={vp[3:0],vs};dp<={dp[3:0],de};pp<={pp[3:0],enabled && panel && good};lp<={lp[3:0],enabled && lit};sp<={sp[3:0],enabled && shade};
   out_vs<=vp[4];out_de<=dp[4];
   if(!dp[4])out_rgb<=0;else if(lp[4])out_rgb<=24'hffffff;
   else if(sp[4])out_rgb<=pp[4]?{1'b0,mixed[23:17],1'b0,mixed[15:9],1'b0,mixed[7:1]}:{1'b0,rgb5[23:17],1'b0,rgb5[15:9],1'b0,rgb5[7:1]};
   else out_rgb<=pp[4]?mixed:rgb5;
  end
 end
endmodule
'''
files['audio_visualizer.v']=r'''// Signed waveform, circular LUT RAM. Default avoids the bottom caption.
module audio_visualizer #(parameter [9:0] WIN_X=24,WIN_Y=344,WIN_W=256,WIN_H=80,parameter N=128)(
 input clk,rst,vs,de,input [9:0] x,y,input [23:0] rgb,input audio_valid,input signed [23:0] audio_left,input enable,
 output reg out_vs,out_de,output reg [23:0] out_rgb);
 localparam AW=$clog2(N),XS=$clog2(WIN_W)-$clog2(N);
 (* ram_style="dram" *) reg signed [7:0] hist[0:N-1];
 reg [AW-1:0] head,frame_head;reg [AW:0] count,frame_count;reg enabled,vs_last;
 wire [9:0] dx=x-WIN_X;wire [AW-1:0] column=dx>>XS,read_index=frame_head+column;
 wire available={1'b0,column}>=(N-frame_count);
 wire panel=(x>=WIN_X && {1'b0,x}<{1'b0,WIN_X}+WIN_W && y>=WIN_Y && {1'b0,y}<{1'b0,WIN_Y}+WIN_H);
 wire signed [7:0] value=hist[read_index];wire [7:0] magnitude=value[7]?(8'd0-value):value;
 (* dsp_style="no" *) wire [15:0] scale=magnitude*((WIN_H>>1)-2);
 wire [9:0] offset=scale>>7,centre=WIN_Y+(WIN_H>>1),sample_y=value[7]?centre+offset:centre-offset;
 reg [9:0] yy1,trace1;reg [23:0] rgb1;reg vs1,de1,panel1,known1;
 wire trace=known1 && (yy1==trace1 || yy1==trace1+1'b1),axis=yy1==centre;
 always @(posedge clk)if(!rst && audio_valid)hist[head]<=audio_left[23:16];
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   head<=0;frame_head<=0;count<=0;frame_count<=0;enabled<=0;vs_last<=1;yy1<=0;trace1<=0;rgb1<=0;
   vs1<=0;de1<=0;panel1<=0;known1<=0;out_vs<=0;out_de<=0;out_rgb<=0;
  end else begin
   if(audio_valid)begin head<=head+1'b1;if(count<N)count<=count+1'b1;end
   vs_last<=vs;if(vs_last && !vs)begin frame_head<=head;frame_count<=count;enabled<=enable;end
   yy1<=y;trace1<=sample_y;rgb1<=rgb;vs1<=vs;de1<=de;panel1<=enabled && panel;known1<=available;
   out_vs<=vs1;out_de<=de1;
   if(!de1)out_rgb<=0;else if(!panel1)out_rgb<=rgb1;
   else if(trace)out_rgb<={1'b0,rgb1[23:17],(8'd128+{1'b0,rgb1[15:9]}),(8'd96+{2'b0,rgb1[7:2]})};
   else if(axis)out_rgb<={2'b0,rgb1[23:18],8'd64,8'd72};
   else out_rgb<={1'b0,rgb1[23:17],1'b0,rgb1[15:9],1'b0,rgb1[7:1]};
  end
 end
endmodule
'''
for name,text in files.items():
 (R/'src/modules/video'/name).write_text(text,encoding='utf-8')
print('Wrote three modules; original pixel implementation preserved in backup')
