from pathlib import Path
root=Path(__file__).resolve().parents[2]
p=root/'src/modules/osd/caption_overlay.v'
s=p.read_text(encoding='utf-8').replace('// Time is elapsed powered-on time, NOT wall clock. Text uses the existing ASCII font.',
 '// Time defaults to uptime; accepted UART HHMMSS selects a 24-hour wall clock.')
p.write_text(s,encoding='utf-8')
p=root/'src/modules/control/remote_controls.v'
# Restart safely if an earlier preparation stopped at a decoding failure.
s=(root/'reports/remote_album_20261019/phase1_pass/src/modules/control/remote_controls.v').read_text(encoding='utf-8-sig')
s=s.replace('parameter TIMEOUT_CYCLES=50000000)', 'parameter TIMEOUT_CYCLES=50000000,parameter IR_ENABLED=0)')
s=s.replace('output [23:0] time_bcd,output [7:0] time_seq,output time_set);',
            'output [23:0] time_bcd,output [7:0] time_seq,output time_set,input ir_rx);')
s=s.replace(' wire [7:0] data;', ''' wire [7:0] ir_command;
 wire ir_valid,ir_repeat;
 wire supported_ir=ir_valid && (ir_command==8'h40 || ir_command==8'h15 || ir_command==8'h44);
 generate if(IR_ENABLED)begin:infrared
  ir_nec_rx #(.CLK_FREQ(CLK_HZ)) decoder(.clk(clk),.rst(rst),.ir_in(ir_rx),
   .o_command(ir_command),.o_command_valid(ir_valid),.o_repeat(ir_repeat));
 end else begin:no_infrared
  assign ir_command=0;assign ir_valid=0;assign ir_repeat=0;
 end endgenerate
 wire [7:0] data;''')
s=s.replace(".ir_command(8'd0),.ir_valid(1'b0)",'.ir_command(ir_command),.ir_valid(supported_ir)')
p.write_text(s,encoding='utf-8')
p=root/'src/top.v';s=p.read_text(encoding='utf-8-sig').replace('remote_controls remote(', 'remote_controls #(.IR_ENABLED(1)) remote(')
s=s.replace('.time_seq(remote_time_seq),.time_set(remote_time_set));',
            '.time_seq(remote_time_seq),.time_set(remote_time_set),.ir_rx(ir_rx_pin));')
p.write_text(s,encoding='utf-8')
p=root/'sim/tb_remote_uart.v';s=p.read_text(encoding='utf-8-sig').replace('overflow,np,pp,tp,time_bcd,seq,ts);',"overflow,np,pp,tp,time_bcd,seq,ts,1'b1);")
p.write_text(s,encoding='utf-8')
p=root/'scripts/run_tests.ps1';s=p.read_text(encoding='utf-8-sig').replace('$files += @($mergeTests |',"$mergeTests += @('tb_remote_ir')\n $files += @($mergeTests |")
p.write_text(s,encoding='utf-8')
(root/'sim/tb_remote_ir.v').write_text('''`timescale 1ns/1ps
module tb_remote_ir;
 reg clk=0,rst=1,ir=1;
 always #5 clk=~clk;
 wire np,pp,tp,tx,overflow;
 integer errors=0,n=0,p=0,b=0;
 remote_controls #(.CLK_HZ(1000000),.BAUD(62500),.IR_ENABLED(1)) dut(
  .clk(clk),.rst(rst),.rx(1'b1),.ir_rx(ir),.tx(tx),.overflow(overflow),
  .next_pulse(np),.prev_pulse(pp),.toggle_pulse(tp),.time_bcd(),.time_seq(),.time_set());
 always @(posedge clk)if(!rst)begin
  if(np)n=n+1;if(pp)p=p+1;if(tp)b=b+1;
 end
 task level;input value;input integer duration;begin
  @(negedge clk);ir=value;repeat(duration)@(negedge clk);
 end endtask
 task byte;input [7:0]data;integer k;begin
  for(k=0;k<8;k=k+1)begin level(0,560);level(1,data[k]?1690:560);end
 end endtask
 task packet;input [7:0]command,complement;begin
  level(0,9000);level(1,4500);byte(0);byte(255);byte(command);byte(complement);
  level(0,560);level(1,100);
 end endtask
 task check;input ok;input [511:0]msg;begin
  if(ok!==1)begin errors=errors+1;$display("FAILED %s",msg);end
 end endtask
 initial begin
  repeat(5)@(negedge clk);rst=0;repeat(10)@(negedge clk);
  packet(8'h40,8'hbf);check(n==1 && p==0 && b==0,"NEC40 next through real decoder and command merge");
  packet(8'h15,8'hea);check(n==1 && p==1 && b==0,"NEC15 previous without b/p reversal");
  packet(8'h44,8'hbb);check(n==1 && p==1 && b==1,"NEC44 toggles autoplay");
  level(0,9000);level(1,2250);level(0,560);level(1,100);
  check(b==1,"hold repeat cannot toggle autoplay repeatedly");
  packet(8'h40,8'h00);check(n==1,"invalid complement rejected");
  packet(8'h45,8'hba);check(n==1 && p==1 && b==1,"unsupported audio controls do not create duplicate state");
  check(tx && !overflow,"IR does not generate UART replies");
  rst=1;repeat(4)@(negedge clk);rst=0;packet(8'h40,8'hbf);
  check(n==2 && p==1 && b==1,"decode recovers after reset");
  if(errors==0)$display("ALL PASS tb_remote_ir: real NEC pins, mapped next/previous/toggle, bad CRC complement, ignored hold repeats, reset, no UART replies");
  else $display("FAILED tb_remote_ir %d",errors);
  $finish;
 end
 initial begin #10000000;$display("FAILED watchdog tb_remote_ir");$finish;end
endmodule
''',encoding='utf-8')
print('Connected real NEC decoder and registered IR integration test')
