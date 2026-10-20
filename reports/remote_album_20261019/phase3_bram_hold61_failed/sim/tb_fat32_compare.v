`timescale 1ns/1ps
// White-box boundary test: execute the real STREAM_LIMIT/STREAM_CHECK states.
// The reference retains the original 33-bit comparison and every other guard.
module tb_fat32_compare;
 reg clk=0,rst=1;
 always #5 clk=~clk;
 wire br,ar;
 integer errors=0,cases=0,i,j,k;
 reg [31:0] sizes[0:9],rels[0:9];
 reg [31:0] clusters[0:13];
 reg [31:0] random_size,random_rel;
 reg [32:0] sectors;
 reg expected;
 sd_fat32 dut(.clk(clk),.rst(rst),.sd_init_done(1'b1),
  .bmp_req(1'b0),.bmp_file_idx(3'd0),.bmp_rel_sector(32'd0),
  .aud_req(1'b0),.aud_rel_sector(32'd0),.bmp_abort(1'b0),
  .aud_file_idx(6'd0),.aud_abort(1'b0),
  .arb_bmp_req(br),.arb_bmp_data(8'd0),.arb_bmp_valid(1'b0),
  .arb_bmp_end(1'b0),.arb_bmp_error(1'b0),.arb_bmp_grant(1'b0),
  .arb_aud_req(ar),.arb_aud_data(8'd0),.arb_aud_valid(1'b0),
  .arb_aud_end(1'b0),.arb_aud_error(1'b0));
 task check;
  input ok;input [511:0] msg;
  begin if(ok!==1'b1)begin errors=errors+1;
   $display("FAILED FAT32 compare case=%0d size=%h rel=%h %0s",cases,random_size,random_rel,msg);
  end end
 endtask
 task run_cluster;
  input [31:0] candidate,maximum;
  begin
   @(negedge clk);dut.state=dut.FAT_VALIDATE;
   dut.next_cluster=candidate;dut.max_cluster=maximum;
   expected=candidate>=2 && candidate<=maximum && candidate<32'h0ffffff0;
   @(posedge clk);#1;
   if(dut.cluster_ok!==expected)begin errors=errors+1;
    $display("FAILED FAT32 cluster next=%h max=%h actual=%b expected=%b",candidate,maximum,dut.cluster_ok,expected);
   end
   cases=cases+1;
  end
 endtask
 task run_case;
  input [31:0] size_bytes,relative_sector;
  input integer guard;
  begin
   random_size=size_bytes;random_rel=relative_sector;
   @(negedge clk);
   dut.state=dut.STREAM_LIMIT;
   dut.request_size=size_bytes;dut.request_rel=relative_sector;
   dut.owner=(guard==1 || guard==7);
   dut.wav_found=(guard!=1);dut.bmp_count=4;
   dut.request_file=(guard==2)?6'd4:6'd0;
   dut.target_index=(guard>=8 && guard<=10)?24'hffffff:
    (guard==11)?24'd1:(guard==12)?24'h800000:(guard==3)?24'd100:24'd0;
   dut.data_clusters=(guard==8)?32'h01000000:(guard==9)?32'hffffffff:
    (guard==10 || guard==12)?32'h00ffffff:(guard==11)?32'd0:
    (guard==13)?32'h00800000:32'd100;
   dut.max_cluster=101;
   dut.working_cluster=(guard==4)?0:(guard==5)?1:(guard==6)?102:2;
   sectors=({1'b0,size_bytes}+33'd511)>>9;
   @(posedge clk);#1;
   check(dut.request_sectors===sectors,"ceil(bytes/512), including carry into bit23");
   check(dut.request_sectors[32:24]===9'd0,"upper sector bits are zero");
   // Execute the real CURSOR_APPLY state instead of forcing STREAM_CHECK.
   // Restore the chosen cluster boundary after the cursor is applied.
   @(posedge clk);#1;
   @(negedge clk);
   dut.working_cluster=(guard==4)?0:(guard==5)?1:(guard==6)?102:2;
   expected=(dut.owner && !dut.wav_found) || (!dut.owner && dut.request_file>=dut.bmp_count) ||
    size_bytes==0 || {1'b0,relative_sector}>=sectors || dut.target_index>=dut.data_clusters ||
    dut.working_cluster<2 || dut.working_cluster>dut.max_cluster;
   @(posedge clk);#1;
   check(dut.stream_bad===expected,"registered full guard equals original 33-bit expression");
   check(!br && !ar,"range checking must not occupy SD channel");
   cases=cases+1;
  end
 endtask
 initial begin
  sizes[0]=0;sizes[1]=1;sizes[2]=511;sizes[3]=512;sizes[4]=513;
  sizes[5]=32'hfffffe00;sizes[6]=32'hfffffe01;sizes[7]=32'hffffffff;
  sizes[8]=32'h80000000;sizes[9]=32'h01000000;
  rels[0]=0;rels[1]=32'h007fffff;rels[2]=32'h00800000;
  rels[3]=32'h01000000;rels[4]=32'h7fffffff;rels[5]=32'hffffffff;
  rels[6]=1;rels[7]=32'h00800001;rels[8]=32'h00ffffff;rels[9]=32'h80000000;
  repeat(3)@(negedge clk);rst=0;
  for(i=0;i<10;i=i+1)for(j=0;j<10;j=j+1)for(k=0;k<8;k=k+1)
   run_case(sizes[i],rels[j],k);
  // A large volume is not bounded by the size of one file. Isolate that guard.
  for(k=8;k<14;k=k+1)run_case(1024,0,k);
  // Exercise both sides of each exact ceiling as well as broad 32-bit values.
  for(i=0;i<512;i=i+1)begin
   random_size=$random;random_rel=$random;
   run_case(random_size,random_rel,0);
   sectors=({1'b0,random_size}+33'd511)>>9;
   run_case(random_size,sectors[31:0],0);
   if(sectors!=0)run_case(random_size,sectors[31:0]-1'b1,7);
  end
  clusters[0]=0;clusters[1]=1;clusters[2]=2;clusters[3]=32'h0000ffff;
  clusters[4]=32'h00010000;clusters[5]=32'h00ffffff;clusters[6]=32'h01000000;
  clusters[7]=32'h0fffffef;clusters[8]=32'h0ffffff0;clusters[9]=32'h0ffffff8;
  clusters[10]=32'h0fffffff;clusters[11]=32'h10000000;
  clusters[12]=32'h80000000;clusters[13]=32'hffffffff;
  for(i=0;i<14;i=i+1)for(j=0;j<14;j=j+1)run_cluster(clusters[i],clusters[j]);
  for(i=0;i<512;i=i+1)begin
   random_size=$random & 32'h0fffffff;random_rel=$random;
   run_cluster(random_size,random_rel);
   run_cluster(random_size,random_size);
   run_cluster(random_size,random_size-1'b1);
  end
  if(errors==0)$display("tb_fat32_compare ALL PASS (%0d real-DUT cases)",cases);
  else $display("FAILED tb_fat32_compare errors=%0d",errors);
  $finish;
 end
 initial begin #1000000;$display("FAILED FAT32 comparison timeout");$finish;end
endmodule
