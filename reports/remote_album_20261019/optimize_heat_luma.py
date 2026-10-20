"""Only after a failed build: exactly tabulate the nested thermal-luma mapping.
No pixel/line latency, edge thresholds, RGB values or shared blur changes.
"""
from pathlib import Path
import json
root=Path(__file__).resolve().parents[2]
assert json.loads((root/'reports/build_manifest.json').read_text())['status']!='running'
p=root/'src/modules/video/pixel_effects.v'
s=p.read_text(encoding='utf-8')
old='wire [15:0] heat_weighted=weighted_luma(heat(raw_gray));'
assert old in s
fn='''// Exact 256-entry composition of heat() and weighted_luma().
 // Removes the second multiplier/adder chain from the Sobel/window path.
 // The original RGB transform, luma rounding and three-cycle latency stay exact.
 function [7:0] thermal_luma;
  input [7:0] value;
  begin case(value)
'''
rows=[]
for v in range(256):
 u=(v&63)*4
 r,g,b=((0,u,255),(0,255,255-u),(u,255,0),(255,255-u,0))[v>>6]
 result=(77*r+150*g+29*b)>>8
 rows.append(result)
 fn+=f"   8'd{v}:thermal_luma=8'd{result};\n"
fn+="   default:thermal_luma=8'd0;\n  endcase end\n endfunction\n"
s=s.replace(old,fn+' wire [15:0] heat_weighted={thermal_luma(raw_gray),8\'d0};')
p.write_text(s,encoding='utf-8')
(Path(__file__).resolve().parent/'thermal_luma_exact.mem').write_text(''.join(f'{v:02x}\n' for v in rows),encoding='ascii')
p=root/'sim/tb_pixel_effects.v';s=p.read_text(encoding='utf-8')
old='  repeat(3)@(negedge clk);rst=0;'
assert old in s
s=s.replace(old,'''  repeat(3)@(negedge clk);rst=0;
  // Every gray value is reachable with R=G=B; independent integer oracle.
  for(i=0;i<256;i=i+1)begin
   rgb={i[7:0],i[7:0],i[7:0]};#1;
   case(i/64)
    0:begin xx=0;yy=(i%64)*4;k=255;end
    1:begin xx=0;yy=255;k=255-(i%64)*4;end
    2:begin xx=(i%64)*4;yy=255;k=0;end
    3:begin xx=255;yy=255-(i%64)*4;k=0;end
   endcase
   m=(77*xx+150*yy+29*k)/256;
   if(dut.raw_gray!==i[7:0] || dut.heat_weighted[15:8]!==m[7:0])begin
    errors=errors+1;$display("FAILED exact thermal luma at gray=%d",i);
   end
  end''')
p.write_text(s,encoding='utf-8')
print('Installed exhaustive exact thermal-luma lookup, unchanged three-cycle output')
