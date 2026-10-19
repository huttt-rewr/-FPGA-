from pathlib import Path
root=Path(__file__).resolve().parents[2]
def edit(name,pairs):
    p=root/name
    s=p.read_text(encoding='utf-8-sig')
    for old,new in pairs:
        assert old in s,(name,old)
        s=s.replace(old,new)
    p.write_text(s,encoding='utf-8')

edit('src/modules/video/frame_swap.v',[
 ('output reg [1:0] effect_mode','output reg [2:0] effect_mode'),
 ('reg alternate_slide;','// Slot 3 cycles fade, slide, wipe, iris, checker. Captured once per request.\n    reg [2:0] rotation_effect;'),
 ('alternate_slide<=0;',"rotation_effect<=3'd1;"),
 ("effect_mode<=(transition_mode==3)?(alternate_slide?2'd2:2'd1):transition_mode;\n                            if(transition_mode==3) alternate_slide<=~alternate_slide;",
  "effect_mode<=(transition_mode==3)?rotation_effect:{1'b0,transition_mode};\n                            if(transition_mode==3)\n                                rotation_effect<=(rotation_effect==5)?3'd1:rotation_effect+1'b1;")])
for name in ('picture_adjust','picture_gamma'):
    edit('src/modules/video/'+name+'.v',[
     ('output reg [23:0] out_rgb);','output reg [23:0] out_rgb,\n input [9:0] y,output reg [9:0] out_y);'),
     ('reg [9:0] px;','reg [9:0] px,py;'),
     ('px<=0;','px<=0;py<=0;'),
     ('out_x<=0;','out_x<=0;out_y<=0;'),
     ('px<=x;','px<=x;py<=y;'),
     ('out_x<=px;','out_x<=px;out_y<=py;')])
edit('src/top.v',[
 ('wire [1:0] running_effect;','wire [2:0] running_effect;'),
 ('wire [9:0] adjusted_x;','wire [9:0] adjusted_x,adjusted_y;'),
 ('wire [9:0] gamma_x;','wire [9:0] gamma_x,gamma_y;'),
 ('.vs(vs),.de(de),.x(pixel_x),','.vs(vs),.de(de),.x(pixel_x),.y(pixel_y),'),
 ('.out_x(adjusted_x),.out_rgb(enhanced_rgb)', '.out_x(adjusted_x),.out_y(adjusted_y),.out_rgb(enhanced_rgb)'),
 ('.x(adjusted_x),.rgb(enhanced_rgb)', '.x(adjusted_x),.y(adjusted_y),.rgb(enhanced_rgb)'),
 ('.out_x(gamma_x),.out_rgb(gamma_rgb)', '.out_x(gamma_x),.out_y(gamma_y),.out_rgb(gamma_rgb)'),
 ('.x(gamma_x),.rgb(gamma_rgb)', '.x(gamma_x),.y(gamma_y),.mode_800(mode_video),.rgb(gamma_rgb)')])

# Append new ports, preserving all old positional port positions. Update every caller.
for name in ('tb_effects_pipeline','tb_svga_pipeline'):
    mode="1'b1" if name=='tb_svga_pipeline' else "1'b0"
    edit('sim/'+name+'.v',[
     ('wire [9:0] ax;', 'wire [9:0] ax,ay;'),
     ('av,ad,ax,adjusted);','av,ad,ax,adjusted,py,ay);'),
     ('mode,level,offset,ev,ed,ec);',"{1'b0,mode},level,offset,ev,ed,ec,ay,"+mode+');')])
edit('sim/tb_board_pipeline.v',[
 ('px,py,ax,gx;','px,py,ax,ay,gx,gy;'),
 ('av,ad,ax,ac);','av,ad,ax,ac,py,ay);'),
 ('en,gv,gd,gx,gc);','en,gv,gd,gx,gc,ay,gy);'),
 ("effect,6'd16,offset,ev,ed,ec);","{1'b0,effect},6'd16,offset,ev,ed,ec,gy,mode);")])
