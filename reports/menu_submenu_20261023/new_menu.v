// Narrow solid menu, two levels, two-second popup. RGB/VS/DE latency: 2 clocks.
module menu_overlay #(parameter VGA_CLOCK_HZ=25000000,parameter SVGA_CLOCK_HZ=40000000,
 parameter POPUP_SECONDS=2)(
 input clk,input rst,input vs,input de,input [9:0] x,y,input [23:0] rgb,
 input menu_open,input [2:0] menu_item,input edit_mode,input auto_play,
 input signed [7:0] brightness,input [3:0] contrast,input [4:0] volume,
 input mute,input gamma_enable,input debug_enable,
 output reg out_vs,output reg out_de,output reg [23:0] out_rgb,
 input mode_800);
 localparam VGA_TICKS=VGA_CLOCK_HZ*POPUP_SECONDS;
 localparam SVGA_TICKS=SVGA_CLOCK_HZ*POPUP_SECONDS;
 localparam MAX_TICKS=(VGA_TICKS>SVGA_TICKS)?VGA_TICKS:SVGA_TICKS;
 localparam TIMER_BITS=(MAX_TICKS<2)?1:$clog2(MAX_TICKS+1);
 reg [TIMER_BITS-1:0] popup_ticks;
 reg signed [7:0] previous_brightness;
 reg [3:0] previous_contrast;
 reg previous_menu;
 reg vs_last,opened,editing,playing,muted,gamma_on,debug_on,popup_visible;
 reg [2:0] selected;
 reg negative;
 reg [3:0] bright_tens,bright_units,vol_tens,vol_units,contrast_q;
 wire [7:0] magnitude=brightness[7]?-brightness:brightness;
 wire external_change=(brightness!=previous_brightness || contrast!=previous_contrast)
                      && !menu_open && !previous_menu;
 wire [TIMER_BITS-1:0] popup_duration=mode_800?SVGA_TICKS:VGA_TICKS;
 // Observe shared registers. Suppress menu edits, including the closing edge.
 always @(posedge clk)begin
  if(rst)begin
   popup_ticks<=0;previous_brightness<=0;previous_contrast<=4;previous_menu<=0;
  end else begin
   previous_brightness<=brightness;previous_contrast<=contrast;previous_menu<=menu_open;
   if(menu_open)popup_ticks<=0;
   else if(external_change)popup_ticks<=popup_duration;
   else if(popup_ticks!=0)popup_ticks<=popup_ticks-1'b1;
  end
 end
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
   vol_tens<=0;vol_units<=0;contrast_q<=4;popup_visible<=0;
  end else begin
   vs_last<=vs;
   if(vs_last && !vs)begin
    opened<=menu_open;selected<=menu_item;editing<=edit_mode;
    playing<=auto_play;muted<=mute;gamma_on<=gamma_enable;debug_on<=debug_enable;
    negative<=brightness[7];{bright_tens,bright_units}<=decimal2(magnitude);
    {vol_tens,vol_units}<=decimal2({3'b0,volume});contrast_q<=contrast;
    popup_visible<=!menu_open && (external_change || popup_ticks!=0);
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
 function [6:0] value_char;
  input [2:0] item;input [3:0] col;
  begin
   value_char=73;
   case(item)
    0:case(col)0:value_char=playing?34:36;1:value_char=playing?35:37;endcase
    1:case(col)0:value_char=negative?75:74;1:value_char=63+bright_tens;2:value_char=63+bright_units;endcase
    2:if(col==0)value_char=63+contrast_q;
    3:if(col==0)value_char=gamma_on?53:54;
    4:case(col)0:value_char=63+vol_tens;1:value_char=63+vol_units;endcase
    5:if(col==0)value_char=muted?53:54;
    6:if(col==0)value_char=debug_on?53:54;
   endcase
  end
 endfunction
 reg [6:0] char_idx;
 reg [3:0] glyph_row,column;
 reg panel,selected_band,selected_text;
 reg [9:0] local_x,local_y;
 reg [3:0] cell_col;
 integer k;
 always @* begin
  panel=0;selected_band=0;selected_text=0;char_idx=73;glyph_row=0;column=0;
  local_x=0;local_y=0;cell_col=0;
  if(opened)begin
   panel=x<128 && y>=16 && y<448;
   if(x>=8 && x<40 && y>=40 && y<56)begin
    local_x=x-8;local_y=y-40;glyph_row=local_y[3:0];column=local_x[3:0];
    char_idx=local_x[4]?7'd33:7'd32;
   end
   if(!editing)begin
    for(k=0;k<8;k=k+1)begin
     if(y>=88+k*40 && y<120+k*40)begin
      local_y=y-(88+k*40);selected_band=(selected==k);selected_text=selected_band;
      local_x=x-8;
      if(selected_band && x>=8 && x<104)begin
       glyph_row=local_y[4:1];column=local_x[4:1];
       char_idx=label_char(k,local_x[8:5]);
      end else if(!selected_band && local_y<16 && x>=8 && x<56)begin
       glyph_row=local_y[3:0];column=local_x[3:0];
       char_idx=label_char(k,{2'b0,local_x[5:4]});
      end
     end
    end
   end else begin
    // Submenu replaces the list, stacking doubled label and current value.
    if(x>=8 && x<104 && ((y>=88 && y<120)||(y>=144 && y<176)))begin
     local_x=x-8;local_y=y>=144?y-144:y-88;
     column=local_x[4:1];glyph_row=local_y[4:1];cell_col=local_x[8:5];
     selected_band=1;selected_text=1;
     char_idx=y>=144?value_char(selected,cell_col):label_char(selected,cell_col);
    end
    if(x>=8 && x<40 && ((y>=208 && y<224)||(y>=240 && y<256)))begin
     local_x=x-8;local_y=y>=240?y-240:y-208;
     column=local_x[3:0];glyph_row=local_y[3:0];
     char_idx=y>=240?(local_x[4]?56:55):(local_x[4]?58:57);
    end
   end
   if(x>=8 && x<72 && y>=416 && y<432)begin
    local_x=x-8;local_y=y-416;column=local_x[3:0];glyph_row=local_y[3:0];
    case(local_x[5:4])0:char_idx=61;1:char_idx=62;2:char_idx=49;3:char_idx=50;endcase
   end
  end else if(popup_visible)begin
   panel=x>=8 && x<152 && y>=8 && y<64;
   if(((y>=16 && y<32)||(y>=40 && y<56)) && x>=16 && x<144)begin
    local_x=x-16;local_y=y>=40?y-40:y-16;
    column=local_x[3:0];glyph_row=local_y[3:0];cell_col=local_x[7:4];
    if(cell_col<3)char_idx=label_char(y>=40 ? 3'd2 : 3'd1,cell_col);
    else if(cell_col==3)char_idx=76;
    else char_idx=value_char(y>=40 ? 3'd2 : 3'd1,cell_col-4);
   end
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
   else if(glyph[15-column1])out_rgb<=highlight1?24'hffff00:24'hc0c8d0;
   else out_rgb<=band1?24'h243040:24'h101820;
  end
 end
endmodule
