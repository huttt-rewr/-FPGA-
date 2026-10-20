`timescale 1ns/1ps
// Real playback controller + BMP parser; sector transport replaced by a peer.
module tb_load_recovery;
 reg clk=0,rst=1,next_cmd=0;
 always #5 clk=~clk;
 reg peer_init=1,peer_end=0,peer_valid=0;reg [7:0] peer_data=0;
 wire busy,error,req;wire [2:0] count;
 integer errors=0,i;
 sd_card_bmp #(.CLK_FREQ_HZ(1000),.SCAN_MAX_SECTOR(0),.SCAN_TARGET_COUNT(1)) dut(
  .clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),
  .cmd_next(next_cmd),.cmd_prev(1'b0),.cmd_toggle(1'b0),.commit_ack_toggle(1'b0),
  .status_busy(busy),.status_error(error),.status_count(count),
  .bmp_width(16'd640),.bmp_height(16'd480),.write_finish_toggle(1'b0),
  .write_req(req),.write_req_ack(req),.SD_MISO(1'b1));
 function [7:0] hdr;input integer pos;begin
  case(pos)
   0:hdr=8'h42;1:hdr=8'h4d;2:hdr=8'h36;3:hdr=8'h10;4:hdr=8'h0e;
   10:hdr=54;14:hdr=40;18:hdr=8'h80;19:hdr=2;22:hdr=8'he0;23:hdr=1;
   26:hdr=1;28:hdr=24;default:hdr=0;
  endcase
 end endfunction
 task sector;begin
  wait(dut.sd_sec_read);repeat(3)@(negedge clk);
  for(i=0;i<512;i=i+1)begin peer_valid=1;peer_data=hdr(i);@(negedge clk);end
  peer_valid=0;peer_end=1;@(negedge clk);peer_end=0;
  wait(!dut.sd_sec_read);@(negedge clk);
 end endtask
 initial begin
  force dut.sd_init_done=peer_init;force dut.sd_sec_read_end=peer_end;
  force dut.sd_sec_read_data_valid=peer_valid;force dut.sd_sec_read_data=peer_data;
  repeat(4)@(negedge clk);rst=0;
  sector; // scan
  sector; // first load header
  wait(dut.bmp_read_m0.state==4); // deliberately truncate pixel payload
  wait(error);@(negedge clk);
  if(busy || count!=1 || !dut.scan_done)errors=errors+1;
  peer_init=0;repeat(12)@(negedge clk);peer_init=1;repeat(5)@(negedge clk);
  if(busy || !dut.bmp_ready || !dut.scan_done || count!=1)errors=errors+1;
  next_cmd=1;@(negedge clk);next_cmd=0;
  wait(busy);repeat(3)@(negedge clk);
  if(error || !dut.sd_sec_read)errors=errors+1;
  sector; // retry reaches data transfer again
  wait(dut.bmp_read_m0.state==4);
  if(errors==0)$display("ALL PASS tb_load_recovery: timeout releases busy, scan survives, retry starts");
  else $display("FAILED tb_load_recovery %0d",errors);
  $finish;
 end
 initial begin #200000;$display("FAILED watchdog tb_load_recovery");$finish;end
endmodule
