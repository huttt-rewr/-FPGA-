`timescale 1ns/1ps
module tb_audio_sd_integration;
 reg clk=0,vc=0,rst=1,scan=0,load=0,enabled=1;
 always #5 clk=~clk;always #20 vc=~vc;
 wire br,bg,bv,be,ber,ar,av,ae,aer,sr,sv,serr,wrreq,found,sdone,bready,pen,stall;
 wire [31:0] ba,aa,sa;wire [7:0] bd,ad;wire [23:0] pixel,sample,fd,l,r;
 reg [7:0] cd=0;reg cv=0,ce=0,cer=0;wire sample_valid,error,ready,full,empty,fre,valid,uf,tr;
 wire [10:0] wu,ru;wire [11:0] sw,sh;
 integer errors=0,pixels=0,audio_reads=0,bmp_reads=0,samples=0,outputs=0,idx=0,busy=0,base=0,k;
 reg fault=0;reg [7:0] pcm_image[0:1535];
 bmp_read #(.SHARED_SD(1),.ENABLE_SCALING(1),.READ_STALL_CYCLES(900)) bmp(
 .clk(clk),.rst(rst),.ready(bready),.scan_start(scan),.scan_start_sector(32'd0),.scan_max_sector(32'd0),.scan_target_count(3'd1),.scan_done(sdone),.scan_found_valid(found),.load_start(load),.load_abort(1'b0),.load_sector(32'd0),.sd_init_done(1'b1),.read_granted(bg),.bmp_width(16'd640),.bmp_height(16'd480),.write_req(wrreq),.write_req_ack(wrreq),.sd_sec_read(br),.sd_sec_read_addr(ba),.sd_sec_read_data(bd),.sd_sec_read_data_valid(bv),.sd_sec_read_end(be),.bmp_data_wr_en(pen),.bmp_data(pixel),.read_stall(stall),.pixel_ready(1'b1),.source_width(sw),.source_height(sh));
 audio_wav #(.START_SECTOR(100)) wav(.clk(clk),.rst(rst),.sd_init_done(1'b1),.enable(enabled),.sector_room(wu<=764 && !full),.sample_ready(!full),.req(ar),.addr(aa),.data(ad),.data_valid(av),.sector_end(ae),.read_error(aer),.sample_valid(sample_valid),.sample(sample),.error(error),.ready(ready));
 sd_read_arbiter #(.TIMEOUT_CYCLES(2000)) arb(.clk(clk),.rst(rst),.sd_ready(1'b1),.bmp_req(br),.bmp_addr(ba),.bmp_data(bd),.bmp_valid(bv),.bmp_end(be),.bmp_error(ber),.bmp_grant(bg),.aud_req(ar),.aud_addr(aa),.aud_data(ad),.aud_valid(av),.aud_end(ae),.aud_error(aer),.sd_req(sr),.sd_addr(sa),.sd_data(cd),.sd_valid(cv),.sd_end(ce),.sd_error(cer),.transport_reset(tr));
 audio_async_fifo fifo(.wr_clk(clk),.rd_clk(vc),.rst(rst|error),.wr_en(sample_valid),.wr_data(sample),.full(full),.rd_en(fre),.rd_data(fd),.empty(empty),.wr_used(wu),.rd_used(ru));
 audio_playback player(.clk(vc),.rst(rst),.volume(5'd31),.mute(!enabled),.mode_800(1'b0),.stream_ok(ready && !error && enabled),.fifo_empty(empty),.fifo_used(ru),.fifo_data(fd),.fifo_rd_en(fre),.valid(valid),.left_pcm(l),.right_pcm(r),.underflow(uf));
 task u32;input integer p,v;begin pcm_image[p]=v;pcm_image[p+1]=v>>8;pcm_image[p+2]=v>>16;pcm_image[p+3]=v>>24;end endtask
 task check;input ok;input [511:0] msg;begin if(ok!==1)begin errors=errors+1;$display("FAILED integration %0s",msg);end end endtask
 function [7:0] bmp_byte;input integer p;begin
 case(p)0:bmp_byte=66;1:bmp_byte=77;2:bmp_byte=70;10:bmp_byte=54;14:bmp_byte=40;18,22:bmp_byte=2;26:bmp_byte=1;28:bmp_byte=24;
 54,57,62,65:bmp_byte=1;55,58,63,66:bmp_byte=2;56,59,64,67:bmp_byte=3;default:bmp_byte=0;endcase
 end endfunction
 always @(negedge clk)begin
 cv=0;ce=0;cer=0;
 if(rst)begin busy=0;idx=0;end
 else if(busy==0 && sr)begin base=sa*512;idx=0;busy=1;if(sa>=100)audio_reads=audio_reads+1;else bmp_reads=bmp_reads+1;end
 else if(busy==1)begin
  if(idx<512)begin cd=base>=51200?pcm_image[base-51200+idx]:bmp_byte(base+idx);cv=1;idx=idx+1;end
  else begin if(fault && base>=51200)cer=1;else ce=1;busy=2;end
 end else if(busy==2 && !sr)busy=0;
 end
 always @(posedge clk)if(!rst)begin
 if(stall || ber || tr)begin errors=errors+1;$display("FAILED integration BMP/transport error");end
 if(pen)begin if(pixel!==((pixels%640<80 || pixels%640>=560)?24'h000000:24'h030201))begin errors=errors+1;$display("FAILED integration pixel %h",pixel);end pixels=pixels+1;end
 if(sample_valid)begin samples=samples+1;if(sample!==24'h001234)begin errors=errors+1;$display("FAILED integration PCM");end end
 end
 always @(posedge vc)begin #1;if(!rst && valid && l!=0)begin outputs=outputs+1;if(l!==24'h11d02a || r!==l)begin errors=errors+1;$display("FAILED integration HDMI sample %h",l);end end end
 initial begin
 for(k=0;k<1536;k=k+1)pcm_image[k]=0;
 u32(0,32'h46464952);u32(4,1060);u32(8,32'h45564157);u32(12,32'h20746d66);u32(16,16);pcm_image[20]=1;pcm_image[22]=1;u32(24,48000);u32(28,96000);pcm_image[32]=2;pcm_image[34]=16;u32(36,32'h61746164);u32(40,1024);
 for(k=44;k<1068;k=k+2)begin pcm_image[k]=8'h34;pcm_image[k+1]=8'h12;end
 repeat(5)@(negedge clk);rst=0;scan=1;@(negedge clk);scan=0;wait(sdone);check(found,"BMP scans while audio active");
 @(negedge clk);load=1;@(negedge clk);load=0;wait(pixels==307200);wait(bready);repeat(30000)@(negedge clk);
 check(samples>1024 && outputs>10 && audio_reads>2 && bmp_reads>=3 && !error && !uf,"concurrent scan/scale/loop/HDMI stream");
 rst=1;repeat(5)@(negedge clk);pixels=0;samples=0;outputs=0;fault=1;rst=0;scan=1;@(negedge clk);scan=0;wait(error);wait(sdone);check(found && samples==0,"audio CRC failure isolated from BMP");
 @(negedge clk);load=1;@(negedge clk);load=0;wait(pixels==307200);check(error && !ber,"BMP continues after audio failure");
 if(errors==0)$display("ALL PASS tb_audio_sd_integration");else $display("FAILED integration %0d",errors);$finish;
 end
 initial begin #100000000;$display("FAILED integration watchdog bmp=%d wav=%d pixels=%d br=%b ar=%b busy=%d scans=%d aud=%d samples=%d",bmp.state,wav.state,pixels,br,ar,busy,bmp_reads,audio_reads,samples);$finish;end
endmodule
