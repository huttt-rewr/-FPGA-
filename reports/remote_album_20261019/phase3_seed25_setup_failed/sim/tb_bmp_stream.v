`timescale 1ns/1ps
module tb_bmp_stream;
 reg clk=0,rst=1,scan=0,load=0,valid=0,sector_end=0;reg [7:0] din=0;
 always #5 clk=~clk;
 wire ready,done,found,wrreq,read,en;wire [31:0] addr;wire [23:0] pixel;
 integer errors=0,pixels=0,b,s,k;reg [7:0] value;
 bmp_read dut(.clk(clk),.rst(rst),.ready(ready),.scan_start(scan),
  .scan_start_sector(32'd0),.scan_max_sector(32'd0),.scan_target_count(3'd1),
  .scan_done(done),.scan_found_valid(found),.load_start(load),.load_abort(1'b0),
  .load_sector(32'd0),.sd_init_done(1'b1),.bmp_width(16'd640),.bmp_height(16'd480),
  .write_req(wrreq),.write_req_ack(wrreq),.sd_sec_read(read),.sd_sec_read_addr(addr),
  .sd_sec_read_data(din),.sd_sec_read_data_valid(valid),.sd_sec_read_end(sector_end),
  .bmp_data_wr_en(en),.bmp_data(pixel));
 function [7:0] byte_at;input integer pos;integer n;begin
  if(pos>=54 && pos<921654)begin n=pos-54;byte_at=(n/3+(n%3)*17)%256;end
  else case(pos)
   0:byte_at=8'h42;1:byte_at=8'h4d;2:byte_at=8'h36;3:byte_at=8'h10;4:byte_at=8'h0e;
   10:byte_at=54;14:byte_at=40;18:byte_at=8'h80;19:byte_at=2;
   22:byte_at=8'he0;23:byte_at=1;26:byte_at=1;28:byte_at=24;default:byte_at=0;
  endcase
 end endfunction
 always @(posedge clk)if(en)begin
  if(pixel!=={byte_at(54+pixels*3+2),byte_at(54+pixels*3+1),byte_at(54+pixels*3)})errors=errors+1;
  pixels=pixels+1;
 end
 task sector;input integer offset;begin
  wait(read);repeat(2)@(negedge clk);
  for(b=0;b<512;b=b+1)begin valid=1;din=byte_at(offset+b);@(negedge clk);end
  valid=0;sector_end=1;@(negedge clk);sector_end=0;@(negedge clk);
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;scan=1;@(negedge clk);scan=0;
  sector(0);wait(done);@(negedge clk);load=1;@(negedge clk);load=0;
  sector(0);wait(dut.state==4);
  for(s=0;s<1801;s=s+1)begin
   wait(read);if(addr!==s)errors=errors+1;sector(s*512);
  end
  repeat(5)@(negedge clk);
  if(pixels!=307200 || !ready || !done)errors=errors+1;
  if(errors==0)$display("ALL PASS tb_bmp_stream: 307200 RGB pixels, 1801 sectors, exact channel order");
  else $display("FAILED tb_bmp_stream %0d pixels=%0d",errors,pixels);
  $finish;
 end
 initial begin #20000000;$display("FAILED watchdog tb_bmp_stream");$finish;end
endmodule
