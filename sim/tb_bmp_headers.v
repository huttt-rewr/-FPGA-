`timescale 1ns/1ps
module tb_bmp_headers;
reg clk=0,rst=1,scan=0,load=0,valid=0,sector_end=0;
reg [7:0] din=0;
reg [7:0] header[0:511];
wire ready,done,found,wrreq,read;
integer i,errors=0,found_count=0;
always #5 clk=~clk;
bmp_read dut(.clk(clk),.rst(rst),.ready(ready),.scan_start(scan),
 .scan_start_sector(32'd0),.scan_max_sector(32'd0),.scan_target_count(3'd1),
 .scan_done(done),.scan_found_valid(found),.load_start(load),.load_abort(1'b0),
 .load_sector(32'd0),.sd_init_done(1'b1),.bmp_width(16'd640),.bmp_height(16'd480),
 .write_req(wrreq),.write_req_ack(1'b0),.sd_sec_read(read),
 .sd_sec_read_data(din),.sd_sec_read_data_valid(valid),.sd_sec_read_end(sector_end));
always @(posedge clk) if(found) found_count=found_count+1;
task put32;input integer offset;input [31:0] value;begin
 header[offset]=value;header[offset+1]=value>>8;header[offset+2]=value>>16;header[offset+3]=value>>24;
end endtask
task make_header;input [31:0] dib;input [15:0] planes;input integer offset;begin
 for(i=0;i<512;i=i+1)header[i]=0;
 header[0]=8'h42;header[1]=8'h4d;put32(2,offset+921600);put32(10,offset);
 put32(14,dib);put32(18,640);put32(22,480);header[26]=planes;header[27]=planes>>8;header[28]=24;
end endtask
task send_header;input integer bytes;begin
 wait(read);repeat(3)@(negedge clk);
 for(i=0;i<bytes;i=i+1)begin valid=1;din=header[i];@(negedge clk);end
 valid=0;sector_end=1;@(negedge clk);sector_end=0;repeat(5)@(negedge clk);
end endtask
task check_scan;input [31:0] dib;input [15:0] planes;input integer offset;input integer bytes;input integer expected;begin
 rst=1;repeat(3)@(negedge clk);rst=0;found_count=0;
 make_header(dib,planes,offset);scan=1;@(negedge clk);scan=0;send_header(bytes);
 if(!ready || !done || found_count!=expected)begin
  errors=errors+1;$display("FAILED case dib=%0d planes=%0d bytes=%0d found=%0d",dib,planes,bytes,found_count);
 end
end endtask
initial begin
 check_scan(40,1,54,512,1);check_scan(108,1,122,512,1);check_scan(124,1,138,512,1);
 check_scan(12,1,54,512,0);check_scan(0,1,54,512,0);check_scan(64,1,78,512,0);
 check_scan(32'hffffffff,1,54,512,0);check_scan(40,0,54,512,0);check_scan(40,2,54,512,0);
 check_scan(108,1,121,512,0);check_scan(124,1,137,512,0);
 check_scan(40,1,4096,512,1);check_scan(40,1,4097,512,0);
 check_scan(124,1,54,512,0);check_scan(40,1,54,34,0);
 check_scan(40,1,54,512,1);
 // No reset: a truncated subsequent load must not reuse the previous valid header.
 load=1;@(negedge clk);load=0;send_header(2);
 if(wrreq || !ready)errors=errors+1;
 // A malformed full header must also be rejected in the load path.
 make_header(40,2,54);load=1;@(negedge clk);load=0;send_header(512);
 if(wrreq || !ready)errors=errors+1;
 if(errors==0)$display("ALL PASS tb_bmp_headers: DIB, planes, offset and stale/truncated header rejection");
 else $display("FAILED tb_bmp_headers errors=%0d",errors);
 $finish;
end
initial begin #200000;$display("FAILED watchdog tb_bmp_headers");$finish;end
endmodule
