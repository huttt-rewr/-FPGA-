from pathlib import Path
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent
s=(R/'sim/tb_indexed_player.v').read_text(encoding='utf-8')
s=s.replace('tb_indexed_player','tb_rate_player')
s=s.replace('reg [7:0] image=0,audio=0;', 'reg toggle=0;reg [3:0] rate=0;wire limited,auto_on;integer before_frames;\n reg [7:0] image=0,audio=0;')
s=s.replace('sd_card_bmp #(.INDEXED(1)', '// Accelerate only the timer; preserve the player watchdog.\n defparam dut.rate_control.timer.CLK_FREQ_HZ=3000;\n sd_card_bmp #(.RATE_CONTROLS(1),.INDEXED(1)')
s=s.replace(".cmd_toggle(1'b0)",'.cmd_toggle(toggle)')
s=s.replace('.status_auto(),', '.status_auto(auto_on),.fps_mode(rate),.rate_limited(limited),')
a=s.index('  select_image(9);');b=s.index('  $finish;',a)
s=s[:a]+'''  // At scaled test time, loading a frame is slower than every target period.
  @(negedge clk);toggle=1;@(negedge clk);toggle=0;
  wait(auto_on);wait(ii==1 && !busy);
  check(shown && !err && pixels==0,"automatic commit produces an entire correct frame");
  wait(busy);repeat(4000)@(negedge clk);
  check(limited && ii==1,"deadline expires during load without early commit");
  // Stop while the next frame is loading: complete that frame, queue no more.
  toggle=1;@(negedge clk);toggle=0;wait(!auto_on);wait(!busy);
  repeat(20)@(negedge clk);before_frames=frames;
  repeat(10000)@(negedge clk);
  check(frames==before_frames && !busy && ii==2,"pause drains one in-flight image and schedules no backlog");
  rate=5;repeat(10)@(negedge clk);
  check(!limited,"rate change clears the previous limit diagnostic");
  if(errors==0)$display("ALL PASS tb_rate_player: real FAT/scaler/player, guarded target cadence, full frames, pause during load, no backlog");
  else $display("FAILED rate player errors=%0d",errors);
'''+s[b:]
(O/'tb_rate_player.v').write_text(s,encoding='utf-8')
print('Prepared end-to-end rate/player regression')
