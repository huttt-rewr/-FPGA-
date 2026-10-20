from pathlib import Path
root=Path(__file__).resolve().parents[2]
(root/'sim/tb_auto_enhance.v').write_text('''`timescale 1ns/1ps
module tb_auto_enhance;
 reg clk=0,rst=1,vs=1,de=0,enable=0;
 always #5 clk=~clk;
 reg [9:0]x=0,y=0;reg [23:0]rgb=0;
 wire ov,od;wire [9:0]ox,oy;wire [23:0]result;
 auto_enhance dut(clk,rst,vs,de,x,y,rgb,enable,ov,od,ox,oy,result);
 integer errors=0,seen=0,i,j,n,f,w,h,m;
 integer loR=255,hiR=0,loG=255,hiG=0,loB=255,hiB=0;
 integer useLoR=0,useHiR=0,useLoG=0,useHiG=0,useLoB=0,useHiB=0;
 reg seen_frame=0,coefficients=0,active_enable=0;
 reg last_vs=1;
 reg [45:0]expected[0:3];reg [23:0]want;
 function [7:0] mapped;input integer value,low,high;integer scale,z;begin
  if(high==low)mapped=value;
  else begin
   scale=(65280+(high-low)/2)/(high-low);
   z=((value<low?0:value-low)*scale+128)/256;
   mapped=z>255?255:z;
  end
 end endfunction
 always @(posedge clk)begin
  if(rst)begin
   for(i=0;i<4;i=i+1)expected[i]=0;
   loR=255;hiR=0;loG=255;hiG=0;loB=255;hiB=0;
   seen_frame=0;coefficients=0;active_enable=0;last_vs=1;
  end else begin
   want=rgb;
   if(active_enable && coefficients)want={mapped(rgb[23:16],useLoR,useHiR),
    mapped(rgb[15:8],useLoG,useHiG),mapped(rgb[7:0],useLoB,useHiB)};
   for(i=3;i>0;i=i-1)expected[i]=expected[i-1];
   expected[0]={vs,de,x,y,de?want:24'd0};
   if(last_vs && !vs)begin
    active_enable=enable;
    if(seen_frame)begin
     useLoR=loR;useHiR=hiR;useLoG=loG;useHiG=hiG;useLoB=loB;useHiB=hiB;coefficients=1;
    end
    seen_frame=de;loR=de?rgb[23:16]:255;hiR=de?rgb[23:16]:0;
    loG=de?rgb[15:8]:255;hiG=de?rgb[15:8]:0;loB=de?rgb[7:0]:255;hiB=de?rgb[7:0]:0;
   end else if(de && vs)begin
    seen_frame=1;
    if(rgb[23:16]<loR)loR=rgb[23:16];if(rgb[23:16]>hiR)hiR=rgb[23:16];
    if(rgb[15:8]<loG)loG=rgb[15:8];if(rgb[15:8]>hiG)hiG=rgb[15:8];
    if(rgb[7:0]<loB)loB=rgb[7:0];if(rgb[7:0]>hiB)hiB=rgb[7:0];
   end
   last_vs=vs;
   #1;
   if({ov,od,ox,oy,result}!==expected[3])begin
    if(errors<8)$display("FAILED automatic levels xy=%d,%d got=%h want=%h",x,y,{ov,od,ox,oy,result},expected[3]);
    errors=errors+1;
   end
   if(od)seen=seen+1;
  end
 end
 task pixel;input integer rr,gg,bb;begin
  de=1;rgb={rr[7:0],gg[7:0],bb[7:0]};x=x+1'b1;@(negedge clk);
 end endtask
 task blank;begin de=0;vs=0;repeat(8)@(negedge clk);vs=1;repeat(8)@(negedge clk);end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;
  // First enabled frame must bypass because there is no preceding valid frame.
  enable=1;blank;
  for(n=0;n<256;n=n+1)pixel(32+n/2,80+n/4,127);
  de=0;repeat(8)@(negedge clk);blank;
  // Previous frame's narrow range maps endpoints to full scale; B is constant.
  for(n=0;n<256;n=n+1)pixel(n,255-n,n);
  de=0;repeat(8)@(negedge clk);blank;
  // Every possible 8-bit range, including range=0 and saturation outside old limits.
  for(j=0;j<256;j=j+1)begin
   pixel(0,0,0);pixel(j,j,j);de=0;repeat(5)@(negedge clk);blank;
   for(n=0;n<256;n=n+1)pixel(n,n,n);
   de=0;repeat(5)@(negedge clk);blank;
  end
  // Empty frames retain last coefficients; enable is sampled only at frame boundary.
  blank;blank;enable=0;
  for(n=0;n<16;n=n+1)pixel(n+100,n+20,n+30);
  de=0;repeat(8)@(negedge clk);blank;
  // Two actual output sizes: exact active pixels, line blanking, random-looking RGB.
  for(m=0;m<2;m=m+1)begin
   w=m?800:640;h=m?600:480;blank;
   for(f=0;f<h;f=f+1)begin
    y=f;x=1023;
    for(n=0;n<w;n=n+1)pixel(n+f,n*3+f,n^f);
    de=0;repeat(5)@(negedge clk);
   end
  end
  de=0;repeat(8)@(negedge clk);rst=1;repeat(3)@(negedge clk);
  if({ov,od,ox,oy,result}!==0)errors=errors+1;
  if(errors==0 && seen>850000)$display("ALL PASS tb_auto_enhance: 256 ranges x256 values, full VGA/SVGA bypass, frame coefficients, empty/constant/first frames, saturation, RGB VS DE XY latency, reset");
  else $display("FAILED tb_auto_enhance errors=%d seen=%d",errors,seen);
  $finish;
 end
 initial begin #20000000;$display("FAILED watchdog tb_auto_enhance");$finish;end
endmodule
''',encoding='utf-8')
print('Installed independent exhaustive automatic-level oracle')
p=root/'sim/tb_remote_uart.v'
s=p.read_text(encoding='utf-8')
old='  check(!overflow,"bounded response queue no overflow");'
assert old in s
s=s.replace(old,'''  byte("a");repeat(200)@(negedge clk);
  check(auto_enh && replies[9]=="K" && count==10,"UART a persists and acknowledges automatic levels enable");
  byte("a");repeat(200)@(negedge clk);
  check(!auto_enh && replies[10]=="K" && count==11,"UART a disables automatic levels independently of playback");
'''+old)
p.write_text(s,encoding='utf-8')
