from pathlib import Path
import runpy
root=Path(__file__).resolve().parents[2]
def edit(path,pairs):
    p=root/path;s=p.read_text(encoding='utf-8-sig')
    for old,new in pairs:
        assert old in s,(path,old);s=s.replace(old,new)
    p.write_text(s,encoding='utf-8')
rom='''// Generated reciprocal table: Q8 round(255*256/r), r=0 is bypass.
module auto_enhance_scale(input [7:0] range_value,output reg [15:0] scale);
 always @*case(range_value)
'''
values=[0]+[(255*256+r//2)//r for r in range(1,256)]
for n,v in enumerate(values):rom+=f"  8'd{n}:scale=16'h{v:04x};\n"
rom+='  default:scale=0;\n endcase\nendmodule\n'
(root/'src/modules/video/auto_enhance_scale.v').write_text(rom,encoding='utf-8')
(root/'src/modules/video/auto_enhance_scale.mem').write_text(''.join(f'{v:04x}\n' for v in values),encoding='ascii')
(root/'src/modules/video/auto_enhance.v').write_text('''// Previous-frame per-channel automatic levels. Four fully registered stages.
// Empty frames retain coefficients. Constant channels and the first frame bypass.
module auto_enhance(
 input clk,input rst,input vs,input de,input [9:0] x,y,input [23:0] rgb,input enable,
 output reg out_vs,output reg out_de,output reg [9:0] out_x,out_y,output reg [23:0] out_rgb);
 reg vs_d,seen,coeff_valid,frame_enable;
 wire frame_start=vs_d && !vs;
 reg [7:0] rmin,rmax,gmin,gmax,bmin,bmax;
 wire [7:0] rr=rmax-rmin,gr=gmax-gmin,br=bmax-bmin;
 wire [15:0] rs,gs,bs;
 auto_enhance_scale rscale(rr,rs),gscale(gr,gs),bscale(br,bs);
 reg [15:0] sR,sG,sB;
 reg [7:0] oR,oG,oB;
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   vs_d<=1;seen<=0;coeff_valid<=0;frame_enable<=0;
   rmin<=255;rmax<=0;gmin<=255;gmax<=0;bmin<=255;bmax<=0;
   sR<=0;sG<=0;sB<=0;oR<=0;oG<=0;oB<=0;
  end else begin
   vs_d<=vs;
   if(frame_start)begin
    frame_enable<=enable;
    if(seen)begin sR<=rs;sG<=gs;sB<=bs;oR<=rmin;oG<=gmin;oB<=bmin;coeff_valid<=1;end
    // A legal coincident first pixel must belong to the new frame.
    seen<=de;
    rmin<=de?rgb[23:16]:8'd255;rmax<=de?rgb[23:16]:8'd0;
    gmin<=de?rgb[15:8]:8'd255;gmax<=de?rgb[15:8]:8'd0;
    bmin<=de?rgb[7:0]:8'd255;bmax<=de?rgb[7:0]:8'd0;
   end else if(de && vs)begin
    seen<=1;
    if(rgb[23:16]<rmin)rmin<=rgb[23:16];if(rgb[23:16]>rmax)rmax<=rgb[23:16];
    if(rgb[15:8]<gmin)gmin<=rgb[15:8];if(rgb[15:8]>gmax)gmax<=rgb[15:8];
    if(rgb[7:0]<bmin)bmin<=rgb[7:0];if(rgb[7:0]>bmax)bmax<=rgb[7:0];
   end
  end
 end
 reg v1,d1,v2,d2,v3,d3,en1,en2,en3;
 reg [9:0] x1,y1,x2,y2,x3,y3;
 reg [23:0] rgb1,rgb2,rgb3;
 reg [7:0] deltaR,deltaG,deltaB;
 reg [15:0] scaleR1,scaleG1,scaleB1;
 reg [23:0] productR,productG,productB;
 reg [2:0] bypass1,bypass2,bypass3;
 function [7:0] saturate;
  input [23:0] value;reg [24:0] rounded;
  begin rounded={1'b0,value}+25'd128;saturate=(rounded[24:8]>255)?8'd255:rounded[15:8];end
 endfunction
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   v1<=0;d1<=0;v2<=0;d2<=0;v3<=0;d3<=0;en1<=0;en2<=0;en3<=0;
   x1<=0;y1<=0;x2<=0;y2<=0;x3<=0;y3<=0;rgb1<=0;rgb2<=0;rgb3<=0;
   deltaR<=0;deltaG<=0;deltaB<=0;scaleR1<=0;scaleG1<=0;scaleB1<=0;
   productR<=0;productG<=0;productB<=0;bypass1<=0;bypass2<=0;bypass3<=0;
   out_vs<=0;out_de<=0;out_x<=0;out_y<=0;out_rgb<=0;
  end else begin
   v1<=vs;d1<=de;x1<=x;y1<=y;rgb1<=rgb;en1<=frame_enable && coeff_valid;
   deltaR<=(rgb[23:16]>=oR)?rgb[23:16]-oR:8'd0;
   deltaG<=(rgb[15:8]>=oG)?rgb[15:8]-oG:8'd0;
   deltaB<=(rgb[7:0]>=oB)?rgb[7:0]-oB:8'd0;
   scaleR1<=sR;scaleG1<=sG;scaleB1<=sB;
   bypass1<={sR==0,sG==0,sB==0};
   v2<=v1;d2<=d1;x2<=x1;y2<=y1;rgb2<=rgb1;en2<=en1;bypass2<=bypass1;
   productR<=deltaR*scaleR1;productG<=deltaG*scaleG1;productB<=deltaB*scaleB1;
   v3<=v2;d3<=d2;x3<=x2;y3<=y2;en3<=en2;bypass3<=bypass2;
   rgb3<={bypass2[2]?rgb2[23:16]:saturate(productR),
           bypass2[1]?rgb2[15:8]:saturate(productG),bypass2[0]?rgb2[7:0]:saturate(productB)};
   out_vs<=v3;out_de<=d3;out_x<=x3;out_y<=y3;out_rgb<=d3?rgb3:24'd0;
  end
 end
endmodule
''',encoding='utf-8')
# Above RGB saturation stage must preserve bypass for ALL channels when disabled.
p=root/'src/modules/video/auto_enhance.v';s=p.read_text().replace('rgb3<={bypass2[2]?', 'rgb3<=!en2?rgb2:{bypass2[2]?')
p.write_text(s,encoding='utf-8')
edit('src/modules/control/player_control.v',[
 ('output reg scroll_enable,output reg [1:0] slogan_select);','output reg scroll_enable,output reg [1:0] slogan_select,output reg auto_enh_en);'),
 ('transition_mode<=1;captions_enable<=1;scroll_enable<=1;slogan_select<=0;',
  'transition_mode<=1;captions_enable<=1;scroll_enable<=1;slogan_select<=0;auto_enh_en<=0;'),
 ('"n":next_pulse<=1;', '"a":auto_enh_en<=~auto_enh_en;\n                    "n":next_pulse<=1;')])
edit('src/modules/control/remote_controls.v',[
 ('output time_set,input ir_rx);','output time_set,input ir_rx,output auto_enh_en);'),
 ('data=="b")?data', 'data=="b" || data=="a")?data'),
 ('.slogan_select());','.slogan_select(),.auto_enh_en(auto_enh_en));')])
edit('src/top.v',[
 ('wire [32:0] time_video;', 'wire [32:0] time_video;\nwire auto_enh_en,auto_enh_video;\nwire ae_vs,ae_de;wire [9:0] ae_x,ae_y;wire [23:0] ae_rgb;'),
 ('.time_set(remote_time_set),.ir_rx(ir_rx_pin));', '.time_set(remote_time_set),.ir_rx(ir_rx_pin),.auto_enh_en(auto_enh_en));'),
 ('transition_pixels effects(','''cdc_snapshot #(.WIDTH(1)) autoenh_cdc(.src_clk(sd_card_clk),.src_rst(rst_controls),
 .src_data(auto_enh_en),.dst_clk(video_clk),.dst_rst(rst_video),.dst_data(auto_enh_video));
auto_enhance autoe(.clk(video_clk),.rst(rst_video),.vs(gamma_vs),.de(gamma_de),.x(gamma_x),.y(gamma_y),
 .rgb(gamma_rgb),.enable(auto_enh_video),.out_vs(ae_vs),.out_de(ae_de),.out_x(ae_x),.out_y(ae_y),.out_rgb(ae_rgb));
transition_pixels effects('''),
 ('.vs(gamma_vs),.de(gamma_de),\n .x(gamma_x),.y(gamma_y),.mode_800(mode_video),.rgb(gamma_rgb)',
  '.vs(ae_vs),.de(ae_de),\n .x(ae_x),.y(ae_y),.mode_800(mode_video),.rgb(ae_rgb)')])
edit('sim/tb_upgrade.v',[('effect,captions,scroll,slogan);','effect,captions,scroll,slogan,auto_enh);'),
 ('wire captions,scroll;','wire captions,scroll,auto_enh;')])
edit('sim/tb_remote_uart.v',[("time_bcd,seq,ts,1'b1);","time_bcd,seq,ts,1'b1,auto_enh);"),
 ('wire tx,overflow,np,pp,tp,ts;','wire tx,overflow,np,pp,tp,ts,auto_enh;')])
edit('scripts/run_tests.ps1',[('$files += @($mergeTests |',"$mergeTests += @('tb_auto_enhance')\n $files += @($mergeTests |")])
print('Installed four-stage automatic levels with generated hex reciprocal ROM')
