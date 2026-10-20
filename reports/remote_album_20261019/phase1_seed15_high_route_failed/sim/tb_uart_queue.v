`timescale 1ns/1ps
module tb_uart_queue;
 reg clk=0,rst=1,send=0;reg [7:0] data=0;
 always #5 clk=~clk;
 wire tx,busy,overflow,valid;wire [7:0] decoded;
 uart_tx_queue #(.CLK_FREQ(16000000),.BAUD(100000)) dut(clk,rst,data,send,tx,busy,overflow);
 uart_rx #(.CLK_FREQ(16000000),.BAUD(100000)) rx(clk,rst,tx,decoded,valid);
 integer received=0,errors=0,i;
 always @(posedge clk) if(valid) begin
  if(decoded!==8'h40+received) begin errors=errors+1;$display("Mismatch byte %0d got %h",received,decoded);end
  received=received+1;
 end
 initial begin
  repeat(4) @(negedge clk);rst=0;
  for(i=0;i<16;i=i+1) begin @(negedge clk);data=8'h40+i;send=1;end
  @(negedge clk);send=0;
  repeat(27000) @(negedge clk);
  if(received!=16 || busy || overflow) begin errors=errors+1;$display("UART received=%0d busy=%b overflow=%b",received,busy,overflow);end
  for(i=0;i<20;i=i+1) begin @(negedge clk);send=1;end
  @(negedge clk);send=0;
  if(!overflow) errors=errors+1;
  if(errors==0)$display("ALL PASS tb_uart_queue: 16 ordered replies and overflow flag");
  else $display("FAILED tb_uart_queue %0d",errors);
  $finish;
 end
endmodule
