`timescale 1ns/1ps
module tb_scaled_svga;
 reg clk=0,rst=1,load=0,scan=0,abort_load=0;
 always #5 clk=~clk;
 reg [7:0] disk[0:6222335];reg [23:0] expected[0:479999];
 reg [7:0] din=0;reg dv=0,se=0,pr=1;
 wire read,wr,ready,pv,stall,found,scan_done;wire [31:0] addr;wire [23:0] pixel;
 wire [11:0] width,height;
 integer errors=0,count=0,testcase=0,cycle=0,bytes=0,sector_pos=0,sector_delay=0;
 integer transport=0,sector_limit=512,base_pos=0,i;
 reg short_sector=0,active=0;
 reg [1023:0] filename;
 bmp_read #(.ENABLE_SCALING(1),.ADAPTIVE(1)) dut(.clk(clk),.rst(rst),.ready(ready),
  .scan_start(scan),.scan_start_sector(32'd0),.scan_max_sector(32'd131071),.scan_target_count(3'd1),
  .scan_done(scan_done),.scan_found_valid(found),.load_start(load),.load_abort(abort_load),
  .load_sector(32'd0),.sd_init_done(1'b1),.bmp_width(16'd800),.bmp_height(16'd600),
  .write_req(wr),.write_req_ack(wr),.sd_sec_read(read),.sd_sec_read_addr(addr),
  .sd_sec_read_data(din),.sd_sec_read_data_valid(dv),.sd_sec_read_end(se),
  .bmp_data_wr_en(pv),.bmp_data(pixel),.read_stall(stall),.pixel_ready(pr),
  .source_width(width),.source_height(height));
 // Sector peer: no byte-stream backpressure, intermittent valid gaps, exact 512 bytes.
 always @(negedge clk)begin
  cycle=cycle+1;dv=0;se=0;pr=(cycle%43<31);
  if(rst || abort_load)begin transport=0;sector_pos=0;end
  else case(transport)
   0:if(read)begin
    base_pos=addr*512;sector_pos=0;sector_limit=short_sector?111:512;transport=1;
    if(base_pos<0 || base_pos+512>bytes)begin errors=errors+1;$display("FAILED out of file sector %d",addr);end
   end
   1:if(cycle%7!=0)begin
    dv=1;din=disk[base_pos+sector_pos];sector_pos=sector_pos+1;
    if(sector_pos==sector_limit)transport=2;
   end
   2:begin se=1;transport=3;end
   3:if(!read)transport=0;
  endcase
 end
 always @(posedge clk)if(pv)begin
  if(!pr)begin errors=errors+1;$display("FAILED output despite backpressure");end
  if(active && (count>=480000 || pixel!==expected[count]))begin
   if(errors<10)$display("FAILED case=%0d pixel=%0d actual=%h expected=%h",testcase,count,pixel,expected[count]);
   errors=errors+1;
  end
  count=count+1;
 end
 task reset_dut;begin
  @(posedge clk);#2;rst=1;active=0;load=0;scan=0;abort_load=0;short_sector=0;
  repeat(5)@(posedge clk);#2;rst=0;count=0;
 end endtask
 task launch;begin @(posedge clk);#2;load=1;@(posedge clk);#2;load=0;end endtask
 initial begin
  for(testcase=0;testcase<9;testcase=testcase+1)begin
   reset_dut;
   $sformat(filename,"../reports/screen_adapt_20261010/vectors/case%0d.hex",testcase);$readmemh(filename,disk);
   $sformat(filename,"../reports/screen_adapt_20261010/vectors/expected%0d.hex",testcase);$readmemh(filename,expected);
   bytes=({disk[5],disk[4],disk[3],disk[2]}+511)/512*512;
   @(posedge clk);#2;scan=1;@(posedge clk);#2;scan=0;
   wait(scan_done);repeat(5)@(posedge clk);#2;
   if(!ready || dut.scan_found_total!=1)begin errors=errors+1;$display("FAILED scanning variable header");end
   active=1;launch;wait(!ready);wait(ready);repeat(5)@(posedge clk);#2;
   if(count!=480000 || stall)begin errors=errors+1;$display("FAILED incomplete scaled output %0d",count);end
   $display("case %0d: %0dx%0d -> 800x600, pixels=%0d errors=%0d",testcase,width,height,count,errors);
  end
  // Abort during source sector transfer, then load again with no stale row/cache data.
  reset_dut;launch;wait(dut.state==5 && read);@(posedge clk);#2;abort_load=1;
  repeat(4)@(posedge clk);#2;abort_load=0;
  repeat(5)@(posedge clk);#2;if(!ready || read || pv)errors=errors+1;
  count=0;active=1;launch;wait(!ready);wait(ready);
  if(count!=480000)errors=errors+1;
  // Truncated source sector must report failure; no completed frame/commit is fabricated.
  reset_dut;launch;wait(dut.state==5);short_sector=1;wait(stall);
  if(count!=0 || ready)begin errors=errors+1;$display("FAILED short sector not quarantined");end
  abort_load=1;repeat(5)@(posedge clk);#2;
  if(!ready)errors=errors+1;
  if(errors==0)$display("ALL PASS tb_scaled_svga: 9 full frames, bilinear RGB reference, padding, extended offsets, scan, backpressure, abort/reload, truncated sector");
  else $display("FAILED tb_scaled_svga errors=%0d",errors);
  $finish;
 end
 initial begin #2000000000;$display("FAILED watchdog scaled BMP");$finish;end
endmodule
