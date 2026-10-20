`timescale 1ns/1ps
// White-box arithmetic boundaries complement the full-frame golden tests.
module tb_scaler_row_address;
 reg clk=0,rst=1;
 always #5 clk=~clk;
 wire sector_read,pixel_valid,done,error,busy;
 wire [31:0] sector_address;
 wire [23:0] pixel;
 reg [11:0] probe_y;
 reg [12:0] probe_stride;
 reg [31:0] probe_offset;
 reg [32:0] probe_state;
 reg [63:0] reference;
 reg [31:0] expected;
 integer errors=0,checks=0,row;
 bmp_scale_loader dut(.clk(clk),.rst(rst),.start(1'b0),
  .source_width(12'd1920),.source_height(12'd1080),
  .pixel_offset(32'd4096),.base_sector(32'd37),
  .sector_read(sector_read),.sector_address(sector_address),
  .sector_data(8'd0),.sector_valid(1'b0),.sector_end(1'b0),
  .pixel(pixel),.pixel_valid(pixel_valid),.pixel_ready(1'b1),
  .done(done),.error(error),.busy(busy),.mode_800(1'b0));
 task check;
  input ok;input [511:0] message;
  begin checks=checks+1;if(ok!==1)begin
   errors=errors+1;$display("FAILED row-address %0s y=%0d stride=%0d offset=%h actual=%h expected=%h",
    message,probe_y,probe_stride,probe_offset,dut.byte_address,expected);
  end end
 endtask
 task address;
  input [11:0] y;input [12:0] stride;input [31:0] offset;
  begin
   @(negedge clk);probe_y=y;probe_stride=stride;probe_offset=offset;
   reference={52'd0,y}*{51'd0,stride}+{32'd0,offset};expected=reference[31:0];
   probe_state=33'h40;
   @(posedge clk);#1;
   check(dut.byte_address[15:0]===expected[15:0],"low-half sum");
   check(!sector_read,"partial address never requests SD");
   @(negedge clk);probe_state=33'h100000000;
   @(posedge clk);#1;
   check(dut.byte_address===expected,"complete modulo-32 address");
   check(dut.byte_address[31:9]===expected[31:9],"sector boundary");
   if(y==1079)$display("1920x1080 last row: offset=%h y=%0d stride=%0d byte_address=%h reference=%h",
    offset,y,stride,dut.byte_address,expected);
   @(negedge clk);probe_state=33'h200;
   @(posedge clk);#1;expected=expected+1'b1;
   check(dut.byte_address===expected,"next byte including carry/wrap");
  end
 endtask
 initial begin
  repeat(3)@(negedge clk);rst=0;
  force dut.load_y=probe_y;force dut.stride=probe_stride;
  force dut.offset=probe_offset;force dut.state=probe_state;
  // Every row of a real 1920x1080 BGR24 image, including 64K carries.
  for(row=0;row<1080;row=row+1)address(row,5760,4096);
  address(1,4,32'h0000fffc);address(1,4,32'hfffffffc);
  address(0,5760,32'hffffffff);address(4095,8191,32'hfffffff0);
  address(1,512,32'h000001ff);address(0,4,32'h000001ff);
  // Assert reset between low and high halves: stale carry must be discarded.
  @(negedge clk);probe_state=33'h40;probe_y=1;probe_stride=4;probe_offset=32'hfffc;
  @(posedge clk);#1;check(dut.byte_address_carry,"carry prepared before reset");
  rst=1;#1;check(dut.byte_address===0 && dut.byte_address_carry===0,"asynchronous reset clears partial sum");
  @(negedge clk);rst=0;
  address(0,4,32'h12340000);
  release dut.load_y;release dut.stride;release dut.offset;release dut.state;
  if(errors==0)$display("ALL PASS tb_scaler_row_address: %0d checks, all 1080 source rows, low carry, high wrap, sector crossings, increment and reset",checks);
  else $display("FAILED row-address errors=%0d",errors);
  $finish;
 end
 initial begin #1000000;$display("FAILED row-address watchdog");$finish;end
endmodule
