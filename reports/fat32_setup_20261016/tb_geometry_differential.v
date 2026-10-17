`timescale 1ns/1ps
// 真实仲裁器加行为SD卡：直接按LBA从Python生成的二进制FAT32镜像读512字节。
// mode: 0=superfloppy,1=MBR/spc2,2=坏签名,3=坏spc,4=短扇区,
// 5=根目录坏簇,6=根目录EOC,7=文件坏簇,8=SD读错,9=文件提前EOC。
module geometry_candidate(input clk,rst,input integer mode,
 input integer variant,input br,input [2:0] file_idx,input [31:0] baddr,
 output [7:0] bd,output bv,be,berr,bg,
 input ar,input [31:0] aaddr,output [7:0] ad,output av,ae,aerr,
 output mounted,failed,output [3:0] code,output [2:0] count,output found,
 output [127:0] sizes,output [31:0] asize,input abort_bmp,input init_done);
 wire pbr,pbv,pbe,pberr,pbg,par,pav,pae,paerr,req,valid,done,err,tr;
 wire [31:0] pbaddr,paaddr,addr;wire [7:0] pbd,pad;
 reg [7:0] data=0;reg dv=0,se=0,re=0;
 assign valid=dv;assign done=se;assign err=re;
 sd_fat32 #(.ROOT_CLUSTER_LIMIT(4)) fs(.clk(clk),.rst(rst),.sd_init_done(init_done),
 .mount_done(mounted),.mount_error(failed),.mount_error_code(code),.bmp_count(count),
 .wav_found(found),.bmp_size(sizes),.wav_size(asize),
 .bmp_req(br),.bmp_file_idx(file_idx),.bmp_rel_sector(baddr),.bmp_data(bd),
 .bmp_valid(bv),.bmp_end(be),.bmp_error(berr),.bmp_grant(bg),.bmp_abort(abort_bmp),
 .aud_req(ar),.aud_rel_sector(aaddr),.aud_data(ad),.aud_valid(av),.aud_end(ae),.aud_error(aerr),
 .arb_bmp_req(pbr),.arb_bmp_addr(pbaddr),.arb_bmp_data(pbd),.arb_bmp_valid(pbv),
 .arb_bmp_end(pbe),.arb_bmp_error(pberr),.arb_bmp_grant(pbg),
 .arb_aud_req(par),.arb_aud_addr(paaddr),.arb_aud_data(pad),.arb_aud_valid(pav),.arb_aud_end(pae),.arb_aud_error(paerr));
 sd_read_arbiter #(.TIMEOUT_CYCLES(4096)) arb(.clk(clk),.rst(rst),.sd_ready(init_done),
 .bmp_req(pbr),.bmp_addr(pbaddr),.bmp_data(pbd),.bmp_valid(pbv),.bmp_end(pbe),.bmp_error(pberr),.bmp_grant(pbg),
 .aud_req(par),.aud_addr(paaddr),.aud_data(pad),.aud_valid(pav),.aud_end(pae),.aud_error(paerr),
 .sd_req(req),.sd_addr(addr),.sd_data(data),.sd_valid(valid),.sd_end(done),.sd_error(err),.transport_reset(tr));
 integer fd=0,old_mode=-1,n=0,active=0,cycle=0,got,seek_result;
 integer reads=0,fat_reads=0,latched_lba=0;
 reg [7:0] sector[0:511];
 always @(negedge clk)begin
  dv=0;se=0;re=0;cycle=cycle+1;
  if(rst || !init_done || mode!=old_mode)begin
   old_mode=mode;
   active=0;n=0;reads=0;fat_reads=0;
   if(fd!=0)$fclose(fd);
   if(mode==10)fd=$fopen("../reports/fat32_20261015/vectors/contig.img","rb");
   else if(mode==1)fd=$fopen("../reports/fat32_20261015/vectors/mbr.img","rb");
   else fd=$fopen("../reports/fat32_20261015/vectors/super.img","rb");
   if(fd==0)begin $display("FAILED FAT32 fixture missing image");$finish;end
  end else case(active)
   0:if(req)begin
    reads=reads+1;latched_lba=addr;
    if((mode==1 && addr>=2080 && addr<2593) || (mode!=1 && addr>=32 && addr<545))fat_reads=fat_reads+1;
    seek_result=$fseek(fd,addr*512,0);got=$fread(sector,fd);
    if(addr==(mode==1?2048:0))case(variant)
     1:begin sector[32]=0;sector[33]=0;sector[34]=0;sector[35]=0;end
     2:begin sector[32]=32;sector[33]=0;sector[34]=0;sector[35]=0;end
     3:begin sector[32]=8'h12;sector[33]=8'h04;sector[34]=0;sector[35]=0;end
     4:begin sector[32]=8'h06;sector[33]=8'h04;sector[34]=1;sector[35]=0;end // 65524 data clusters
     5:begin sector[32]=8'h07;sector[33]=8'h04;sector[34]=1;sector[35]=0;end // 65525 data clusters
     6:begin sector[32]=8'hfe;sector[33]=8'hff;sector[34]=8'hff;sector[35]=8'hff;end
     7:begin sector[32]=8'hff;sector[33]=8'h03;sector[34]=0;sector[35]=8'h10;end // high cluster bound
     8:begin sector[36]=0;sector[37]=2;sector[38]=0;sector[39]=0;end // FAT capacity too small
     9:begin sector[32]=1;sector[33]=5;sector[34]=2;sector[35]=0;end // partition shorter than BPB
     default:;
    endcase

    if(seek_result!=0 || got!=512)begin $display("FAILED FAT32 SD model seek/read LBA=%0d got=%0d",addr,got);$finish;end
    if(mode==2 && addr==0)sector[511]=0;
    if(mode==3 && addr==0)sector[13]=3;
    if((mode==5 || mode==6) && addr==32)begin
     sector[8]=(mode==5)?8'hf7:8'hff;sector[9]=8'hff;sector[10]=8'hff;sector[11]=8'h0f;
    end
    if((mode==7 || mode==9) && addr==32)begin
     sector[40]=(mode==7)?8'hf7:8'hff;sector[41]=8'hff;sector[42]=8'hff;sector[43]=8'h0f;
    end
    if(mode==11 && addr==33)begin sector[8]=2;sector[9]=0;sector[10]=0;sector[11]=0;end
    if(mode==11 && addr==1186)begin
     for(got=0;got<512;got=got+1)sector[got]=8'he5;
    end
    n=0;active=1;
   end
   1:if(mode==8 && latched_lba==1066 && n==33)begin re=1;active=3;end
     else if(cycle%7!=0)begin
      data=sector[n];dv=1;n=n+1;
      if(n==((mode==4 || (mode==14 && latched_lba==1066))?511:512))active=2;
     end
   2:begin se=1;active=3;end
   3:if(!req)active=0;
  endcase
 end
endmodule

`timescale 1ns/1ps
// 真实仲裁器加行为SD卡：直接按LBA从Python生成的二进制FAT32镜像读512字节。
// mode: 0=superfloppy,1=MBR/spc2,2=坏签名,3=坏spc,4=短扇区,
// 5=根目录坏簇,6=根目录EOC,7=文件坏簇,8=SD读错,9=文件提前EOC。
module geometry_reference(input clk,rst,input integer mode,
 input integer variant,input br,input [2:0] file_idx,input [31:0] baddr,
 output [7:0] bd,output bv,be,berr,bg,
 input ar,input [31:0] aaddr,output [7:0] ad,output av,ae,aerr,
 output mounted,failed,output [3:0] code,output [2:0] count,output found,
 output [127:0] sizes,output [31:0] asize,input abort_bmp,input init_done);
 wire pbr,pbv,pbe,pberr,pbg,par,pav,pae,paerr,req,valid,done,err,tr;
 wire [31:0] pbaddr,paaddr,addr;wire [7:0] pbd,pad;
 reg [7:0] data=0;reg dv=0,se=0,re=0;
 assign valid=dv;assign done=se;assign err=re;
 sd_fat32_reference #(.ROOT_CLUSTER_LIMIT(4)) fs(.clk(clk),.rst(rst),.sd_init_done(init_done),
 .mount_done(mounted),.mount_error(failed),.mount_error_code(code),.bmp_count(count),
 .wav_found(found),.bmp_size(sizes),.wav_size(asize),
 .bmp_req(br),.bmp_file_idx(file_idx),.bmp_rel_sector(baddr),.bmp_data(bd),
 .bmp_valid(bv),.bmp_end(be),.bmp_error(berr),.bmp_grant(bg),.bmp_abort(abort_bmp),
 .aud_req(ar),.aud_rel_sector(aaddr),.aud_data(ad),.aud_valid(av),.aud_end(ae),.aud_error(aerr),
 .arb_bmp_req(pbr),.arb_bmp_addr(pbaddr),.arb_bmp_data(pbd),.arb_bmp_valid(pbv),
 .arb_bmp_end(pbe),.arb_bmp_error(pberr),.arb_bmp_grant(pbg),
 .arb_aud_req(par),.arb_aud_addr(paaddr),.arb_aud_data(pad),.arb_aud_valid(pav),.arb_aud_end(pae),.arb_aud_error(paerr));
 sd_read_arbiter #(.TIMEOUT_CYCLES(4096)) arb(.clk(clk),.rst(rst),.sd_ready(init_done),
 .bmp_req(pbr),.bmp_addr(pbaddr),.bmp_data(pbd),.bmp_valid(pbv),.bmp_end(pbe),.bmp_error(pberr),.bmp_grant(pbg),
 .aud_req(par),.aud_addr(paaddr),.aud_data(pad),.aud_valid(pav),.aud_end(pae),.aud_error(paerr),
 .sd_req(req),.sd_addr(addr),.sd_data(data),.sd_valid(valid),.sd_end(done),.sd_error(err),.transport_reset(tr));
 integer fd=0,old_mode=-1,n=0,active=0,cycle=0,got,seek_result;
 integer reads=0,fat_reads=0,latched_lba=0;
 reg [7:0] sector[0:511];
 always @(negedge clk)begin
  dv=0;se=0;re=0;cycle=cycle+1;
  if(rst || !init_done || mode!=old_mode)begin
   old_mode=mode;
   active=0;n=0;reads=0;fat_reads=0;
   if(fd!=0)$fclose(fd);
   if(mode==10)fd=$fopen("../reports/fat32_20261015/vectors/contig.img","rb");
   else if(mode==1)fd=$fopen("../reports/fat32_20261015/vectors/mbr.img","rb");
   else fd=$fopen("../reports/fat32_20261015/vectors/super.img","rb");
   if(fd==0)begin $display("FAILED FAT32 fixture missing image");$finish;end
  end else case(active)
   0:if(req)begin
    reads=reads+1;latched_lba=addr;
    if((mode==1 && addr>=2080 && addr<2593) || (mode!=1 && addr>=32 && addr<545))fat_reads=fat_reads+1;
    seek_result=$fseek(fd,addr*512,0);got=$fread(sector,fd);
    if(addr==(mode==1?2048:0))case(variant)
     1:begin sector[32]=0;sector[33]=0;sector[34]=0;sector[35]=0;end
     2:begin sector[32]=32;sector[33]=0;sector[34]=0;sector[35]=0;end
     3:begin sector[32]=8'h12;sector[33]=8'h04;sector[34]=0;sector[35]=0;end
     4:begin sector[32]=8'h06;sector[33]=8'h04;sector[34]=1;sector[35]=0;end // 65524 data clusters
     5:begin sector[32]=8'h07;sector[33]=8'h04;sector[34]=1;sector[35]=0;end // 65525 data clusters
     6:begin sector[32]=8'hfe;sector[33]=8'hff;sector[34]=8'hff;sector[35]=8'hff;end
     7:begin sector[32]=8'hff;sector[33]=8'h03;sector[34]=0;sector[35]=8'h10;end // high cluster bound
     8:begin sector[36]=0;sector[37]=2;sector[38]=0;sector[39]=0;end // FAT capacity too small
     9:begin sector[32]=1;sector[33]=5;sector[34]=2;sector[35]=0;end // partition shorter than BPB
     default:;
    endcase

    if(seek_result!=0 || got!=512)begin $display("FAILED FAT32 SD model seek/read LBA=%0d got=%0d",addr,got);$finish;end
    if(mode==2 && addr==0)sector[511]=0;
    if(mode==3 && addr==0)sector[13]=3;
    if((mode==5 || mode==6) && addr==32)begin
     sector[8]=(mode==5)?8'hf7:8'hff;sector[9]=8'hff;sector[10]=8'hff;sector[11]=8'h0f;
    end
    if((mode==7 || mode==9) && addr==32)begin
     sector[40]=(mode==7)?8'hf7:8'hff;sector[41]=8'hff;sector[42]=8'hff;sector[43]=8'h0f;
    end
    if(mode==11 && addr==33)begin sector[8]=2;sector[9]=0;sector[10]=0;sector[11]=0;end
    if(mode==11 && addr==1186)begin
     for(got=0;got<512;got=got+1)sector[got]=8'he5;
    end
    n=0;active=1;
   end
   1:if(mode==8 && latched_lba==1066 && n==33)begin re=1;active=3;end
     else if(cycle%7!=0)begin
      data=sector[n];dv=1;n=n+1;
      if(n==((mode==4 || (mode==14 && latched_lba==1066))?511:512))active=2;
     end
   2:begin se=1;active=3;end
   3:if(!req)active=0;
  endcase
 end
