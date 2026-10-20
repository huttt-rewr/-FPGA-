// Six registers: luma box blur -> retained chroma -> dark glass -> shadow/text.
module glass_osd #(parameter DEPTH=1024,parameter SHARED_LUMA=0,parameter [9:0] WIN_X=120,WIN_Y=80,WIN_W=400,WIN_H=320)(
 input clk,rst,vs,de,input [9:0] x,y,input [23:0] rgb,input [7:0] ascii_char,input osd_enable,
 output reg out_vs,out_de,output reg [23:0] out_rgb,
 input [11:0] shared_sum,input [7:0] shared_luma,input shared_valid,shared_sobel);
 // Only the panel and two causal left neighbours need storage. At SVGA this
 // is at most 503 physical columns, instead of caching 1024 unseen columns.
 localparam CACHE_DEPTH=(DEPTH<512)?DEPTH:512;
 wire selected=(x>=WIN_X-2 && {1'b0,x}<{1'b0,WIN_X}+WIN_W);
 reg [9:0] cache_x;
 always @(posedge clk or posedge rst)begin
  if(rst)cache_x<=0;else if(!vs || !de || !selected)cache_x<=0;else cache_x<=cache_x+1'b1;
 end
 wire [7:0] gray,t0,t1,t2,m0,m1,m2,b0,b1,b2;wire good;
 generate if(!SHARED_LUMA)begin:independent
  video_luma_window #(.DEPTH(CACHE_DEPTH)) window(clk,rst,vs,de && selected,cache_x,rgb,gray,t0,t1,t2,m0,m1,m2,b0,b1,b2,good,8'd0);
 end else begin:shared
  // Non-Sobel modes reuse the exact transformed-luma 3x3 sum from the pixel
  // filter. Sobel output is binary, so its own two rows need ONE bit/column.
  (* ram_style="dram" *) reg row1[0:CACHE_DEPTH-1];
  (* ram_style="dram" *) reg row2[0:CACHE_DEPTH-1];
  wire p1=row1[cache_x],p2=row2[cache_x];
  reg ta,tb,ma,mb,ba,bb;reg de_last;reg [1:0] rows;
  wire d=de && selected;
  always @(posedge clk)if(!rst && vs && d && shared_sobel)begin row1[cache_x]<=rgb[0];row2[cache_x]<=p1;end
  always @(posedge clk or posedge rst)begin
   if(rst)begin ta<=0;tb<=0;ma<=0;mb<=0;ba<=0;bb<=0;rows<=0;de_last<=0;end
   else begin
    de_last<=d;if(!vs)rows<=0;else if(de_last && !d && rows!=2)rows<=rows+1'b1;
    if(!vs || !d)begin ta<=0;tb<=0;ma<=0;mb<=0;ba<=0;bb<=0;end
    else begin ta<=p2;tb<=ta;ma<=p1;mb<=ma;ba<=rgb[0];bb<=ba;end
   end
  end
  assign gray=shared_luma;
  assign good=shared_sobel?(d && rows==2 && cache_x>=2):shared_valid;
  assign t0={8{tb}};assign t1={8{ta}};assign t2={8{p2}};
  assign m0={8{mb}};assign m1={8{ma}};assign m2={8{p1}};
  assign b0={8{bb}};assign b1={8{ba}};assign b2=rgb[7:0];
 end endgenerate
 wire panel=(x>=WIN_X && {1'b0,x}<{1'b0,WIN_X}+WIN_W && y>=WIN_Y && {1'b0,y}<{1'b0,WIN_Y}+WIN_H);
 wire [9:0] tx=x-WIN_X-10'd16,ty=y-WIN_Y-10'd16,sx=tx-10'd2,sy=ty-10'd2;
 wire [7:0] glyph,shadow_glyph;
 wire [7:0] external_glyph,external_shadow,title_glyph,title_shadow;
 osd_char_rom font(ascii_char,ty[4:1],external_glyph);
 osd_char_rom shadow_font(ascii_char,sy[4:1],external_shadow);
 glass_title_row title_font(tx[9:3],ty[4:1],title_glyph);
 glass_title_row title_shadow_font(sx[9:3],sy[4:1],title_shadow);
 assign glyph=ascii_char==0?title_glyph:external_glyph;
 assign shadow_glyph=ascii_char==0?title_shadow:external_shadow;
 wire text_band=panel && x>=WIN_X+16 && {1'b0,x}<{1'b0,WIN_X}+WIN_W-16 && y>=WIN_Y+16 && y<WIN_Y+30;
 wire shadow_band=panel && x>=WIN_X+18 && {1'b0,x}<{1'b0,WIN_X}+WIN_W-14 && y>=WIN_Y+18 && y<WIN_Y+32;
 wire lit=text_band && tx[2:0]<5 && glyph[4-tx[2:0]],shade=shadow_band && sx[2:0]<5 && shadow_glyph[4-sx[2:0]];
 reg enabled,vs_last;reg [9:0] sumt1,summ1,sumb1;reg [11:0] sum2,shared_sum1;reg sobel1;
 wire [24:0] s={13'd0,sum2};
 wire [24:0] ninth=(s<<13)-(s<<10)+(s<<7)-(s<<4)+(s<<1);
 // floor(sum/9), exact for 0..2295, using reciprocal/shift.
 reg [7:0] blur3,gray1,gray2,gray3;reg [23:0] rgb1,rgb2,rgb3,rgb4,rgb5,recolor4,dark5;
 reg [4:0] vp,dp,pp,lp,sp;
 function [7:0] corrected;
  input [7:0] c;input signed [8:0] delta;reg signed [9:0] v;
  begin v=$signed({2'd0,c})+delta;corrected=v[9]?8'd0:(v[8]?8'd255:v[7:0]);end
 endfunction
 wire signed [8:0] luma_delta=$signed({1'b0,blur3})-$signed({1'b0,gray3});
 (* dsp_style="yes" *) function [15:0] times153;input [7:0] c;reg [15:0] v;begin v={8'd0,c};times153=c*8'd153;end endfunction
 function [7:0] darken;input [7:0] c;reg [15:0] p;begin p=times153(c);darken=p[15:8];end endfunction
 function [7:0] blend;input [7:0] a,b;reg [15:0] v,w;begin w={8'd0,b};v=times153(a)+b*8'd103;blend=v[15:8];end endfunction
 wire [23:0] mixed={blend(dark5[23:16],rgb5[23:16]),blend(dark5[15:8],rgb5[15:8]),blend(dark5[7:0],rgb5[7:0])};
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   enabled<=0;vs_last<=1;sumt1<=0;summ1<=0;sumb1<=0;sum2<=0;blur3<=0;shared_sum1<=0;sobel1<=0;
   rgb1<=0;rgb2<=0;rgb3<=0;rgb4<=0;rgb5<=0;gray1<=0;gray2<=0;gray3<=0;recolor4<=0;dark5<=0;
   vp<=0;dp<=0;pp<=0;lp<=0;sp<=0;out_vs<=0;out_de<=0;out_rgb<=0;
  end else begin
   vs_last<=vs;if(vs_last && !vs)enabled<=osd_enable;
   sumt1<={2'd0,t0}+{2'd0,t1}+{2'd0,t2};summ1<={2'd0,m0}+{2'd0,m1}+{2'd0,m2};sumb1<={2'd0,b0}+{2'd0,b1}+{2'd0,b2};
   shared_sum1<=shared_sum;sobel1<=shared_sobel;
   sum2<=(SHARED_LUMA && !sobel1)?shared_sum1:({2'd0,sumt1}+{2'd0,summ1}+{2'd0,sumb1});blur3<=ninth[23:16];
   rgb1<=rgb;rgb2<=rgb1;rgb3<=rgb2;rgb4<=rgb3;rgb5<=rgb4;gray1<=gray;gray2<=gray1;gray3<=gray2;
   recolor4<={corrected(rgb3[23:16],luma_delta),corrected(rgb3[15:8],luma_delta),corrected(rgb3[7:0],luma_delta)};
   dark5<={darken(recolor4[23:16]),darken(recolor4[15:8]),darken(recolor4[7:0])};
   vp<={vp[3:0],vs};dp<={dp[3:0],de};pp<={pp[3:0],enabled && panel && good};lp<={lp[3:0],enabled && lit};sp<={sp[3:0],enabled && shade};
   out_vs<=vp[4];out_de<=dp[4];
   if(!dp[4])out_rgb<=0;else if(lp[4])out_rgb<=24'hffffff;
   else if(sp[4])out_rgb<=pp[4]?{1'b0,mixed[23:17],1'b0,mixed[15:9],1'b0,mixed[7:1]}:{1'b0,rgb5[23:17],1'b0,rgb5[15:9],1'b0,rgb5[7:1]};
   else out_rgb<=pp[4]?mixed:rgb5;
  end
 end
endmodule

// Constant-character ROM instances let TD prune unused ASCII decoder branches.
// Reuses the existing glyph definitions; no new font data or memory blocks.
module glass_title_row(input [6:0] column,input [3:0] row,output reg [7:0] bits);
 wire [7:0] f,p,g,a,m,e,d,i;
 osd_char_rom font_f(8'h46,row,f);osd_char_rom font_p(8'h50,row,p);
 osd_char_rom font_g(8'h47,row,g);osd_char_rom font_a(8'h41,row,a);
 osd_char_rom font_m(8'h4d,row,m);osd_char_rom font_e(8'h45,row,e);
 osd_char_rom font_d(8'h44,row,d);osd_char_rom font_i(8'h49,row,i);
 always @*case(column)
  0:bits=f;1:bits=p;2:bits=g;3,9:bits=a;5:bits=m;6:bits=e;7:bits=d;8:bits=i;
  default:bits=0;
 endcase
endmodule
