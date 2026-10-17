from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).resolve().parent
s=(ROOT/'sim/tb_indexed_player.v').read_text(encoding='utf-8')
s=s.replace('module tb_indexed_player;','module tb_mode_reload;')
s=s.replace('reg clk=0,rst=1,next_cmd=0,prev_cmd=0,ack=0,finish=0;', '''reg clk=0,power_reset=1,next_cmd=0,prev_cmd=0,ack=0,finish=0;
 reg boot=0;always #20 boot=~boot;
 reg [1:0] requested_mode=1;
 wire mode_ready,mode_800;wire [1:0] active_mode;wire rst;
 video_mode_control #(.QUIET_CYCLES(16),.SETTLE_CYCLES(128)) mode_control(
  .clk(boot),.rst(power_reset),.edid_done(1'b1),.supports_800(1'b1),.requested_mode(requested_mode),
  .ready(mode_ready),.mode_800(mode_800),.active_mode(active_mode),.fallback());
 reset_sync reset_player(.clk(clk),.arst(power_reset | !mode_ready),.rst(rst));''')
s=s.replace('.ENABLE_SCALING(1),', '.ENABLE_SCALING(1),.ADAPTIVE(1),')
s=s.replace('.bmp_width(16\'d640),.bmp_height(16\'d480)', '.bmp_width(mode_800?16\'d800:16\'d640),.bmp_height(mode_800?16\'d600:16\'d480)')
s=s.replace('col=pixels%640;', 'col=pixels%(mode_800?800:640);')
s=s.replace('if(col<80 || col>=560)', 'if(col<(mode_800?100:80) || col>=(mode_800?700:560))')
s=s.replace('if(pixels==307200)', 'if(pixels==(mode_800?480000:307200))')
s=s.replace('  if(!rst && pv)begin','  if(rst)pixels=0;\n  if(!rst && pv)begin')
a=s.index('  repeat(5)@(negedge clk);rst=0;')
b=s.index('  $finish;',a)
s=s[:a]+'''  repeat(5)@(negedge clk);power_reset=0;
  wait(shown && !busy);repeat(10)@(negedge clk);
  check(ii==0 && !mode_800,"initial VGA frame");
  select_image(3);complete_image(3);
  requested_mode=2;wait(!mode_ready);wait(mode_ready);wait(shown && !busy);repeat(10)@(negedge clk);
  check(ii==3 && mode_800 && !err && pixels==0,"SVGA reload selected image and full 480000 frame");
  requested_mode=1;wait(!mode_ready);wait(mode_ready);wait(shown && !busy);repeat(10)@(negedge clk);
  check(ii==3 && !mode_800 && !err && pixels==0,"return VGA reload selected image and full 307200 frame");
  // A mode change while a partial new frame is being written must abort it.
  select_image(7);wait(busy && pixels>100);requested_mode=0;
  wait(!mode_ready);wait(mode_ready);wait(shown && !busy);repeat(10)@(negedge clk);
  check(ii==7 && !mode_800 && active_mode==0 && !err && pixels==0,"mid-load reset aborts old partial frame, then clean reload");
  if(errors==0)$display("ALL PASS tb_mode_reload: real FAT/BMP/WAV reload across VGA-SVGA-VGA, exact pixels, mid-load abort, same file resume");
  else $display("FAILED mode reload errors=%0d",errors);
'''+s[b:]
(OUT/'tb_mode_reload.v').write_text(s,encoding='utf-8')
print('Prepared mode lifecycle + real FAT/scaler/WAV reload test')
