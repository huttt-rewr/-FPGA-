`timescale 1ns/1ps
module tb_menu_media_pixels;
 reg clk=0,rst=1,vs=1,de=0,editing=0,mode=0,movie=0;always #5 clk=~clk;
 reg [9:0] x=0,y=0;reg [2:0] item=0;reg [1:0] requested=1;
 wire ov,od;wire [23:0] rgb;
 reg [15:0] words[0:1439];reg [25:0] expected[0:1];
 integer f,xx,yy,errors=0,pixels=0,fd=0;reg [23:0] ref_rgb;
 menu_overlay #(.MEDIA_MENU(1)) dut(.clk(clk),.rst(rst),.vs(vs),.de(de),.x(x),.y(y),.rgb(24'h305070),
  .menu_open(1'b1),.menu_page(1'b1),.menu_item(item),.edit_mode(editing),.auto_play(1'b0),
  .brightness(8'sd0),.contrast(4'd4),.volume(5'd8),.mute(1'b0),.gamma_enable(1'b0),.debug_enable(1'b0),
  .mode_800(mode),.requested_resolution(requested),.movie_mode(movie),.out_vs(ov),.out_de(od),.out_rgb(rgb));
 function integer label;
  input integer k,c;
  begin label=73;
   case(k)
    0:if(c<2)label=77+c;
    1:if(c<2)label=79+c;
    2:case(c)0:label=44;1:label=81;endcase
    3:if(c<3)label=82+c;
   endcase
  end
 endfunction
 function integer value;
  input integer k,c;integer n;
  begin value=73;
   if(k<3)case(c)0:value=58;1:value=85;2:value=86+k;endcase
   else begin
    // Independent decimal oracle: use the actual output size, including fallback.
    n=(mode && !movie)?800:640;
    case(c)
     0:value=63+n/100;1:value=63+(n/10)%10;2:value=63+n%10;
     3:value=89;
     4:value=63+((mode && !movie)?600:480)/100;
     5:value=63+(((mode && !movie)?600:480)/10)%10;
     6:value=63+((mode && !movie)?600:480)%10;
    endcase
   end
  end
 endfunction
 function [23:0] reference;
  input integer px,py;integer code,gx,gy,row,dy,dx,scale;reg band;
  begin
   reference=24'h305070;code=73;gx=0;gy=0;band=0;
   if(px<128 && py>=16 && py<448)begin
    if(px>=8 && px<40 && py>=40 && py<56)begin code=32+(px-8)/16;gx=(px-8)%16;gy=py-40;end
    if(px>=88 && px<104 && py>=40 && py<56)begin code=65;gx=px-88;gy=py-40;end
    if(!editing)begin
     for(row=0;row<4;row=row+1)begin
      dy=py-(88+row*40);
      if(dy>=0 && dy<32)begin
       band=(row==item);scale=band?2:1;
       if(px>=8 && px<(band?104:56) && dy<16*scale)begin
        dx=px-8;code=label(row,dx/(16*scale));gx=(dx/scale)%16;gy=dy/scale;
       end
      end
     end
    end else begin
     if(px>=8 && px<((item==3)?120:104) && ((py>=88 && py<120)||(py>=144 && py<176)))begin
      band=1;dx=px-8;dy=py-((py>=144)?144:88);gx=(dx/2)%16;gy=dy/2;
      code=(py>=144)?value(item,dx/32):label(item,dx/32);
      if(item==3 && py>=144)begin gx=dx%16;gy=dy%16;code=(dy<16)?value(item,dx/16):73;end
     end
     if(px>=8 && px<40 && ((py>=208 && py<224)||(py>=240 && py<256)))begin
      gx=(px-8)%16;gy=(py>=240)?py-240:py-208;
      code=((py>=240)?55:57)+(px-8)/16;
     end
    end
    if(px>=8 && px<72 && py>=416 && py<432)begin
     case((px-8)/16)0:code=61;1:code=62;2:code=49;3:code=50;endcase
     gx=(px-8)%16;gy=py-416;
    end
    reference=words[code*16+gy][15-gx]?(band?24'hffff00:24'hc0c8d0):(band?24'h243040:24'h101820);
   end
  end
 endfunction
 always @(posedge clk)begin
  if(rst)begin expected[0]=0;expected[1]=0;end
  else begin expected[1]=expected[0];expected[0]={vs,de,de?reference(x,y):24'd0};end
  #1;
  if(!rst && {ov,od,rgb}!==expected[1])begin
   if(errors<8)$display("FAILED media pixel frame=%d x=%d y=%d actual=%h expected=%h",f,x,y,{ov,od,rgb},expected[1]);errors=errors+1;
  end
  if(!rst && od)begin pixels=pixels+1;if(fd!=0)$fwrite(fd,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);end
 end
 initial begin
  $readmemh("../src/modules/osd/zh_font.mem",words);
  repeat(4)@(negedge clk);rst=0;
  for(f=0;f<10;f=f+1)begin
   item=f%4;editing=f>=4;requested=(f>=8)?2:1;mode=(f==8);movie=(f==9);
   if(f>=8)item=3;
   vs=0;repeat(6)@(negedge clk);vs=1;repeat(6)@(negedge clk);
   if(f==3 || f==4 || f==8)begin
    case(f)3:fd=$fopen("../reports/menu_media_20261023/media_list.ppm","wb");
     4:fd=$fopen("../reports/menu_media_20261023/image_submenu.ppm","wb");
     8:fd=$fopen("../reports/menu_media_20261023/resolution.ppm","wb");endcase
    if(!fd)begin $display("FAILED screenshot");$finish;end
    $fwrite(fd,"P6\n640 480\n255\n");
   end
   for(yy=0;yy<480;yy=yy+1)begin
    for(xx=0;xx<640;xx=xx+1)begin x=xx;y=yy;de=1;@(negedge clk);end
    de=0;repeat(4)@(negedge clk);
   end
   repeat(4)@(negedge clk);if(fd)begin $fclose(fd);fd=0;end
  end
  if(errors==0 && pixels==3072000)$display("ALL PASS tb_menu_media_pixels: 10 complete frames, new Chinese labels/actions, actual resolutions and fallback, solid128px, exact RGB/VS/DE");
  else $display("FAILED tb_menu_media_pixels errors=%d pixels=%d",errors,pixels);$finish;
 end
 initial begin #50000000;$display("FAILED media pixels watchdog");$finish;end
endmodule
