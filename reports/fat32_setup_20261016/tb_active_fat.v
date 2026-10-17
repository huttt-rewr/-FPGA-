`timescale 1ns/1ps
// 真实仲裁器加行为SD卡：直接按LBA从Python生成的二进制FAT32镜像读512字节。
// mode: 0=superfloppy,1=MBR/spc2,2=坏签名,3=坏spc,4=短扇区,
// 5=根目录坏簇,6=根目录EOC,7=文件坏簇,8=SD读错,9=文件提前EOC。
module fat32_active_fixture(input clk,rst,input integer mode,
 input br,input [2:0] file_idx,input [31:0] baddr,
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
    // ExtFlags: mirroring disabled, active FAT index 1. Primary FAT reads forbidden.
    if(addr==0)sector[40]=8'h81;
    if(addr>=32 && addr<545)begin $display("FAILED active FAT: primary FAT read");$finish;end

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
module tb_active_fat;
 reg clk=0,rst=1,br=0,ar=0,abort_bmp=0;always #5 clk=~clk;
 reg [2:0] file_idx=0;reg [31:0] baddr=0,aaddr=0;
 integer mode=0,errors=0,n=0,j,which,read_count,base,expected_size,old_fat;
 wire [7:0] bd,ad;wire bv,be,berr,bg,av,ae,aerr,mounted,failed,found;
 wire [3:0] code;wire [2:0] count;wire [127:0] sizes;wire [31:0] asize;
 reg [7:0] expected[0:4095],expected_b[0:511],expected_a[0:511];reg [1023:0] filename;
 integer nb,na,ended_b,ended_a;
 fat32_active_fixture card(.clk(clk),.rst(rst),.mode(mode),.br(br),.file_idx(file_idx),.baddr(baddr),
 .bd(bd),.bv(bv),.be(be),.berr(berr),.bg(bg),.ar(ar),.aaddr(aaddr),.ad(ad),.av(av),.ae(ae),.aerr(aerr),
 .mounted(mounted),.failed(failed),.code(code),.count(count),.found(found),.sizes(sizes),.asize(asize),.abort_bmp(abort_bmp),.init_done(1'b1));
 task check;input ok;input [511:0] msg;begin
  if(ok!==1)begin errors=errors+1;$display("FAILED FAT32 stream mode=%0d file=%0d rel=%0d byte=%0d %0s",mode,file_idx,br?baddr:aaddr,n,msg);end
 end endtask
 task reset_card;input integer m;begin
  @(negedge clk);rst=1;mode=m;br=0;ar=0;abort_bmp=0;repeat(4)@(negedge clk);#1;rst=0;
  wait(mounted || failed);check(mounted && !failed,"mount before stream");
 end endtask
 task sector_read;
  input integer audio,rel,should_error;
  begin
   @(negedge clk);n=0;
   if(audio)begin aaddr=rel;ar=1;end else begin baddr=rel;br=1;end
   begin:receive_bytes
    forever begin
     @(posedge clk);
     if(audio?av:bv)begin
      if(!should_error)check((audio?ad:bd)===expected[rel*512+n],"Python original bytes including last-sector padding");
      n=n+1;
     end
     if(audio?aerr:berr)begin check(should_error,"unexpected stream error");disable receive_bytes;end
     if(audio?ae:be)begin check(!should_error && n==512,"exact sector end and count");disable receive_bytes;end
    end
   end
   @(negedge clk);br=0;ar=0;repeat(8)@(negedge clk);
  end
 endtask
 task load_expected;input integer file_number;
  begin
   case(file_number)
    0:begin filename=mode==1?"../reports/fat32_20261015/vectors/mbr_FIRST___BMP.hex":"../reports/fat32_20261015/vectors/super_FIRST___BMP.hex";expected_size=2630;end
    1:begin filename=mode==1?"../reports/fat32_20261015/vectors/mbr_SECOND__bmp.hex":"../reports/fat32_20261015/vectors/super_SECOND__bmp.hex";expected_size=2554;end
    2:begin filename=mode==1?"../reports/fat32_20261015/vectors/mbr_THIRD___BMP.hex":"../reports/fat32_20261015/vectors/super_THIRD___BMP.hex";expected_size=730;end
    3:begin filename=mode==1?"../reports/fat32_20261015/vectors/mbr_FOURTH__BMP.hex":"../reports/fat32_20261015/vectors/super_FOURTH__BMP.hex";expected_size=1494;end
    default:begin filename=mode==1?"../reports/fat32_20261015/vectors/mbr_SOUND___WAV.hex":"../reports/fat32_20261015/vectors/super_SOUND___WAV.hex";expected_size=4044;end
   endcase
   $readmemh(filename,expected);
  end
 endtask

 initial begin
  reset_card(0);
  check(count==4 && found,"active FAT root enumeration");
  for(which=0;which<5;which=which+1)begin
   file_idx=which;load_expected(which);
   for(j=0;j<(expected_size+511)/512;j=j+1)sector_read(which==4,j,0);
  end
  if(errors==0)$display("ALL PASS active_fat: FAT2-only root and five fragmented files, exact Python bytes");
  else $display("FAILED active_fat errors=%0d",errors);
  $finish;
 end
 initial begin #10000000;$display("FAILED active FAT watchdog");$finish;end
endmodule
