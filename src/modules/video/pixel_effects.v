// All modes have three registers of latency; causal Sobel centre (x-1,y-1).
(* dsp_style="yes" *) module pixel_effects #(parameter DEPTH=1024,parameter [7:0] EDGE_TH=80,parameter BRAM_WINDOW=0)(
 input clk,rst,vs,de,input [9:0] x,input [23:0] rgb,input [1:0] mode_sel,
 output reg out_vs,out_de,output reg [23:0] out_rgb,
 output reg [11:0] out_luma_sum,output reg [7:0] out_luma,
 output reg out_window_valid,out_sobel);
 function [15:0] weighted_luma;
  input [23:0] p;reg [15:0] v;
  begin
   v=p[23:16]*8'd77+p[15:8]*8'd150+p[7:0]*8'd29;weighted_luma=v;end
 endfunction
 function [23:0] heat;
  input [7:0] a;
  begin case(a[7:6])
   0:heat={8'd0,a[5:0],2'b00,8'hff};1:heat={8'd0,8'hff,(8'hff-{a[5:0],2'b00})};
   2:heat={a[5:0],2'b00,8'hff,8'd0};3:heat={8'hff,(8'hff-{a[5:0],2'b00}),8'd0};endcase end
 endfunction
 wire [15:0] raw_weighted=weighted_luma(rgb);
 wire [7:0] raw_gray=raw_weighted[15:8];
 // Exact complement: floor((255*256-S)/256), including fractional borrow.
 wire [7:0] inverted_gray=(8'd255-raw_gray)-(|raw_weighted[7:0]);
 // Exact 256-entry composition of heat() and weighted_luma().
 // Removes the second multiplier/adder chain from the Sobel/window path.
 // The original RGB transform, luma rounding and three-cycle latency stay exact.
 function [7:0] thermal_luma;
  input [7:0] value;
  begin case(value)
   8'd0:thermal_luma=8'd28;
   8'd1:thermal_luma=8'd31;
   8'd2:thermal_luma=8'd33;
   8'd3:thermal_luma=8'd35;
   8'd4:thermal_luma=8'd38;
   8'd5:thermal_luma=8'd40;
   8'd6:thermal_luma=8'd42;
   8'd7:thermal_luma=8'd45;
   8'd8:thermal_luma=8'd47;
   8'd9:thermal_luma=8'd49;
   8'd10:thermal_luma=8'd52;
   8'd11:thermal_luma=8'd54;
   8'd12:thermal_luma=8'd57;
   8'd13:thermal_luma=8'd59;
   8'd14:thermal_luma=8'd61;
   8'd15:thermal_luma=8'd64;
   8'd16:thermal_luma=8'd66;
   8'd17:thermal_luma=8'd68;
   8'd18:thermal_luma=8'd71;
   8'd19:thermal_luma=8'd73;
   8'd20:thermal_luma=8'd75;
   8'd21:thermal_luma=8'd78;
   8'd22:thermal_luma=8'd80;
   8'd23:thermal_luma=8'd82;
   8'd24:thermal_luma=8'd85;
   8'd25:thermal_luma=8'd87;
   8'd26:thermal_luma=8'd89;
   8'd27:thermal_luma=8'd92;
   8'd28:thermal_luma=8'd94;
   8'd29:thermal_luma=8'd96;
   8'd30:thermal_luma=8'd99;
   8'd31:thermal_luma=8'd101;
   8'd32:thermal_luma=8'd103;
   8'd33:thermal_luma=8'd106;
   8'd34:thermal_luma=8'd108;
   8'd35:thermal_luma=8'd110;
   8'd36:thermal_luma=8'd113;
   8'd37:thermal_luma=8'd115;
   8'd38:thermal_luma=8'd117;
   8'd39:thermal_luma=8'd120;
   8'd40:thermal_luma=8'd122;
   8'd41:thermal_luma=8'd124;
   8'd42:thermal_luma=8'd127;
   8'd43:thermal_luma=8'd129;
   8'd44:thermal_luma=8'd132;
   8'd45:thermal_luma=8'd134;
   8'd46:thermal_luma=8'd136;
   8'd47:thermal_luma=8'd139;
   8'd48:thermal_luma=8'd141;
   8'd49:thermal_luma=8'd143;
   8'd50:thermal_luma=8'd146;
   8'd51:thermal_luma=8'd148;
   8'd52:thermal_luma=8'd150;
   8'd53:thermal_luma=8'd153;
   8'd54:thermal_luma=8'd155;
   8'd55:thermal_luma=8'd157;
   8'd56:thermal_luma=8'd160;
   8'd57:thermal_luma=8'd162;
   8'd58:thermal_luma=8'd164;
   8'd59:thermal_luma=8'd167;
   8'd60:thermal_luma=8'd169;
   8'd61:thermal_luma=8'd171;
   8'd62:thermal_luma=8'd174;
   8'd63:thermal_luma=8'd176;
   8'd64:thermal_luma=8'd178;
   8'd65:thermal_luma=8'd177;
   8'd66:thermal_luma=8'd177;
   8'd67:thermal_luma=8'd176;
   8'd68:thermal_luma=8'd176;
   8'd69:thermal_luma=8'd176;
   8'd70:thermal_luma=8'd175;
   8'd71:thermal_luma=8'd175;
   8'd72:thermal_luma=8'd174;
   8'd73:thermal_luma=8'd174;
   8'd74:thermal_luma=8'd173;
   8'd75:thermal_luma=8'd173;
   8'd76:thermal_luma=8'd172;
   8'd77:thermal_luma=8'd172;
   8'd78:thermal_luma=8'd171;
   8'd79:thermal_luma=8'd171;
   8'd80:thermal_luma=8'd171;
   8'd81:thermal_luma=8'd170;
   8'd82:thermal_luma=8'd170;
   8'd83:thermal_luma=8'd169;
   8'd84:thermal_luma=8'd169;
   8'd85:thermal_luma=8'd168;
   8'd86:thermal_luma=8'd168;
   8'd87:thermal_luma=8'd167;
   8'd88:thermal_luma=8'd167;
   8'd89:thermal_luma=8'd166;
   8'd90:thermal_luma=8'd166;
   8'd91:thermal_luma=8'd166;
   8'd92:thermal_luma=8'd165;
   8'd93:thermal_luma=8'd165;
   8'd94:thermal_luma=8'd164;
   8'd95:thermal_luma=8'd164;
   8'd96:thermal_luma=8'd163;
   8'd97:thermal_luma=8'd163;
   8'd98:thermal_luma=8'd162;
   8'd99:thermal_luma=8'd162;
   8'd100:thermal_luma=8'd161;
   8'd101:thermal_luma=8'd161;
   8'd102:thermal_luma=8'd161;
   8'd103:thermal_luma=8'd160;
   8'd104:thermal_luma=8'd160;
   8'd105:thermal_luma=8'd159;
   8'd106:thermal_luma=8'd159;
   8'd107:thermal_luma=8'd158;
   8'd108:thermal_luma=8'd158;
   8'd109:thermal_luma=8'd157;
   8'd110:thermal_luma=8'd157;
   8'd111:thermal_luma=8'd157;
   8'd112:thermal_luma=8'd156;
   8'd113:thermal_luma=8'd156;
   8'd114:thermal_luma=8'd155;
   8'd115:thermal_luma=8'd155;
   8'd116:thermal_luma=8'd154;
   8'd117:thermal_luma=8'd154;
   8'd118:thermal_luma=8'd153;
   8'd119:thermal_luma=8'd153;
   8'd120:thermal_luma=8'd152;
   8'd121:thermal_luma=8'd152;
   8'd122:thermal_luma=8'd152;
   8'd123:thermal_luma=8'd151;
   8'd124:thermal_luma=8'd151;
   8'd125:thermal_luma=8'd150;
   8'd126:thermal_luma=8'd150;
   8'd127:thermal_luma=8'd149;
   8'd128:thermal_luma=8'd149;
   8'd129:thermal_luma=8'd150;
   8'd130:thermal_luma=8'd151;
   8'd131:thermal_luma=8'd153;
   8'd132:thermal_luma=8'd154;
   8'd133:thermal_luma=8'd155;
   8'd134:thermal_luma=8'd156;
   8'd135:thermal_luma=8'd157;
   8'd136:thermal_luma=8'd159;
   8'd137:thermal_luma=8'd160;
   8'd138:thermal_luma=8'd161;
   8'd139:thermal_luma=8'd162;
   8'd140:thermal_luma=8'd163;
   8'd141:thermal_luma=8'd165;
   8'd142:thermal_luma=8'd166;
   8'd143:thermal_luma=8'd167;
   8'd144:thermal_luma=8'd168;
   8'd145:thermal_luma=8'd169;
   8'd146:thermal_luma=8'd171;
   8'd147:thermal_luma=8'd172;
   8'd148:thermal_luma=8'd173;
   8'd149:thermal_luma=8'd174;
   8'd150:thermal_luma=8'd175;
   8'd151:thermal_luma=8'd177;
   8'd152:thermal_luma=8'd178;
   8'd153:thermal_luma=8'd179;
   8'd154:thermal_luma=8'd180;
   8'd155:thermal_luma=8'd181;
   8'd156:thermal_luma=8'd183;
   8'd157:thermal_luma=8'd184;
   8'd158:thermal_luma=8'd185;
   8'd159:thermal_luma=8'd186;
   8'd160:thermal_luma=8'd187;
   8'd161:thermal_luma=8'd189;
   8'd162:thermal_luma=8'd190;
   8'd163:thermal_luma=8'd191;
   8'd164:thermal_luma=8'd192;
   8'd165:thermal_luma=8'd193;
   8'd166:thermal_luma=8'd195;
   8'd167:thermal_luma=8'd196;
   8'd168:thermal_luma=8'd197;
   8'd169:thermal_luma=8'd198;
   8'd170:thermal_luma=8'd199;
   8'd171:thermal_luma=8'd201;
   8'd172:thermal_luma=8'd202;
   8'd173:thermal_luma=8'd203;
   8'd174:thermal_luma=8'd204;
   8'd175:thermal_luma=8'd205;
   8'd176:thermal_luma=8'd207;
   8'd177:thermal_luma=8'd208;
   8'd178:thermal_luma=8'd209;
   8'd179:thermal_luma=8'd210;
   8'd180:thermal_luma=8'd211;
   8'd181:thermal_luma=8'd213;
   8'd182:thermal_luma=8'd214;
   8'd183:thermal_luma=8'd215;
   8'd184:thermal_luma=8'd216;
   8'd185:thermal_luma=8'd217;
   8'd186:thermal_luma=8'd219;
   8'd187:thermal_luma=8'd220;
   8'd188:thermal_luma=8'd221;
   8'd189:thermal_luma=8'd222;
   8'd190:thermal_luma=8'd224;
   8'd191:thermal_luma=8'd225;
   8'd192:thermal_luma=8'd226;
   8'd193:thermal_luma=8'd223;
   8'd194:thermal_luma=8'd221;
   8'd195:thermal_luma=8'd219;
   8'd196:thermal_luma=8'd216;
   8'd197:thermal_luma=8'd214;
   8'd198:thermal_luma=8'd212;
   8'd199:thermal_luma=8'd209;
   8'd200:thermal_luma=8'd207;
   8'd201:thermal_luma=8'd205;
   8'd202:thermal_luma=8'd202;
   8'd203:thermal_luma=8'd200;
   8'd204:thermal_luma=8'd197;
   8'd205:thermal_luma=8'd195;
   8'd206:thermal_luma=8'd193;
   8'd207:thermal_luma=8'd190;
   8'd208:thermal_luma=8'd188;
   8'd209:thermal_luma=8'd186;
   8'd210:thermal_luma=8'd183;
   8'd211:thermal_luma=8'd181;
   8'd212:thermal_luma=8'd179;
   8'd213:thermal_luma=8'd176;
   8'd214:thermal_luma=8'd174;
   8'd215:thermal_luma=8'd172;
   8'd216:thermal_luma=8'd169;
   8'd217:thermal_luma=8'd167;
   8'd218:thermal_luma=8'd165;
   8'd219:thermal_luma=8'd162;
   8'd220:thermal_luma=8'd160;
   8'd221:thermal_luma=8'd158;
   8'd222:thermal_luma=8'd155;
   8'd223:thermal_luma=8'd153;
   8'd224:thermal_luma=8'd151;
   8'd225:thermal_luma=8'd148;
   8'd226:thermal_luma=8'd146;
   8'd227:thermal_luma=8'd144;
   8'd228:thermal_luma=8'd141;
   8'd229:thermal_luma=8'd139;
   8'd230:thermal_luma=8'd137;
   8'd231:thermal_luma=8'd134;
   8'd232:thermal_luma=8'd132;
   8'd233:thermal_luma=8'd130;
   8'd234:thermal_luma=8'd127;
   8'd235:thermal_luma=8'd125;
   8'd236:thermal_luma=8'd122;
   8'd237:thermal_luma=8'd120;
   8'd238:thermal_luma=8'd118;
   8'd239:thermal_luma=8'd115;
   8'd240:thermal_luma=8'd113;
   8'd241:thermal_luma=8'd111;
   8'd242:thermal_luma=8'd108;
   8'd243:thermal_luma=8'd106;
   8'd244:thermal_luma=8'd104;
   8'd245:thermal_luma=8'd101;
   8'd246:thermal_luma=8'd99;
   8'd247:thermal_luma=8'd97;
   8'd248:thermal_luma=8'd94;
   8'd249:thermal_luma=8'd92;
   8'd250:thermal_luma=8'd90;
   8'd251:thermal_luma=8'd87;
   8'd252:thermal_luma=8'd85;
   8'd253:thermal_luma=8'd83;
   8'd254:thermal_luma=8'd80;
   8'd255:thermal_luma=8'd78;
   default:thermal_luma=8'd0;
  endcase end
 endfunction
 wire [15:0] heat_weighted={thermal_luma(raw_gray),8'd0};
 wire [7:0] stored_gray;
 wire [7:0] gray,t0,t1,t2,m0,m1,m2,b0,b1,b2;wire good;
 generate if(BRAM_WINDOW)begin:bram_window
  video_luma_window_bram #(.DEPTH(DEPTH)) window(clk,rst,vs,de,x,stored_gray,
   gray,t0,t1,t2,m0,m1,m2,b0,b1,b2,good);
 end else begin:lut_window
  video_luma_window #(.DEPTH(DEPTH),.EXTERNAL_LUMA(1)) window(clk,rst,vs,de,x,rgb,
   gray,t0,t1,t2,m0,m1,m2,b0,b1,b2,good,stored_gray);
 end endgenerate
 reg [10:0] xp1,xn1,yp1,yn1;reg [11:0] mag2;
 reg [23:0] rgb1,rgb2;reg [7:0] gray1,gray2,stored1,stored2;
 reg vs1,vs2,de1,de2,w1,w2,vs_last;reg [1:0] mode1,mode2,frame_mode;
 assign stored_gray=(frame_mode==1)?inverted_gray:(frame_mode==3)?heat_weighted[15:8]:raw_gray;
 reg [9:0] sumt1,summ1,sumb1;reg [11:0] sum2;
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
   sumt1<=0;summ1<=0;sumb1<=0;sum2<=0;out_luma_sum<=0;out_luma<=0;out_window_valid<=0;out_sobel<=0;
   rgb1<=0;rgb2<=0;gray1<=0;gray2<=0;stored1<=0;stored2<=0;vs1<=0;vs2<=0;de1<=0;de2<=0;w1<=0;w2<=0;out_vs<=0;out_de<=0;out_rgb<=0;
  end else begin
   vs_last<=vs;if(vs_last && !vs)frame_mode<=mode_sel;
   xp1<=xp;xn1<=xn;yp1<=yp;yn1<=yn;mag2<={1'b0,ax}+{1'b0,ay};
   sumt1<={2'd0,t0}+{2'd0,t1}+{2'd0,t2};summ1<={2'd0,m0}+{2'd0,m1}+{2'd0,m2};sumb1<={2'd0,b0}+{2'd0,b1}+{2'd0,b2};
   sum2<={2'd0,sumt1}+{2'd0,summ1}+{2'd0,sumb1};out_luma_sum<=sum2;
   out_window_valid<=w2;out_sobel<=mode2==2;
   rgb1<=rgb;rgb2<=rgb1;gray1<=raw_gray;gray2<=gray1;stored1<=stored_gray;stored2<=stored1;vs1<=vs;vs2<=vs1;de1<=de;de2<=de1;w1<=good;w2<=w1;
   mode1<=frame_mode;mode2<=mode1;out_vs<=vs2;out_de<=de2;
   if(!de2)out_rgb<=0;
   else case(mode2)
    0:out_rgb<=rgb2;1:out_rgb<=~rgb2;
    2:out_rgb<=(w2 && mag2>{4'd0,EDGE_TH})?24'hffffff:24'd0;
    3:out_rgb<=thermal;
   endcase
   out_luma<=(mode2==2)?((w2 && mag2>{4'd0,EDGE_TH})?8'hff:8'd0):stored2;
  end
 end
endmodule

// TD ram_style="dram" means LUT distributed RAM, never SDRAM/BRAM.
// No RAM reset/initialization. Mask the first two rows/columns EVERY frame.
module video_luma_window #(parameter DEPTH=1024,parameter EXTERNAL_LUMA=0)(
 input clk,rst,vs,de,input [9:0] x,input [23:0] rgb,
 output [7:0] gray,t0,t1,t2,m0,m1,m2,b0,b1,b2,output valid,input [7:0] external_luma);
 wire [15:0] r={8'd0,rgb[23:16]},g={8'd0,rgb[15:8]},b={8'd0,rgb[7:0]};
 wire [15:0] weighted=(r<<6)+(r<<3)+(r<<2)+r+(g<<7)+(g<<4)+(g<<2)+(g<<1)+(b<<4)+(b<<3)+(b<<2)+b;
 assign gray=EXTERNAL_LUMA?external_luma:weighted[15:8];
 // Split the last partial bank explicitly: TD otherwise rounds 800 to 1024.
 localparam BANKS=(DEPTH+255)/256;
 wire [7:0] bank1[0:BANKS-1],bank2[0:BANKS-1];
 wire ok=x<DEPTH;
 genvar bank;
 generate for(bank=0;bank<BANKS;bank=bank+1)begin:line_bank
  localparam LEN=((DEPTH-bank*256)<256)?(DEPTH-bank*256):256;
  localparam AW=(LEN<2)?1:$clog2(LEN);
  (* ram_style="dram" *) reg [7:0] row1[0:LEN-1];
  (* ram_style="dram" *) reg [7:0] row2[0:LEN-1];
  wire [AW-1:0] address=x[AW-1:0];
  assign bank1[bank]=row1[address];assign bank2[bank]=row2[address];
  always @(posedge clk)if(!rst && vs && de && ok && x[9:8]==bank)begin
   row1[address]<=gray;row2[address]<=bank1[bank];
  end
 end endgenerate
 wire [7:0] p1=ok?bank1[x[9:8]]:8'd0,p2=ok?bank2[x[9:8]]:8'd0;
 reg [7:0] ta,tb,ma,mb,ba,bb;reg de_last;reg [1:0] rows;
 assign t0=tb;assign t1=ta;assign t2=p2;assign m0=mb;assign m1=ma;assign m2=p1;
 assign b0=bb;assign b1=ba;assign b2=gray;
 assign valid=de && vs && ok && rows==2 && x>=2;
 always @(posedge clk or posedge rst)begin
  if(rst)begin ta<=0;tb<=0;ma<=0;mb<=0;ba<=0;bb<=0;rows<=0;de_last<=0;end
  else begin
   de_last<=de;if(!vs)rows<=0;else if(de_last && !de && rows!=2)rows<=rows+1'b1;
   if(!de || !vs)begin ta<=0;tb<=0;ma<=0;mb<=0;ba<=0;bb<=0;end
   else begin ta<=p2;tb<=(x==0)?8'd0:ta;ma<=p1;mb<=(x==0)?8'd0:ma;ba<=gray;bb<=(x==0)?8'd0:ba;end
  end
 end
endmodule