edit('sim/tb_picture_adjust.v',[('ov,od,ox,result);',"ov,od,ox,result,10'd0,());")])
edit('sim/tb_picture_gamma.v',[('ov,od,ox,result);',"ov,od,ox,result,10'd0,());")])
edit('sim/tb_transition_pixels.v',[
 ('mode,level,offset,ov,od,color);',"{1'b0,mode},level,offset,ov,od,color,10'd0,1'b0);")])
edit('sim/tb_transition.v',[
 ('wire [1:0] active,effect;', 'wire [1:0] active;wire [2:0] effect;'),
 ('reg [1:0] prev_active,prev_effect;', 'reg [1:0] prev_active;reg [2:0] prev_effect;')])
edit('sim/tb_switch_controls.v',[
 ('wire [1:0] active,effect;', 'wire [1:0] active;wire [2:0] effect;'),
 ('task finish_animation;input [1:0] kind;', 'task finish_animation;input [2:0] kind;'),
 ('change;sw=15;settle;', 'change;sw=15;settle;'),
 ('busy && effect==1,"mode changed for next transaction only"','busy && effect==3,"mode changed for next transaction only"'),
 ('finish_animation(1);\n  change;check(!busy', 'finish_animation(3);\n  change;check(!busy'),
 ('alternating transitions','five-effect transitions')])
edit('scripts/run_tests.ps1',[
 ("$files += @($mergeTests |", "$mergeTests += @('tb_transition_effects')\n $files += @($mergeTests |")])

# Exact integer circle radii; constants avoid a third DSP for radius squaring.
radius='''    function [17:0] radius_square;
        input [5:0] level;
        input svga;
        begin
            case(level)
'''
for n in range(33):
    radius+=f"                6'd{n}: radius_square=svga?18'd{(500*n//32)**2}:18'd{(400*n//32)**2};\n"
radius+='''                default: radius_square=0;
            endcase
        end
    endfunction
'''
p=root/'src/modules/video/transition_pixels.v'
s=p.read_text()
s=s.replace('input [1:0] effect_mode','input [2:0] effect_mode')
s=s.replace('output reg [23:0] out_rgb);','output reg [23:0] out_rgb,\n    input [9:0] y,input mode_800);')
insert='''    // All geometry stays in video_clk. No extra line stores or SDRAM reads.
    // 0 bypass, 1 fade, 2 translated slide, 3 wipe, 4 circular iris, 5 checker.
    wire [9:0] cx=mode_800?10'd400:10'd320;
    wire [9:0] cy=mode_800?10'd300:10'd240;
    wire [9:0] dx=(x>=cx)?x-cx:cx-x;
    wire [9:0] dy=(y>=cy)?y-cy:cy-y;
    wire [19:0] dx_square=dx*dx,dy_square=dy*dy;
    wire [20:0] distance_square={1'b0,dx_square}+{1'b0,dy_square};
    wire iris_cover=(fade_level==0) ||
                    ((fade_level<32) && distance_square>{3'd0,radius_square(fade_level,mode_800)});
    // A checker appears halfway through; each 32-pixel tile fills monotonically.
    // Changing only checker frequency would leave half the frame exposed at handoff.
    wire [5:0] progress=6'd32-fade_level;
    wire odd_tile=x[5]^y[5];
    wire [5:0] tile_threshold={1'b0,progress[3:0],1'b0};
    wire tile_strip=({1'b0,x[4:0]}<tile_threshold);
    wire checker_cover=(fade_level==0) ||
                       (odd_tile ? (progress>=16 && tile_strip) : (progress>=16 || tile_strip));
    reg cover;
    always @* begin
        case(effect_mode)
            3'd2,3'd3: cover=(x<slide_offset);
            3'd4: cover=iris_cover;
            3'd5: cover=checker_cover;
            default: cover=0;
        endcase
    end
'''+radius
s=s.replace('    reg vs_q,de_q,shift_q,covered_q;',insert+'    reg vs_q,de_q,shift_q,covered_q;')
s=s.replace('covered_q<=(effect_mode==2 && x<slide_offset);','covered_q<=cover;')
p.write_text(s,encoding='utf-8')
print('Installed transition expansion and aligned Y chain')
