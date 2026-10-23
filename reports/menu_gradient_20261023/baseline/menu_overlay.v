// Chinese menu in the common logical 640x480 viewport. Two-cycle RGB/VS/DE.
module menu_overlay(
 input clk,input rst,input vs,input de,input [9:0] x,y,input [23:0] rgb,
 input menu_open,input [2:0] menu_item,input edit_mode,input auto_play,
 input signed [7:0] brightness,input [3:0] contrast,input [4:0] volume,
 input mute,input gamma_enable,input debug_enable,
 output reg out_vs,output reg out_de,output reg [23:0] out_rgb);
 reg vs_last,opened,editing,playing,muted,gamma_on,debug_on;
 reg [2:0] selected;
 reg negative;
 reg [3:0] bright_tens,bright_units,vol_tens,vol_units,contrast_q;
 wire [7:0] magnitude=brightness[7]?-brightness:brightness;
 function [7:0] decimal2;
  input [7:0] value;integer i;reg [7:0] bcd;
  begin
   bcd=0;
   for(i=7;i>=0;i=i-1)begin
    if(bcd[3:0]>=5)bcd[3:0]=bcd[3:0]+4'd3;
    if(bcd[7:4]>=5)bcd[7:4]=bcd[7:4]+4'd3;
    bcd={bcd[6:0],value[i]};
   end
   decimal2=bcd;
  end
 endfunction
 always @(posedge clk)begin
  if(rst)begin
   vs_last<=1;opened<=0;selected<=0;editing<=0;playing<=0;muted<=0;
   gamma_on<=0;debug_on<=0;negative<=0;bright_tens<=0;bright_units<=0;
   vol_tens<=0;vol_units<=0;contrast_q<=4;
  end else begin
   vs_last<=vs;
   if(vs_last && !vs)begin
    opened<=menu_open;selected<=menu_item;editing<=edit_mode;
    playing<=auto_play;muted<=mute;gamma_on<=gamma_enable;debug_on<=debug_enable;
    negative<=brightness[7];{bright_tens,bright_units}<=decimal2(magnitude);
    {vol_tens,vol_units}<=decimal2({3'b0,volume});contrast_q<=contrast;
   end
  end
 end
 function [6:0] label_char;
  input [2:0] item;input [3:0] col;
  begin
   label_char=73;
   case(item)
    0:case(col)0:label_char=34;1:label_char=35;endcase
    1:case(col)0:label_char=38;1:label_char=39;endcase
    2:case(col)0:label_char=40;1:label_char=41;2:label_char=39;endcase
    3:case(col)0:label_char=42;1:label_char=43;endcase
    4:case(col)0:label_char=44;1:label_char=45;endcase
    5:case(col)0:label_char=46;1:label_char=44;endcase
    6:case(col)0:label_char=47;1:label_char=48;endcase
    7:case(col)0:label_char=49;1:label_char=50;endcase
   endcase
  end
 endfunction
 reg [6:0] char_idx;
 reg [3:0] glyph_row,column;
 reg panel,selected_band,selected_text;
 reg [9:0] local_x,local_y;
 reg [3:0] cell_col;
 reg [2:0] item;
 integer k;
 always @* begin
  panel=opened && x>=48 && x<592 && y>=16 && y<448;
  selected_band=0;selected_text=0;char_idx=73;glyph_row=0;column=0;
  local_x=0;local_y=0;cell_col=0;item=0;
  if(x>=64 && x<96 && y>=40 && y<56)begin
   local_x=x-64;local_y=y-40;glyph_row=local_y[3:0];column=local_x[3:0];
   char_idx=local_x[4]?7'd33:7'd32;
  end
  for(k=0;k<8;k=k+1)begin
   if(y>=88+k*40 && y<120+k*40)begin
    item=k;local_y=y-(88+k*40);
    selected_band=(selected==k);selected_text=selected_band;
    if(selected_band)begin
     glyph_row=local_y[4:1];local_x=x-64;column=local_x[4:1];cell_col=local_x[8:5];
     if(x>=64 && x<160)char_idx=label_char(item,cell_col);
     else if(x>=288 && x<416)begin
      local_x=x-288;column=local_x[4:1];cell_col=local_x[8:5];
      case(item)
       0:case(cell_col)0:char_idx=playing?34:36;1:char_idx=playing?35:37;default:char_idx=73;endcase
       1:case(cell_col)0:char_idx=negative?75:74;1:char_idx=63+bright_tens;2:char_idx=63+bright_units;default:char_idx=73;endcase
       2:if(cell_col==0)char_idx=63+contrast_q;
       3:if(cell_col==0)char_idx=gamma_on?53:54;
       4:case(cell_col)0:char_idx=63+vol_tens;1:char_idx=63+vol_units;default:char_idx=73;endcase
       5:if(cell_col==0)char_idx=muted?53:54;
       6:if(cell_col==0)char_idx=debug_on?53:54;
       default:char_idx=73;
      endcase
     end else if(x>=480 && x<544)begin
      local_x=x-480;column=local_x[4:1];
      char_idx=editing?(local_x[5]?56:55):(local_x[5]?60:59);
     end
    end else if(local_y<16 && x>=64 && x<112)begin
     local_x=x-64;column=local_x[3:0];glyph_row=local_y[3:0];
     char_idx=label_char(item,{2'b0,local_x[5:4]});
    end
   end
  end
  if(x>=64 && x<288 && y>=416 && y<432)begin
   local_x=x-64;local_y=y-416;column=local_x[3:0];glyph_row=local_y[3:0];
   case(local_x[7:4])
    0:char_idx=57;1:char_idx=58;2:char_idx=73;3:char_idx=59;4:char_idx=60;
    5:char_idx=73;6:char_idx=55;7:char_idx=56;8:char_idx=73;
    9:char_idx=61;10:char_idx=62;11:char_idx=49;12:char_idx=50;default:char_idx=73;
   endcase
  end
 end
 wire [15:0] glyph;
 zh_font_rom #(.BANK(2)) font(.clk(clk),.char_idx(char_idx),.row(glyph_row),.bits(glyph));
 reg v1,d1,panel1,band1,highlight1;reg [3:0] column1;reg [23:0] rgb1;
 always @(posedge clk)begin
  if(rst)begin
   v1<=0;d1<=0;panel1<=0;band1<=0;highlight1<=0;column1<=0;rgb1<=0;
   out_vs<=0;out_de<=0;out_rgb<=0;
  end else begin
   v1<=vs;d1<=de;panel1<=panel;band1<=selected_band;highlight1<=selected_text;
   column1<=column;rgb1<=rgb;
   out_vs<=v1;out_de<=d1;
   if(!d1)out_rgb<=0;
   else if(!panel1)out_rgb<=rgb1;
   else if(glyph[15-column1])out_rgb<=highlight1?24'hffff00:24'h808080;
   else out_rgb<=band1?24'h243040:24'h101820;
  end
 end
endmodule