endmodule


module tb_geometry_differential;
 reg clk=0,rst=1;always #5 clk=~clk;
 integer mode=0,variant=0,errors=0,tests=0,m,v;
 wire cm,cf,cw,rm,rf,rw;wire [3:0] cc,rc;wire [2:0] cn,rn;
 wire [127:0] cs,rs;wire [31:0] ca,ra;
 geometry_candidate candidate(.clk(clk),.rst(rst),.mode(mode),.variant(variant),.br(1'b0),.file_idx(3'd0),.baddr(32'd0),
  .ar(1'b0),.aaddr(32'd0),.mounted(cm),.failed(cf),.code(cc),.count(cn),.found(cw),.sizes(cs),.asize(ca),.abort_bmp(1'b0),.init_done(1'b1));
 geometry_reference reference(.clk(clk),.rst(rst),.mode(mode),.variant(variant),.br(1'b0),.file_idx(3'd0),.baddr(32'd0),
  .ar(1'b0),.aaddr(32'd0),.mounted(rm),.failed(rf),.code(rc),.count(rn),.found(rw),.sizes(rs),.asize(ra),.abort_bmp(1'b0),.init_done(1'b1));
 always @(posedge clk)if(!rst)begin
  #1;
  if({cm,cf,cc,cn,cw,cs,ca,candidate.req,candidate.addr} !==
     {rm,rf,rc,rn,rw,rs,ra,reference.req,reference.addr})begin
   $display("FAILED differential mode=%0d variant=%0d",mode,variant);$finish;
  end
 end
 initial begin
  for(m=0;m<2;m=m+1)for(v=0;v<10;v=v+1)begin
   @(negedge clk);rst=1;mode=m;variant=v;repeat(4)@(negedge clk);rst=0;
   wait(cm || cf);repeat(4)@(negedge clk);tests=tests+1;
  end
  $display("ALL PASS geometry_differential: %0d BPB scenarios, identical cycle/requests/addresses/status/sizes",tests);
  $finish;
 end
 initial begin #10000000;$display("FAILED geometry watchdog");$finish;end
endmodule
