`timescale 1ns/1ps
module tb_menu_overlay;
 reg clk=0,rst=1,vs=1,de=0,opened=0,editing=0,playing=0,mute=0,gamma=0,debug=0;
 always #5 clk=~clk;
 reg [9:0] x=0,y=0;reg [23:0] rgb=24'h305070;
 reg [2:0] item=0;reg signed [7:0] brightness=0;reg [3:0] contrast=4;reg [4:0] volume=8;
 wire ov,od;wire [23:0] result;
 menu_overlay dut(clk,rst,vs,de,x,y,rgb,opened,item,editing,playing,brightness,contrast,volume,mute,gamma,debug,ov,od,result);
 reg [15:0] words[0:1231];reg [25:0] expected[0:1];
 reg ref_open=0,ref_edit=0,ref_play=0,ref_mute=0,ref_gamma=0,ref_debug=0,last_vs=1;
 integer ref_item=0,ref_brightness=0,ref_contrast=4,ref_volume=8;
 integer errors=0,pixels=0,highlight=0,normal=0,bypass=0,f,xx,yy,fd=0;
 localparam [647:0] GRADIENT={
  24'h1E90FF,24'h1A9AFF,24'h16A4FF,24'h13AEFF,24'h0FB8FF,24'h0BC3FF,
  24'h08CDFF,24'h04D7FF,24'h01E1FF,24'h0DD0FF,24'h22B1FF,24'h3793FF,
  24'h4B75FF,24'h6056FF,24'h7438FF,24'h892FFA,24'h9D2FF4,24'hB12FEE,
  24'hC62FE8,24'hDA2FE2,24'hEE2FDC,24'hFF2FD4,24'hFF32C3,24'hFF34B2,
  24'hFF37A1,24'hFF3A90,24'hFF3D7F};
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
 function [23:0] reference;
  input integer px,py;input [23:0] background;
  integer row,dy,dx,scale,code,gx,gy,col,magnitude,i;reg band;
  begin
   reference=background;
   if(ref_open && px>=48 && px<592 && py>=16 && py<448)begin
    band=0;code=73;gx=0;gy=0;
    if(px>=64 && px<96 && py>=40 && py<56)begin
     code=32+(px-64)/16;gx=(px-64)%16;gy=py-40;
    end
    for(row=0;row<8;row=row+1)begin
     dy=py-(88+row*40);
     if(dy>=0 && dy<32)begin
      band=row==ref_item;scale=band?2:1;gy=(dy/scale)%16;
      if(px>=64 && px<(band?160:112) && dy<16*scale)begin
       dx=px-64;col=dx/(16*scale);gx=(dx/scale)%16;code=label_code(row,col);
      end
      if(band && px>=288 && px<416)begin
       dx=px-288;col=dx/32;gx=(dx/2)%16;
       case(row)
        0:if(col<2)code=(ref_play?34:36)+col;
        1:begin
         magnitude=ref_brightness<0?-ref_brightness:ref_brightness;
         case(col)0:code=ref_brightness<0?75:74;1:code=63+magnitude/10;2:code=63+magnitude%10;endcase
        end
        2:if(col==0)code=63+ref_contrast;
        3:if(col==0)code=ref_gamma?53:54;
        4:case(col)0:code=63+ref_volume/10;1:code=63+ref_volume%10;endcase
        5:if(col==0)code=ref_mute?53:54;
        6:if(col==0)code=ref_debug?53:54;
       endcase
      end
      if(band && px>=480 && px<544)begin
       dx=px-480;code=(ref_edit?55:59)+dx/32;gx=(dx/2)%16;
      end
     end
    end
    if(px>=64 && px<288 && py>=416 && py<432)begin
     col=(px-64)/16;gx=(px-64)%16;gy=py-416;
     case(col)
      0:code=57;1:code=58;2:code=73;3:code=59;4:code=60;5:code=73;
      6:code=55;7:code=56;8:code=73;9:code=61;10:code=62;11:code=49;12:code=50;default:code=73;
     endcase
    end
    if(words[code*16+gy][15-gx])reference=band?24'hffff00:24'h808080;
    else reference=band?24'h243040:GRADIENT[(26-(py-16)/16)*24+:24];
   end
  end
 endfunction
 always @(posedge clk)begin
  if(rst)begin expected[0]=0;expected[1]=0;ref_open=0;last_vs=1;end
  else begin
   expected[1]=expected[0];expected[0]={vs,de,de?reference(x,y,rgb):24'd0};
   if(last_vs && !vs)begin
    ref_open=opened;ref_item=item;ref_edit=editing;ref_play=playing;
    ref_brightness=brightness;ref_contrast=contrast;ref_volume=volume;
    ref_mute=mute;ref_gamma=gamma;ref_debug=debug;
   end
   last_vs=vs;
  end
  #1;
  if(!rst && {ov,od,result}!==expected[1])begin
   if(errors<10)$display("FAILED menu pixel x=%d y=%d got=%h expected=%h",x,y,{ov,od,result},expected[1]);
   errors=errors+1;
  end
  if(!rst && od)begin
   pixels=pixels+1;
   if(result==24'hffff00)highlight=highlight+1;
   if(result==24'h808080)normal=normal+1;
   if(!ref_open)bypass=bypass+1;
   if(fd!=0)$fwrite(fd,"%c%c%c",result[23:16],result[15:8],result[7:0]);
  end
 end
 initial begin
  $readmemh("../src/modules/osd/zh_font.mem",words);
  repeat(5)@(negedge clk);rst=0;
  for(f=0;f<10;f=f+1)begin
   opened=(f!=0 && f!=9);item=(f-1)%8;editing=(f==2 || f==5);
   brightness=f==2?-64:63;volume=16;contrast=8;playing=1;mute=1;gamma=1;debug=1;
   vs=0;repeat(8)@(negedge clk);vs=1;repeat(8)@(negedge clk);
   if(f==2)begin fd=$fopen("../reports/menu_gradient_20261023/menu_edit.ppm","wb");$fwrite(fd,"P6\n640 480\n255\n");end
   for(yy=0;yy<480;yy=yy+1)begin
    if(f==2 && yy==200)begin opened=0;item=7;brightness=0;end
    for(xx=0;xx<640;xx=xx+1)begin x=xx;y=yy;de=1;@(negedge clk);end
    de=0;repeat(5)@(negedge clk);
   end
   repeat(4)@(negedge clk);
   if(fd!=0)begin $fclose(fd);fd=0;end
  end
  rst=1;repeat(4)@(negedge clk);
  if({ov,od,result}!==0)errors=errors+1;
  if(errors==0 && pixels==3072000 && highlight>1000 && normal>1000 && bypass==614400)
   $display("ALL PASS tb_menu_overlay: 10 complete frames, eight selections, 2x glyphs/status, closed bypass, frame-atomic settings, RGB/VS/DE latency");
  else $display("FAILED tb_menu_overlay errors=%d pixels=%d highlight=%d normal=%d bypass=%d",errors,pixels,highlight,normal,bypass);
  $finish;
 end
 initial begin #40000000;$display("FAILED menu overlay watchdog");$finish;end
endmodule
