//======================================================================
// tb_ir_nec_rx.v —— NEC 红外解码自测
//
// 验证：发一帧 NEC（地址 0x00 + 反码 0xFF + 命令 0x1A + 反码 0xE5），
//       期望解出 command=0x1A 并给出一拍 command_valid；再发一个重复码，
//       期望给出 o_repeat。
//
// 运行（iverilog）：
//   cd myproject
//   iverilog -o tb_ir.vvp src/modules/control/ir_nec_rx.v sim/tb_ir_nec_rx.v
//   vvp tb_ir.vvp
//======================================================================
`timescale 1ns/1ps
module tb_ir_nec_rx;

localparam CLK_FREQ = 100_000_000;

reg        clk, rst, ir_in;
wire [7:0] command;
wire       command_valid, repeat_flag;

ir_nec_rx #(.CLK_FREQ(CLK_FREQ)) dut (
    .clk            (clk),
    .rst            (rst),
    .ir_in          (ir_in),
    .o_command      (command),
    .o_command_valid(command_valid),
    .o_repeat       (repeat_flag)
);

always #5 clk = ~clk;   // 100MHz

// 驱动 mark（低）/ space（高），t 单位 us
task mark_us(input integer t); begin ir_in = 1'b0; #(t*1000); end endtask
task space_us(input integer t); begin ir_in = 1'b1; #(t*1000); end endtask

// 发一个字节（LSB 先）：位0=560us低+560us高，位1=560us低+1690us高
task send_byte(input [7:0] b);
    integer j;
    begin
        for (j = 0; j < 8; j = j + 1) begin
            mark_us(560);
            if (b[j]) space_us(1690);
            else      space_us(560);
        end
    end
endtask

// 采样命令输出
reg        got_valid, got_repeat;
reg [7:0]  got_cmd;
always @(posedge clk) begin
    if (command_valid) begin
        got_valid <= 1'b1;
        got_cmd   <= command;
    end
    if (repeat_flag) got_repeat <= 1'b1;
end

integer errors = 0;
task check(input [255:0] name, input cond);
begin
    if (cond) $display("[PASS] %0s", name);
    else begin $display("[FAIL] %0s", name); errors = errors + 1; end
end
endtask

initial begin
    clk = 0; rst = 1; ir_in = 1'b1;
    got_valid = 0; got_cmd = 0; got_repeat = 0;

    #20 rst = 0;
    #1000;

    // ---- 第一帧：地址 0x00，命令 0x1A ----
    mark_us(9000); space_us(4500);       // 引导码
    send_byte(8'h00);                    // 地址
    send_byte(8'hFF);                    // 地址反码
    send_byte(8'h1A);                    // 命令
    send_byte(8'hE5);                    // 命令反码
    mark_us(560); ir_in = 1'b1;          // 结束 mark

    #20000;  // 等待解码完成
    check("命令码 == 0x1A", got_valid && got_cmd == 8'h1A);
    $display("   got_valid=%0b got_cmd=%h", got_valid, got_cmd);

    // ---- 第二帧：重复码 ----
    got_valid = 0; got_repeat = 0;
    mark_us(9000); space_us(2250);       // 重复码：9ms低 + 2.25ms高
    mark_us(560); ir_in = 1'b1;          // 结束 mark：用下降沿关闭重复 space，触发检测
    #100000;                             // 等待 o_repeat 单拍脉冲被采样到
    check("重复码 o_repeat 触发", got_repeat == 1'b1);

    // ---- 第三帧：错误地址反码应被拒（命令反码故意发错）----
    got_valid = 0;
    mark_us(9000); space_us(4500);
    send_byte(8'h00);
    send_byte(8'h00);                    // 反码错误（应为 0xFF）
    send_byte(8'h1A);
    send_byte(8'hE5);
    mark_us(560); ir_in = 1'b1;
    #20000;
    check("反码不匹配 -> 不输出 command_valid", got_valid == 1'b0);

    if (errors == 0)
        $display("\n=== tb_ir_nec_rx ALL PASS ===");
    else
        $display("\n=== tb_ir_nec_rx FAILED: %0d 项 ===", errors);
    $finish;
end

endmodule
