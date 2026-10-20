`timescale 1ns/1ps
// Independent synthetic FAT32 card. High (>16-bit) start clusters, fragmented
// second clusters, 12 BMP/3 WAV and 64-entry overflow profiles.
module tb_fat32_indexed;
 reg clk=0,rst=1,br=0,ar=0,aa=0;always #5 clk=~clk;
 reg [6:0] bi=0;reg [5:0] ai=0;reg [31:0] brel=0,arel=0;
 reg capacity=0;
 wire mounted,failed,found,idle,truncated;wire [3:0] code;wire [6:0] bc,ac;
 wire [7:0] bd,ad,pbd,pad;wire bv,be,berr,bg,av,ae,aerr,pbr,pbv,pbe,pberr,pbg,par,pav,pae,paerr;
 wire [31:0] pbaddr,paaddr;
 wire req,valid,done,error,transport;wire [31:0] addr;
 reg [7:0] data=0;reg dv=0,se=0;
 assign valid=dv;assign done=se;assign error=0;
 sd_fat32 #(.INDEXED(1),.MAX_FILES(64)) fs(.clk(clk),.rst(rst),.sd_init_done(1'b1),
  .mount_done(mounted),.mount_error(failed),.mount_error_code(code),.bmp_count(bc),.wav_found(found),
  .bmp_size(),.wav_size(),.wav_count(ac),.files_truncated(truncated),
  .bmp_req(br),.bmp_file_idx(bi),.bmp_rel_sector(brel),.bmp_data(bd),.bmp_valid(bv),.bmp_end(be),.bmp_error(berr),.bmp_grant(bg),.bmp_abort(1'b0),
  .aud_req(ar),.aud_file_idx(ai),.aud_rel_sector(arel),.aud_data(ad),.aud_valid(av),.aud_end(ae),.aud_error(aerr),.aud_abort(aa),.aud_idle(idle),
  .arb_bmp_req(pbr),.arb_bmp_addr(pbaddr),.arb_bmp_data(pbd),.arb_bmp_valid(pbv),.arb_bmp_end(pbe),.arb_bmp_error(pberr),.arb_bmp_grant(pbg),
  .arb_aud_req(par),.arb_aud_addr(paaddr),.arb_aud_data(pad),.arb_aud_valid(pav),.arb_aud_end(pae),.arb_aud_error(paerr));
 sd_read_arbiter #(.TIMEOUT_CYCLES(4096)) arb(.clk(clk),.rst(rst),.sd_ready(1'b1),
  .bmp_req(pbr),.bmp_addr(pbaddr),.bmp_data(pbd),.bmp_valid(pbv),.bmp_end(pbe),.bmp_error(pberr),.bmp_grant(pbg),
  .aud_req(par),.aud_addr(paaddr),.aud_data(pad),.aud_valid(pav),.aud_end(pae),.aud_error(paerr),
  .sd_req(req),.sd_addr(addr),.sd_data(data),.sd_valid(valid),.sd_end(done),.sd_error(error),.transport_reset(transport));
 localparam FIRST=2082,TOTAL=1050658;
 integer active=0,n=0,lba=0,errors=0,bytes_seen,j,k,expected_id,rel;
 function [7:0] disk_byte;input integer a,b;
  integer slot,offset,id,audio,cluster,v,entry,word,delta;begin
   disk_byte=0;
   if(a==0)case(b)
    11:disk_byte=0;12:disk_byte=2;13:disk_byte=8;14:disk_byte=32;16:disk_byte=2;
    32:disk_byte=TOTAL;33:disk_byte=TOTAL>>8;34:disk_byte=TOTAL>>16;35:disk_byte=TOTAL>>24;
    36:disk_byte=1;37:disk_byte=4;44:disk_byte=2;510:disk_byte=8'h55;511:disk_byte=8'haa;
   endcase
   else if(a>=FIRST && a<FIRST+8)begin
    slot=(a-FIRST)*16+b/32;offset=b%32;
    // Two filtered directory entries followed by real files.
    if(slot<2)begin
     if(offset==0)disk_byte=(slot==0)?8'he5:"L";
     if(offset==11)disk_byte=(slot==0)?8'h20:8'h0f;
    end else begin
     id=slot-2;
     if(id<(capacity?70:15))begin
      audio=capacity?(id%4==3):(id>=12);
      cluster=66000+id*20;
      if(offset<8)disk_byte="A";
      case(offset)
       8:disk_byte=audio?"W":"B";9:disk_byte=audio?"A":"M";10:disk_byte=audio?"V":"P";
       11:disk_byte=8'h20;20:disk_byte=cluster>>16;21:disk_byte=cluster>>24;
       26:disk_byte=cluster;27:disk_byte=cluster>>8;
       28:disk_byte=0;29:disk_byte=18; // 4608 bytes = 9 sectors, two clusters
      endcase
     end
    end
   end else if(a>=32 && a<1057)begin
    entry=(a-32)*128+b/4;word=0;
    if(entry==2)word=32'h0fffffff;
    if(entry>=66000)begin
     delta=(entry-66000)%20;
     if(delta==0)word=entry+7;
     else if(delta==7)word=32'h0fffffff;
    end
    disk_byte=word>>((b%4)*8);
   end else if(a>=FIRST+8)begin
    cluster=2+(a-FIRST)/8;id=(cluster-66000)/20;delta=(cluster-66000)%20;
    v=(delta==7?8:0)+(a-FIRST)%8;
    disk_byte=(id*17+v*3+b)&255;
   end
  end
 endfunction
 always @(negedge clk)begin
  dv=0;se=0;
  if(rst)begin active=0;n=0;end
  else case(active)
   0:if(req)begin lba=addr;n=0;active=1;end
   1:begin data=disk_byte(lba,n);dv=1;n=n+1;if(n==512)active=2;end
   2:begin se=1;active=3;end
   3:if(!req)active=0;
  endcase
 end
 task check;input ok;input [511:0] msg;begin
  if(ok!==1)begin errors=errors+1;$display("FAIL indexed file %0s",msg);end
 end endtask
 task read_sector;input integer audio,index,relative,expected;begin
  @(negedge clk);bytes_seen=0;
  if(audio)begin ai=index;arel=relative;ar=1;end
  else begin bi=index;brel=relative;br=1;end
  begin:rx
   forever begin
    @(posedge clk);
    if(audio?av:bv)begin
     check((audio?ad:bd)===((expected*17+relative*3+bytes_seen)&255),"exact selected bytes / high cluster / cursor identity");
     bytes_seen=bytes_seen+1;
    end
    if(audio?aerr:berr)begin check(0,"unexpected read error");disable rx;end
    if(audio?ae:be)begin check(bytes_seen==512,"sector length");disable rx;end
   end
  end
  @(negedge clk);br=0;ar=0;repeat(10)@(negedge clk);
 end endtask
 task mount;input profile;begin
  @(negedge clk);rst=1;capacity=profile;br=0;ar=0;aa=0;repeat(5)@(negedge clk);rst=0;
  wait(mounted || failed);repeat(5)@(negedge clk);check(mounted && !failed,"mount");
 end endtask
 initial begin
  mount(0);check(bc==12 && ac==3 && found && !truncated,"12 BMP and 3 WAV, filtered entries");
  for(j=0;j<12;j=j+1)begin read_sector(0,j,0,j);read_sector(0,j,8,j);end
  for(j=0;j<3;j=j+1)begin read_sector(1,j,0,12+j);read_sector(1,j,8,12+j);end
  read_sector(1,0,8,12);read_sector(1,2,8,14); // equal cursor target, different WAV
  read_sector(0,63,0,0);read_sector(1,63,0,12); // out-of-range wraps to zero
  // Cancel audio after physical transfer has started; old data must drain.
  @(negedge clk);ar=1;ai=1;arel=8;wait(av);repeat(20)@(negedge clk);aa=1;ar=0;
  repeat(5)begin @(posedge clk);check(!av && !ae && !aerr,"cancelled audio hidden");end
  wait(idle);@(negedge clk);aa=0;repeat(5)@(negedge clk);read_sector(1,2,8,14);
  mount(1);check(bc==48 && ac==16 && truncated,"combined 64-file limit and observable truncation");
  read_sector(0,47,8,62);read_sector(1,15,8,63);read_sector(0,63,0,0);
  if(errors==0)$display("ALL PASS tb_fat32_indexed: 12BMP/3WAV, 64 total cap, high clusters, fragmented streams, audio cursor/safe cancellation, bounds");
  else $display("FAILED indexed errors=%0d",errors);
  $finish;
 end
 initial begin #10000000;$display("FAILED indexed watchdog");$finish;end
endmodule
