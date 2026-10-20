"""Register NEC duration predicates and their matching edges, in the same domain."""
from pathlib import Path
import json
root=Path(__file__).resolve().parents[2]
assert json.loads((root/'reports/build_manifest.json').read_text())['status']!='running'
p=root/'src/modules/control/ir_nec_rx.v'
s=p.read_text(encoding='utf-8-sig')
old='// ---- 状态机 ----'
assert old in s and 'ir_fall_q' not in s
block='''// Register all duration predicates WITH their matching edge. This splits
// duration compare -> protocol decision -> bit counter at 100MHz without
// changing threshold values or quantization. Published events gain one clock.
reg ir_fall_q,ir_rise_q;
reg leader_mark_q,bit_mark_q,leader_space_q,repeat_space_q,bit0_q,bit1_q;
always @(posedge clk or posedge rst)begin
 if(rst)begin
  ir_fall_q<=0;ir_rise_q<=0;leader_mark_q<=0;bit_mark_q<=0;
  leader_space_q<=0;repeat_space_q<=0;bit0_q<=0;bit1_q<=0;
 end else begin
  ir_fall_q<=ir_fall;ir_rise_q<=ir_rise;
  leader_mark_q<=is_leader_mark;bit_mark_q<=is_bit_mark;
  leader_space_q<=is_leader_space;repeat_space_q<=is_repeat_space;
  bit0_q<=is_bit0_space;bit1_q<=is_bit1_space;
 end
end

'''
head,body=s.split(old,1)
for before,after in [('is_leader_mark','leader_mark_q'),('is_bit_mark','bit_mark_q'),
 ('is_leader_space','leader_space_q'),('is_repeat_space','repeat_space_q'),
 ('is_bit0_space','bit0_q'),('is_bit1_space','bit1_q'),('ir_fall','ir_fall_q'),('ir_rise','ir_rise_q')]:
 body=body.replace(before,after)
p.write_text(head+block+old+body,encoding='utf-8')
p=root/'src/modules/control/remote_controls.v';s=p.read_text(encoding='utf-8')
old=' wire [7:0] ir_command;'
assert old in s
block=''' // Local release leaf keeps the new receiver/parser/reply cluster off
 // the shared control-reset fanout. Assertion remains asynchronous.
 (* preserve="true" *) reg remote_rst;
 always @(posedge clk or posedge rst)begin
  if(rst)remote_rst<=1;else remote_rst<=0;
 end
'''
s=s.replace(old,block+old)
s=s.replace('.rst(rst)', '.rst(remote_rst)').replace('receiver(clk,rst,','receiver(clk,remote_rst,')
p.write_text(s,encoding='utf-8')
# Compare every published decoder bit against the frozen pre-change decoder.
# The sole allowed difference is the intentional one-clock event pipeline.
p=root/'sim/tb_ir_nec_rx.v';s=p.read_text(encoding='utf-8-sig')
old='integer errors = 0;'
assert old in s
checker='''wire [7:0] reference_command;
wire reference_valid,reference_repeat;
ir_nec_rx_reference #(.CLK_FREQ(CLK_FREQ)) reference_decoder(
 clk,rst,ir_in,reference_command,reference_valid,reference_repeat);
reg [9:0] reference_q;
always @(posedge clk)begin
 if(rst)reference_q<=0;
 else reference_q<={reference_valid,reference_repeat,reference_command};
 #1;
 if(!rst && {command_valid,repeat_flag,command}!==reference_q)begin
  if(errors<5)$display("FAILED NEC pipeline differs from frozen reference");
  errors=errors+1;
 end
end
'''
s=s.replace(old,old+'\n'+checker)
anchor='    if (errors == 0)'
assert anchor in s
s=s.replace(anchor,'''    // Timing-window boundaries, compared cycle-by-cycle with original.
    mark_us(6999);space_us(3500);mark_us(300);space_us(900);
    mark_us(7000);space_us(3499);mark_us(900);space_us(1200);
    mark_us(12000);space_us(6000);mark_us(901);space_us(2500);
    mark_us(12001);space_us(6001);mark_us(560);space_us(2501);
    #10000;
'''+anchor)
reference=(root/'reports/remote_album_20261019/before/src/modules/control/ir_nec_rx.v').read_text(encoding='utf-8-sig')
reference=reference.replace('module ir_nec_rx #(', 'module ir_nec_rx_reference #(')
p.write_text(s+'\n// Frozen pre-pipeline protocol reference, simulation only.\n'+reference,encoding='utf-8')
print('Pipelined NEC classifications/edges and local remote reset release')
