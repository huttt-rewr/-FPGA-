//======================================================================
// tb_uart_rx.v —— UART 接收自测
//
// 验证：发两个字节 0xA5、0x3C（8N1、LSB 先），期望依次收到且 o_valid 各一拍。
//
// 运行（iverilog）：
//   cd myproject
//   iverilog -o tb_uart.vvp src/modules/control/uart_rx.v sim/tb_uart_rx.v
//   vvp tb_uart.vvp
//======================================================================
`timescale 1ns/1ps
module tb_uart_rx;

localparam CLK_FREQ = 100_000_000;
localparam BAUD     = 115200;
localparam BIT_T    = 1_000_000_000 / BAUD;   // 位周期(ns) = 8680

reg        clk, rst, rx;
wire [7:0] o_data;
wire       o_valid;

uart_rx #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD)) dut (
    .clk(clk), .rst(rst), .rx(rx),
    .o_data(o_data), .o_valid(o_valid)
);

always #5 clk = ~clk;   // 100MHz

task send_byte(input [7:0] b);
    integer j;
    begin
        rx = 1'b0;                     // 起始位
        #BIT_T;
        for (j = 0; j < 8; j = j + 1) begin
            rx = b[j];                 // LSB 先
            #BIT_T;
        end
        rx = 1'b1;                     // 停止位
        #BIT_T;
        rx = 1'b1;
    end
endtask

// 收集收到的字节
reg [7:0] q [0:7];
integer   q_cnt = 0;
always @(posedge clk) begin
    if (o_valid) begin
        q[q_cnt] = o_data;
        q_cnt = q_cnt + 1;
    end
end

integer errors = 0;
task check(input [255:0] name, input cond);
begin
    if (cond) $display("[PASS] %0s", name);
    else begin $display("[FAIL] %0s", name); errors = errors + 1; end
end
endtask

initial begin
    clk = 0; rst = 1; rx = 1'b1;
    #20 rst = 0;
    #1000;

    send_byte(8'hA5);
    #(BIT_T * 3);                       // 等一帧间隔
    send_byte(8'h3C);
    #(BIT_T * 3);

    check("收到 2 个字节", q_cnt == 2);
    check("第 1 字节 == 0xA5", q_cnt >= 1 && q[0] == 8'hA5);
    check("第 2 字节 == 0x3C", q_cnt >= 2 && q[1] == 8'h3C);
    $display("   收到 %0d 个字节：%h %h", q_cnt, q[0], q[1]);

    if (errors == 0)
        $display("\n=== tb_uart_rx ALL PASS ===");
    else
        $display("\n=== tb_uart_rx FAILED: %0d 项 ===", errors);
    $finish;
end

endmodule
