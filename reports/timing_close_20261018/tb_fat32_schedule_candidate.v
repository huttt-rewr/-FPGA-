`timescale 1ns/1ps
module tb_fat32_schedule;
 reg clk=0,rst=1;
 always #5 clk=~clk;
 integer errors=0,cases=0,i,j;
 reg [31:0] rng=32'h19834a51;
 wire br,ar,rbr,rar,be,ae,berr,aerr,rbe,rae,rberr,raerr;
 sd_fat32 dut(.clk(clk),.rst(rst),.sd_init_done(1'b1),
  .bmp_req(1'b0),.bmp_file_idx(3'd0),.bmp_rel_sector(32'd0),.bmp_abort(1'b0),
  .aud_req(1'b0),.aud_rel_sector(32'd0),.aud_file_idx(6'd0),.aud_abort(1'b0),
  .arb_bmp_req(br),.arb_aud_req(ar),.bmp_end(be),.aud_end(ae),.bmp_error(berr),.aud_error(aerr),
  .arb_bmp_data(8'd0),.arb_bmp_valid(1'b0),.arb_bmp_end(1'b0),.arb_bmp_error(1'b0),.arb_bmp_grant(1'b0),
  .arb_aud_data(8'd0),.arb_aud_valid(1'b0),.arb_aud_end(1'b0),.arb_aud_error(1'b0));
 sd_fat32_reference reference(.clk(clk),.rst(rst),.sd_init_done(1'b1),
  .bmp_req(1'b0),.bmp_file_idx(3'd0),.bmp_rel_sector(32'd0),.bmp_abort(1'b0),
  .aud_req(1'b0),.aud_rel_sector(32'd0),.aud_file_idx(6'd0),.aud_abort(1'b0),
  .arb_bmp_req(rbr),.arb_aud_req(rar),.bmp_end(rbe),.aud_end(rae),.bmp_error(rberr),.aud_error(raerr),
  .arb_bmp_data(8'd0),.arb_bmp_valid(1'b0),.arb_bmp_end(1'b0),.arb_bmp_error(1'b0),.arb_bmp_grant(1'b0),
  .arb_aud_data(8'd0),.arb_aud_valid(1'b0),.arb_aud_end(1'b0),.arb_aud_error(1'b0));
 task step;
  begin
   @(posedge clk);#1;
   if({dut.state,dut.working_cluster,dut.working_index,dut.request_sectors,br,ar,be,ae,berr,aerr}!==
      {reference.state,reference.working_cluster,reference.working_index,reference.request_sectors,rbr,rar,rbe,rae,rberr,raerr})begin
    errors=errors+1;
    if(errors<10)$display("FAILED FAT32 schedule case=%0d state=%h ref=%h",cases,dut.state,reference.state);
   end
  end
 endtask
 task run_request;
  input [31:0] size_bytes,relative_sector;
  input [23:0] target,cursor;
  input [31:0] volume_clusters;
  input [3:0] flags;
  begin
   @(negedge clk);
   dut.state=dut.STREAM_LIMIT;reference.state=reference.STREAM_LIMIT;
   dut.request_size=size_bytes;reference.request_size=size_bytes;
   dut.request_rel=relative_sector;reference.request_rel=relative_sector;
   dut.target_index=target;reference.target_index=target;
   dut.data_clusters=volume_clusters;reference.data_clusters=volume_clusters;
   dut.max_cluster=32'h0fffffef;reference.max_cluster=32'h0fffffef;
   dut.owner=flags[0];reference.owner=flags[0];
   dut.request_file=1;reference.request_file=1;
   dut.bmp_count=4;reference.bmp_count=4;
   dut.wav_found=flags[3];reference.wav_found=flags[3];
   dut.cursor_valid={2{flags[1]}};reference.cursor_valid={2{flags[1]}};
   dut.wav_cluster=32'd8;reference.wav_cluster=32'd8;
   dut.mount_fat=0;reference.mount_fat=0;
   for(j=0;j<2;j=j+1)begin
    dut.cursor_index[j]=cursor;reference.cursor_index[j]=cursor;
    dut.cursor_cluster[j]=32'd10;reference.cursor_cluster[j]=32'd10;
    dut.cursor_file[j]=flags[2]?1:2;reference.cursor_file[j]=flags[2]?1:2;
   end
   for(j=0;j<4;j=j+1)begin dut.image_cluster[j]=8;reference.image_cluster[j]=8;end
   step; // limit -> apply
   step; // apply -> check; sector comparison partials become available here
   step; // check -> prep
   if(dut.stream_bad!==reference.stream_bad)begin
    errors=errors+1;$display("FAILED FAT32 stream guard case=%0d",cases);
   end
   step; // unchanged decision and request latency
   // Follow a FAT chain without returning through CURSOR_APPLY. The original
   // request's sector-range result must survive every subsequent cluster hop.
   @(negedge clk);
   dut.state=dut.FAT_VALIDATE;reference.state=reference.FAT_VALIDATE;
   dut.next_cluster=11;reference.next_cluster=11;
   dut.fat_target=10;reference.fat_target=10;
   step;step;step;
   if(dut.stream_bad!==reference.stream_bad)begin
    errors=errors+1;$display("FAILED FAT32 range flag lost across FAT hop case=%0d",cases);
   end
   cases=cases+1;
  end
 endtask
 initial begin
  repeat(3)@(negedge clk);rst=0;
  for(i=0;i<16;i=i+1)begin
   run_request(1024,0,0,0,32'h01000000,i);
   run_request(32'hffffffff,32'h007fffff,24'hffffff,24'hffffff,32'hffffffff,i);
   run_request(32'hffffffff,32'h00800000,24'h010000,24'h00ffff,32'h02000000,i);
   run_request(512,32'hffffffff,24'h00ffff,24'h010000,32'h00010000,i);
   run_request(0,0,0,0,0,i);
  end
  for(i=0;i<512;i=i+1)begin
   rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
   run_request(rng,rng^32'hac38b71f,rng[23:0],rng[31:8],32'h0fffffee,rng[3:0]);
   run_request(rng,{9'd0,rng[31:9]},rng[23:0],rng[23:0],32'hffffffff,4'hf);
  end
  if(errors==0)$display("ALL PASS tb_fat32_schedule: %0d requests, original reference, cursor ownership, unchanged state/handshake cycles and range predicates retained across FAT hops",cases);
  else $display("FAILED FAT32 schedule errors=%0d",errors);
  $finish;
 end
 initial begin #1000000;$display("FAILED FAT32 schedule timeout");$finish;end
endmodule
