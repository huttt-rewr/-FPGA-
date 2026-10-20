`timescale 1ns/1ps
module tb_fat32_stream;
 reg clk=0,rst=1,br=0,ar=0,abort_bmp=0;always #5 clk=~clk;
 reg [2:0] file_idx=0;reg [31:0] baddr=0,aaddr=0;
 integer mode=0,errors=0,n=0,j,which,read_count,base,expected_size,old_fat;
 wire [7:0] bd,ad;wire bv,be,berr,bg,av,ae,aerr,mounted,failed,found;
 wire [3:0] code;wire [2:0] count;wire [127:0] sizes;wire [31:0] asize;
 reg [7:0] expected[0:4095],expected_b[0:511],expected_a[0:511];reg [1023:0] filename;
 integer nb,na,ended_b,ended_a;
 fat32_fixture card(.clk(clk),.rst(rst),.mode(mode),.br(br),.file_idx(file_idx),.baddr(baddr),
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
  for(which=0;which<3;which=which+1)begin
   reset_card(which==2?10:which);
   for(file_idx=0;file_idx<4;file_idx=file_idx+1)begin
    load_expected(file_idx);
    old_fat=card.fat_reads;
    for(j=0;j<(expected_size+511)/512;j=j+1)sector_read(0,j,0);
    if(mode==10 && file_idx==0)check(card.fat_reads==old_fat,"FAT cache serves several adjacent cluster links without reread");
    sector_read(0,0,0); // 解析头后重读和换图片，重新定位首簇。
    sector_read(0,(expected_size+511)/512,1); // 文件大小边界
   end
   load_expected(4);
   for(j=0;j<8;j=j+1)sector_read(1,j,0);
   sector_read(1,0,0);sector_read(1,8,1); // WAV回环
   old_fat=card.fat_reads;sector_read(1,0,0);sector_read(1,0,0);
   check(card.fat_reads==old_fat,"same-cluster repeat hits cursor/cache");
  end
  file_idx=0;load_expected(0);for(j=0;j<512;j=j+1)expected_b[j]=expected[j];
  load_expected(4);for(j=0;j<512;j=j+1)expected_a[j]=expected[j];
  @(negedge clk);baddr=0;aaddr=0;br=1;ar=1;nb=0;na=0;ended_a=0;ended_b=0;
  while(!ended_a || !ended_b)begin
   @(posedge clk);
   if(bv)begin check(bd===expected_b[nb],"concurrent BMP bytes");nb=nb+1;end
   if(av)begin check(ad===expected_a[na],"concurrent audio bytes");na=na+1;end
   check(!berr && !aerr,"concurrent requests isolated");
   if(ae)begin ended_a=1;check(!ended_b && na==512,"audio request wins at transaction boundary");end
   if(be)begin ended_b=1;check(ended_a && nb==512,"pending BMP eventually completes");end
   @(negedge clk);if(ended_a)ar=0;if(ended_b)br=0;
  end
  repeat(8)@(negedge clk);
  reset_card(7);file_idx=0;load_expected(0);sector_read(0,0,0);sector_read(0,1,1);
  reset_card(9);file_idx=0;load_expected(0);sector_read(0,1,1);
  reset_card(8);file_idx=0;sector_read(0,0,1);
  reset_card(14);file_idx=0;sector_read(0,0,1);
  reset_card(6);sector_read(1,0,1); // 根目录没有WAV
  reset_card(0);file_idx=7;sector_read(0,0,1);
  // 请求等待时图片取消，随后能够正常重读，不重置文件系统。
  file_idx=0;load_expected(0);
  @(negedge clk);br=1;abort_bmp=1;repeat(5)@(negedge clk);br=0;abort_bmp=0;
  repeat(30)@(negedge clk);sector_read(0,0,0);
  if(errors==0)$display("ALL PASS tb_fat32_stream: exact fragmented bytes/BMP/WAV/bounds/loops/cache/bad cluster/SD errors/abort");
  else $display("FAILED FAT32 stream total=%0d",errors);
  $finish;
 end
 initial begin #5000000;$display("FAILED FAT32 stream watchdog");$finish;end
endmodule
