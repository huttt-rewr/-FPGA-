`timescale 1ns/1ps
// Unlike the original FAT32 regressions, this fixture traverses every physical
// command/data pin of the NEW transport. Only the card is a behavioral model.
module native_fat32_fixture #(parameter IMAGE_MODE=1)(
 input clk,rst,br,ar,input [2:0] file_idx,input [31:0] rel,
 output [7:0] bd,ad,output bv,be,berr,av,ae,aerr,
 output mounted,failed,found,output [2:0] count,
 output [127:0] sizes,output [31:0] asize,model_errors
);
 wire pbr,pbv,pbe,pberr,pbg,par,pav,pae,paerr,req,valid,done,err,tr,init,init_error;
 wire [31:0] pbaddr,paaddr,addr;
 wire [7:0] pbd,pad,data;
 wire sclk;
 tri1 cmd,d0,d1,d2,d3;
 sd_fat32 fs(.clk(clk),.rst(rst),.sd_init_done(init),
  .mount_done(mounted),.mount_error(failed),.mount_error_code(),.bmp_count(count),
  .wav_found(found),.bmp_size(sizes),.wav_size(asize),
  .bmp_req(br),.bmp_file_idx(file_idx),.bmp_rel_sector(rel),.bmp_data(bd),
  .bmp_valid(bv),.bmp_end(be),.bmp_error(berr),.bmp_grant(),.bmp_abort(1'b0),
  .aud_req(ar),.aud_rel_sector(rel),.aud_data(ad),.aud_valid(av),.aud_end(ae),.aud_error(aerr),
  .arb_bmp_req(pbr),.arb_bmp_addr(pbaddr),.arb_bmp_data(pbd),.arb_bmp_valid(pbv),
  .arb_bmp_end(pbe),.arb_bmp_error(pberr),.arb_bmp_grant(pbg),
  .arb_aud_req(par),.arb_aud_addr(paaddr),.arb_aud_data(pad),.arb_aud_valid(pav),.arb_aud_end(pae),.arb_aud_error(paerr));
 sd_read_arbiter #(.TIMEOUT_CYCLES(20000)) arb(.clk(clk),.rst(rst),.sd_ready(init),
  .bmp_req(pbr),.bmp_addr(pbaddr),.bmp_data(pbd),.bmp_valid(pbv),.bmp_end(pbe),.bmp_error(pberr),.bmp_grant(pbg),
  .aud_req(par),.aud_addr(paaddr),.aud_data(pad),.aud_valid(pav),.aud_end(pae),.aud_error(paerr),
  .sd_req(req),.sd_addr(addr),.sd_data(data),.sd_valid(valid),.sd_end(done),.sd_error(err),.transport_reset(tr));
 sd_card_top_native #(.SPI_LOW_SPEED_DIV(0),.WAIT_TIMEOUT_CYCLES(12000),
  .INIT_TIMEOUT_CYCLES(100000),.INIT_PAUSE_CYCLES(200)) transport(
  .clk(clk),.rst(rst|tr),.SD_CLK(sclk),.SD_CMD(cmd),
  .SD_DAT0(d0),.SD_DAT1(d1),.SD_DAT2(d2),.SD_DAT3(d3),
  .sd_init_done(init),.sd_init_error(init_error),.sd_transfer_error(err),
  .sd_sec_read(req),.sd_sec_read_addr(addr),.sd_sec_read_data(data),
  .sd_sec_read_data_valid(valid),.sd_sec_read_end(done),.sd_sec_write(1'b0),
  .sd_sec_write_addr(32'd0),.sd_sec_write_data(8'd0),.sd_sec_write_data_req(),.sd_sec_write_end());
 sd_native_card_model #(.IMAGE_MODE(IMAGE_MODE)) card(.rst(rst),.SD_CLK(sclk),.SD_CMD(cmd),
  .SD_DAT({d3,d2,d1,d0}),.ccs(1'b1),.fault(4'd0),.last_read_argument(),
  .commands(),.reads(),.errors(model_errors));
endmodule
module tb_sd_native_fat32;
 reg clk=0;
 reg [1:0] rst=3,br=0,ar=0;
 reg [2:0] file_idx=0;
 reg [31:0] rel=0;
 wire [1:0] mounted,failed,found,bv,be,berr,av,ae,aerr;
 wire [7:0] bd[0:1],ad[0:1];
 wire [2:0] count[0:1];
 wire [127:0] sizes[0:1];
 wire [31:0] asize[0:1],model_errors[0:1];
 reg [7:0] expected[0:4095];
 reg [1023:0] filename;
 integer mode,f,sector,n,expected_size,errors=0;
 genvar g;
 always #5 clk=~clk;
 generate for(g=0;g<2;g=g+1)begin:fixture
  native_fat32_fixture #(.IMAGE_MODE(g+1)) dut(.clk(clk),.rst(rst[g]),
   .br(br[g]),.ar(ar[g]),.file_idx(file_idx),.rel(rel),.bd(bd[g]),.ad(ad[g]),
   .bv(bv[g]),.be(be[g]),.berr(berr[g]),.av(av[g]),.ae(ae[g]),.aerr(aerr[g]),
   .mounted(mounted[g]),.failed(failed[g]),.found(found[g]),.count(count[g]),
   .sizes(sizes[g]),.asize(asize[g]),.model_errors(model_errors[g]));
 end endgenerate
 task check;input okay;input [511:0] message;begin
  if(okay!==1'b1)begin errors=errors+1;$display("FAIL native FAT32 mode=%0d file=%0d sector=%0d %0s",mode,f,sector,message);end
 end endtask
 initial begin
  for(mode=0;mode<2;mode=mode+1)begin
   repeat(5)@(negedge clk);rst[mode]=0;
   wait(mounted[mode] || failed[mode]);
   check(mounted[mode] && !failed[mode] && count[mode]==4 && found[mode],"enumeration over 4-bit pins");
   check(sizes[mode]=={32'd1494,32'd730,32'd2554,32'd2630} && asize[mode]==4044,"directory sizes");
   for(f=0;f<5;f=f+1)begin
    file_idx=f;
    case(f)
     0:begin filename=mode==1?"../reports/fat32_20261015/vectors/mbr_FIRST___BMP.hex":"../reports/fat32_20261015/vectors/super_FIRST___BMP.hex";expected_size=2630;end
     1:begin filename=mode==1?"../reports/fat32_20261015/vectors/mbr_SECOND__bmp.hex":"../reports/fat32_20261015/vectors/super_SECOND__bmp.hex";expected_size=2554;end
     2:begin filename=mode==1?"../reports/fat32_20261015/vectors/mbr_THIRD___BMP.hex":"../reports/fat32_20261015/vectors/super_THIRD___BMP.hex";expected_size=730;end
     3:begin filename=mode==1?"../reports/fat32_20261015/vectors/mbr_FOURTH__BMP.hex":"../reports/fat32_20261015/vectors/super_FOURTH__BMP.hex";expected_size=1494;end
     default:begin filename=mode==1?"../reports/fat32_20261015/vectors/mbr_SOUND___WAV.hex":"../reports/fat32_20261015/vectors/super_SOUND___WAV.hex";expected_size=4044;end
    endcase
    $readmemh(filename,expected);
    for(sector=0;sector<(expected_size+511)/512;sector=sector+1)begin
     @(negedge clk);rel=sector;n=0;if(f==4)ar[mode]=1;else br[mode]=1;
     begin:receive_sector
      forever begin
       @(posedge clk);
       if(f==4?av[mode]:bv[mode])begin
        check((f==4?ad[mode]:bd[mode])===expected[sector*512+n],"exact original file byte");n=n+1;
       end
       if(f==4?aerr[mode]:berr[mode])begin check(0,"unexpected read error");disable receive_sector;end
       if(f==4?ae[mode]:be[mode])begin check(n==512,"512 bytes per successful sector");disable receive_sector;end
      end
     end
     @(negedge clk);br=0;ar=0;repeat(8)@(negedge clk);
    end
   end
   check(model_errors[mode]==0,"command/argument/CRC checks");
   rst[mode]=1;
  end
  if(errors==0)$display("ALL PASS tb_sd_native_fat32: 4-bit pins -> transport -> unchanged arbiter/FAT32, MBR/superfloppy, fragmented BMP/WAV exact bytes");
  else $display("FAILED tb_sd_native_fat32 errors=%0d",errors);
  $finish;
 end
 initial begin #20000000;$display("FAILED watchdog tb_sd_native_fat32");$finish;end
endmodule
