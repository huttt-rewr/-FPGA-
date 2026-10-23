`timescale 1ns/1ps
module tb_menu_overlay;
 reg clk=0,rst=1,vs=1,de=0,opened=0,editing=0,playing=0,mute=0,gamma=0,debug=0;
 always #5 clk=~clk;
 reg [9:0] x=0,y=0;reg [23:0] rgb=24'h305070;
 reg [2:0] item=0;reg signed [7:0] brightness=0;reg [3:0] contrast=4;reg [4:0] volume=8;
 wire ov,od;wire [23:0] result;
 menu_overlay dut(.clk(clk),.rst(rst),.vs(vs),.de(de),.x(x),.y(y),.rgb(rgb),
  .menu_open(opened),.menu_item(item),.edit_mode(editing),.auto_play(playing),
  .brightness(brightness),.contrast(contrast),.volume(volume),.mute(mute),
  .gamma_enable(gamma),.debug_enable(debug),.out_vs(ov),.out_de(od),.out_rgb(result),.mode_800(1'b0));
 reg [15:0] words[0:1231];reg [25:0] expected[0:1];
 reg ref_open=0,ref_edit=0,ref_play=0,ref_mute=0,ref_gamma=0,ref_debug=0,last_vs=1,ref_popup=0;
 integer ref_item=0,ref_brightness=0,ref_contrast=4,ref_volume=8;
 integer previous_brightness=0,previous_contrast=4,ticks=0;reg previous_open=0;
 integer errors=0,pixels=0,highlight=0,normal=0,bypass=0,f,xx,yy,fd=0;
 reg changed;
 function integer label_code;
  input integer row,col;
  begin
   label_code=73;
   case(row)
    0:if(col<2)label_code=34+col;
    1:if(col<2)label_code=38+col;
    2:case(col)0:label_code=40;1:label_code=41;2:label_code=39;endcase
    3:if(col<2)label_code=42+col;
    4:if(col<2)label_code=44+col;
    5:case(col)0:label_code=46;1:label_code=44;endcase
    6:if(col<2)label_code=47+col;
    7:if(col<2)label_code=49+col;
   endcase
  end
 endfunction
 function integer value_code;
  input integer row,col;integer magnitude;
  begin
   value_code=73;magnitude=ref_brightness<0?-ref_brightness:ref_brightness;
   case(row)
    0:if(col<2)value_code=(ref_play?34:36)+col;
    1:case(col)0:value_code=ref_brightness<0?75:74;1:value_code=63+magnitude/10;2:value_code=63+magnitude%10;endcase
    2:if(col==0)value_code=63+ref_contrast;
    3:if(col==0)value_code=ref_gamma?53:54;
    4:case(col)0:value_code=63+ref_volume/10;1:value_code=63+ref_volume%10;endcase
    5:if(col==0)value_code=ref_mute?53:54;
    6:if(col==0)value_code=ref_debug?53:54;
   endcase
  end
 endfunction
 function [23:0] reference;
  input integer px,py;input [23:0] background;
  integer row,dy,dx,scale,code,gx,gy,col;reg band,panel;
  begin
   code=73;gx=0;gy=0;band=0;panel=0;reference=background;
   if(ref_open)begin
    panel=px<128 && py>=16 && py<448;
    if(px>=8 && px<40 && py>=40 && py<56)begin
     code=32+(px-8)/16;gx=(px-8)%16;gy=py-40;
    end
    if(!ref_edit)begin
     for(row=0;row<8;row=row+1)begin
      dy=py-(88+row*40);
      if(dy>=0 && dy<32)begin
       band=row==ref_item;scale=band?2:1;
       if(px>=8 && px<(band?104:56) && dy<16*scale)begin
        dx=px-8;col=dx/(16*scale);gx=(dx/scale)%16;gy=dy/scale;code=label_code(row,col);
       end
      end
     end
    end else begin
     if(px>=8 && px<104 && ((py>=88 && py<120)||(py>=144 && py<176)))begin
      dx=px-8;dy=py>=144?py-144:py-88;
      gx=(dx/2)%16;gy=dy/2;col=dx/32;band=1;
      code=py>=144?value_code(ref_item,col):label_code(ref_item,col);
     end
     if(px>=8 && px<40 && ((py>=208 && py<224)||(py>=240 && py<256)))begin
      dx=px-8;gx=dx%16;gy=py>=240?py-240:py-208;
      code=(py>=240?55:57)+dx/16;
     end
    end
    if(px>=8 && px<72 && py>=416 && py<432)begin
     gx=(px-8)%16;gy=py-416;
     case((px-8)/16)0:code=61;1:code=62;2:code=49;3:code=50;endcase
    end
   end else if(ref_popup)begin
    panel=px>=8 && px<152 && py>=8 && py<64;
    if(px>=16 && px<144 && ((py>=16 && py<32)||(py>=40 && py<56)))begin
     dx=px-16;gx=dx%16;gy=py>=40?py-40:py-16;col=dx/16;
     if(col<3)code=label_code(py>=40?2:1,col);
     else if(col==3)code=76;
     else code=value_code(py>=40?2:1,col-4);
    end
   end
   if(panel)begin
    if(words[code*16+gy][15-gx])reference=band?24'hffff00:24'hc0c8d0;
    else reference=band?24'h243040:24'h101820;
   end
  end
 endfunction
 always @(posedge clk)begin
  if(rst)begin
   expected[0]=0;expected[1]=0;ref_open=0;last_vs=1;ref_popup=0;
   previous_brightness=0;previous_contrast=4;previous_open=0;ticks=0;
  end else begin
   expected[1]=expected[0];expected[0]={vs,de,de?reference(x,y,rgb):24'd0};
   changed=(brightness!=previous_brightness || contrast!=previous_contrast) && !opened && !previous_open;
   if(last_vs && !vs)begin
    ref_open=opened;ref_item=item;ref_edit=editing;ref_play=playing;
    ref_brightness=brightness;ref_contrast=contrast;ref_volume=volume;
    ref_mute=mute;ref_gamma=gamma;ref_debug=debug;ref_popup=!opened && (changed || ticks>0);
   end
   if(opened)ticks=0;else if(changed)ticks=50000000;else if(ticks>0)ticks=ticks-1;
   previous_brightness=brightness;previous_contrast=contrast;previous_open=opened;last_vs=vs;
  end
  #1;
  if(!rst && {ov,od,result}!==expected[1])begin
   if(errors<10)$display("FAILED menu pixel x=%d y=%d got=%h expected=%h",x,y,{ov,od,result},expected[1]);
   errors=errors+1;
  end
  if(!rst && od)begin
   pixels=pixels+1;
   if(result==24'hffff00)highlight=highlight+1;
   if(result==24'hc0c8d0)normal=normal+1;
   if(!ref_open && !ref_popup)bypass=bypass+1;
   if(fd!=0)$fwrite(fd,"%c%c%c",result[23:16],result[15:8],result[7:0]);
  end
 end
 initial begin
  $readmemh("../src/modules/osd/zh_font.mem",words);
  repeat(5)@(negedge clk);rst=0;
  for(f=0;f<18;f=f+1)begin
   opened=(f>=1 && f<=15);editing=(f>=9 && f<=15);
   item=f<=8?(f-1)%8:(f-9)%7;
   if(f>0)begin brightness=-64;volume=16;contrast=8;playing=1;mute=1;gamma=1;debug=1;end
   if(f==17)brightness=24;
   vs=0;repeat(8)@(negedge clk);vs=1;repeat(8)@(negedge clk);
   if(f==3 || f==10 || f==17)begin
    if(f==3)fd=$fopen("../reports/menu_submenu_20261023/menu_list.ppm","wb");
    else if(f==10)fd=$fopen("../reports/menu_submenu_20261023/menu_brightness.ppm","wb");
    else fd=$fopen("../reports/menu_submenu_20261023/popup.ppm","wb");
    if(fd==0)begin $display("FAILED screenshot open");$finish;end
    $fwrite(fd,"P6\n640 480\n255\n");
   end
   for(yy=0;yy<480;yy=yy+1)begin
    if(f==10 && yy==200)begin opened=0;item=7;brightness=0;end
    for(xx=0;xx<640;xx=xx+1)begin x=xx;y=yy;de=1;@(negedge clk);end
    de=0;repeat(5)@(negedge clk);
   end
   repeat(4)@(negedge clk);
   if(fd!=0)begin $fclose(fd);fd=0;end
  end
  rst=1;repeat(4)@(negedge clk);
  if({ov,od,result}!==0)errors=errors+1;
  if(errors==0 && pixels==5529600 && highlight>1000 && normal>1000 && bypass==614400)
   $display("ALL PASS tb_menu_overlay: 18 full frames, 128px solid label-only LIST/seven SUBMENUS/popup, 2x glyphs, frame atomic and two-cycle timing");
  else $display("FAILED tb_menu_overlay errors=%d pixels=%d highlight=%d normal=%d bypass=%d",errors,pixels,highlight,normal,bypass);
  $finish;
 end
 initial begin #70000000;$display("FAILED menu overlay watchdog");$finish;end
endmodule
