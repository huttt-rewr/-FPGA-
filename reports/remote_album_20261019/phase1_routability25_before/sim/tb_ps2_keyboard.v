`timescale 1ns/1ps
module tb_ps2_keyboard;
 reg clk=0,rst=1,pclk=1,pdata=1;
 reg slow_clock=1,slow_data=1;
 wire [7:0] slow_code;wire slow_valid,slow_release,slow_extended,slow_error;
 integer slow_received=0,slow_errors=0;
 wire [7:0] code;wire valid,released,extended,error;
 integer errors=0,received=0,bad=0,i;
 reg [7:0] codes[0:31];reg releases[0:31],extensions[0:31];
 always #5 clk=~clk;
 ps2_keyboard #(.FILTER_CYCLES(3),.TIMEOUT_CYCLES(1000)) dut(
  .clk(clk),.rst(rst),.ps2_clk(pclk),.ps2_data(pdata),.scan_code(code),
  .key_valid(valid),.key_release(released),.key_extended(extended),.receive_error(error));
 // Production parameters at the real 10kHz PS/2 bit rate, independently of
 // the accelerated corruption/timeout tests below.
 ps2_keyboard production(.clk(clk),.rst(rst),.ps2_clk(slow_clock),.ps2_data(slow_data),
  .scan_code(slow_code),.key_valid(slow_valid),.key_release(slow_release),
  .key_extended(slow_extended),.receive_error(slow_error));
 always @(posedge clk)begin
  if(slow_error)slow_errors=slow_errors+1;
  if(slow_valid)begin
   if(slow_code!=8'h16 || slow_extended || slow_release!=(slow_received==1))slow_errors=slow_errors+1;
   slow_received=slow_received+1;
  end
 end
 always @(posedge clk)begin
  if(valid)begin codes[received]=code;releases[received]=released;extensions[received]=extended;received=received+1;end
  if(error)bad=bad+1;
 end
 task check;input ok;input [511:0] msg;begin
  if(ok!==1)begin errors=errors+1;$display("FAIL ps2 receiver %0s",msg);end
 end endtask
 task send_bit;input b;begin
  pdata=b;#170;pclk=0;#230;pclk=1;#200;
 end endtask
 task send_frame;input [7:0] value;input parity_bad,stop_bad;
  integer j;begin
   send_bit(0);for(j=0;j<8;j=j+1)send_bit(value[j]);
   send_bit((~^value)^parity_bad);send_bit(!stop_bad);pdata=1;#500;
  end
 endtask
 task slow_bit;input b;begin
  slow_data=b;#20000;slow_clock=0;#50000;slow_clock=1;#30000;
 end endtask
 task slow_frame;input [7:0] value;integer j;begin
  slow_bit(0);for(j=0;j<8;j=j+1)slow_bit(value[j]);
  slow_bit(~^value);slow_bit(1);slow_data=1;#20000;
 end endtask
 initial begin
  repeat(5)@(negedge clk);rst=0;
  // Sub-filter glitch must not become a frame start.
  pdata=0;#100;pclk=0;#10;pclk=1;#200;pdata=1;
  send_frame(8'h16,0,0);
  send_frame(8'hf0,0,0);send_frame(8'h16,0,0);
  send_frame(8'he0,0,0);send_frame(8'h74,0,0);
  send_frame(8'he0,0,0);send_frame(8'hf0,0,0);send_frame(8'h74,0,0);
  check(received==4,"make/break count and prefix suppression");
  check(codes[0]==8'h16 && !releases[0] && !extensions[0],"LSB-first make");
  check(codes[1]==8'h16 && releases[1] && !extensions[1],"break");
  check(codes[2]==8'h74 && !releases[2] && extensions[2],"E0 make");
  check(codes[3]==8'h74 && releases[3] && extensions[3],"E0 F0 break");
  send_frame(8'h44,1,0);send_frame(8'h44,0,1);
  check(received==4 && bad==2,"bad parity/stop dropped");
  // Truncated frame and an orphan prefix each have a bounded lifetime.
  send_bit(0);send_bit(1);pdata=1;#12000;
  send_frame(8'he0,0,0);#12000;
  send_frame(8'h29,0,0);
  check(received==5 && codes[4]==8'h29 && !extensions[4] && bad==4,"timeout resynchronization");
  // Pause sequence is eight bytes; none are ordinary key events.
  send_frame(8'he1,0,0);send_frame(8'h14,0,0);send_frame(8'h77,0,0);send_frame(8'he1,0,0);
  send_frame(8'hf0,0,0);send_frame(8'h14,0,0);send_frame(8'hf0,0,0);send_frame(8'h77,0,0);
  check(received==5,"Pause swallowed as a complete sequence");
  send_frame(8'haa,0,0);send_frame(8'h3a,0,0);
  check(received==6 && codes[5]==8'h3a && !releases[5] && bad==5,"BAT clears prefix history");
  // A damaged byte after E0 must not leave the next ordinary key extended.
  send_frame(8'he0,0,0);send_frame(8'h75,1,0);send_frame(8'h2d,0,0);
  check(received==7 && codes[6]==8'h2d && !extensions[6],"corrupt extended sequence recovery");
  slow_frame(8'h16);slow_frame(8'hf0);slow_frame(8'h16);
  check(slow_received==2 && slow_errors==0,"production filters/timeouts accept 10kHz make and break");
  if(errors==0)$display("ALL PASS tb_ps2_keyboard: filtered/synchronized 11-bit frames, odd parity, E0/F0, Pause/BAT, malformed-frame/prefix timeouts");
  else $display("FAILED tb_ps2_keyboard errors=%0d",errors);
  $finish;
 end
 initial begin #6000000;$display("FAILED watchdog tb_ps2_keyboard");$finish;end
endmodule
