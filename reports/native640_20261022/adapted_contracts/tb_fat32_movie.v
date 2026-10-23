`timescale 1ns/1ps
// Actual 4-bit CMD6 card interface -> FAT32 fragmented file -> AV loader.
// Check every expanded RGB pixel and every PCM sample written and played.
module tb_fat32_movie #(parameter SCENARIO=0,parameter HQ=0);
 reg clk=0,pc=0,rst=1,finish=0;
 always #5 clk=~clk;
 always #20 pc=~pc;
 wire sdclk;tri1 cmd,d0,d1,d2,d3;
 wire req,dv,se,err,ready,wr,we,publish,bank,awe,playing,failed,ended,busy,ack;
 wire [31:0] sector,pixel;wire [7:0] data;wire [1:0] wb,active;
 wire [10:0] aa;wire [15:0] ad;wire visible,buffering,av;
 wire [23:0] left,right;wire [31:0] model_errors;
 wire [6:0] movie_count;
 reg [19:0] raster=0;wire blank=raster==419999;
 always @(posedge pc)if(rst)raster<=0;else raster<=blank?0:raster+1'b1;
 sd_card_bmp #(.VIDEO_FILES(1),.NATIVE_4BIT(1),.NATIVE_HIGH_SPEED(1),.FAT32_ENABLE(1),
  .INDEXED(1),.ENABLE_SCALING(1),.ENABLE_AUDIO(1)) media(
  .clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),.cmd_next(1'b0),.cmd_prev(1'b0),.cmd_toggle(1'b0),
  .commit_ack_toggle(1'b0),.write_finish_toggle(1'b0),.write_req_ack(1'b0),.pixel_ready(1'b1),
  .bmp_width(16'd640),.bmp_height(16'd480),.SD_MISO(1'b1),
  .audio_enable(1'b1),.audio_sample_ready(1'b1),.audio_sector_room(1'b1),
  .image_select_index(8'd0),.audio_select_index(8'd0),.image_select_valid(1'b0),.audio_select_valid(1'b0),.fps_mode(4'd2),
  .SD_CLK(sdclk),.SD_CMD(cmd),.SD_DAT0(d0),.SD_DAT1(d1),.SD_DAT2(d2),.SD_DAT3(d3),
  .movie_mode(1'b1),.movie_restart(1'b0),.movie_index(7'd0),.movie_count(movie_count),
  .movie_req(req),.movie_sector(sector),.movie_data(data),
  .movie_valid(dv),.movie_end(se),.movie_error(err),.movie_ready(ready));
 sd_native_card_model #(.IMAGE_MODE(3),.DOUT_DELAY(14),
  .IMAGE_FILE(HQ?(SCENARIO==2?"../reports/video_quality_20261019/movie_bad_header.img":
                 SCENARIO==3?"../reports/video_quality_20261019/movie_bad_encoding.img":
                 "../reports/video_quality_20261019/movie_fat32.img"):
              SCENARIO==1?"../reports/video_fat32_20261018/movie_missing.img":
              SCENARIO==2?"../reports/video_fat32_20261018/movie_bad_header.img":
              "../reports/video_fat32_20261018/movie_fat32.img")) card(
  .rst(rst),.SD_CLK(sdclk),.SD_CMD(cmd),.SD_DAT({d3,d2,d1,d0}),
  .ccs(1'b1),.fault(4'd0),.hs_mode(4'd1),.errors(model_errors));
 integer cycles=0,pixels=0,samples=0,ticks=0,commits=0,x,y,f,expected,r,g,b,last_ack_cycle=0;
 reg prev_ack=0;
 wire pixel_ready=cycles%13<9;
 sd_av_reader reader(.clk(clk),.rst(rst),.mode_800(1'b0),.toggle_play(1'b0),
  .sd_ready(ready),.sd_error(err),.sector_read(req),.sector_address(sector),
  .sector_data(data),.sector_valid(dv),.sector_end(se),.write_req(wr),.write_req_ack(wr),
  .write_finish_toggle(finish),.write_en(we),.write_data(pixel),.pixel_ready(pixel_ready),.write_bank(wb),
  .request_toggle(publish),.requested_bank(bank),.ack_toggle(ack),.audio_we(awe),.audio_address(aa),.audio_data(ad),
  .playing(playing),.error(failed),.ended(ended),.busy(busy),.state_code());
 av_sync_player player(.clk(pc),.rst(rst),.mode_800(1'b0),.vblank(blank),
  .request_toggle(publish),.requested_bank(bank),.play(playing),.failed(failed),.ended(ended),
  .ack_toggle(ack),.active_buffer(active),.visible(visible),.buffering(buffering),
  .write_clk(clk),.audio_we(awe),.audio_address(aa),.audio_data(ad),.audio_valid(av),.left_pcm(left),.right_pcm(right));
 always @(posedge clk)if(!rst)begin
  cycles=cycles+1;
  if(SCENARIO==0 && (failed || err))$fatal(1,"FAILED FAT32 movie error state=%d sector=%d file_count=%d req=%b fat_state=%h req_file=%d size=%d cluster=%d",reader.state,sector,media.filesystem.fat.bmp_count,req,media.filesystem.fat.state,media.filesystem.fat.request_file,media.filesystem.fat.request_size,media.filesystem.fat.working_cluster);
  if(we)begin
   f=pixels/307200;x=(pixels%640)/(HQ?2:4);y=((pixels%307200)/640)/(HQ?2:4);
   if(HQ)begin
    r=(x+y+f)%32;g=y%64;b=x%32;
    expected=((r*8+r/4)<<16)|((g*4+g/16)<<8)|(b*8+b/4);
   end else expected=((x+y+f)%256)*65536+y*256+x;
   if(pixel!=={expected[23:0],8'd0})$fatal(1,"FAILED movie pixel %d got=%h expected=%h",pixels,pixel,expected);
   pixels=pixels+1;if(pixels%307200==0)finish<=~finish;
  end
  if(awe)begin
   expected=(samples/800)*1000+samples%800+1;
   if(ad!==expected[15:0] || aa!==((samples/800)%2)*1024+samples%800)
    $fatal(1,"FAILED movie PCM write %d",samples);
   samples=samples+1;
  end
 end
 always @(negedge pc)if(!rst)begin
  if(ack!=prev_ack)begin
   if(commits>0 && cycles-last_ack_cycle>5040100)$fatal(1,"FAILED movie missed 20fps deadline");
   commits=commits+1;prev_ack=ack;last_ack_cycle=cycles;
  end
  if(SCENARIO==0 && visible && !ended && buffering)$fatal(1,"FAILED movie underrun");
  if(av && visible)begin
   if(ticks<7200)begin
    expected=(ticks/2400)*1000+(ticks%2400)/3+1;
    if(left!=={expected[15:0],8'd0} || right!==left)$fatal(1,"FAILED movie PCM play %d got=%h",ticks,left);
   end else if(left!==0)$fatal(1,"FAILED EOF not silent");
   ticks=ticks+1;
  end
 end
 initial begin
  repeat(8)@(negedge clk);rst=0;
  if(SCENARIO!=0)begin
   wait(failed);repeat(20)@(negedge clk);
   if(pixels!=0 || samples!=0 || visible || publish || playing || model_errors!=0)
    $fatal(1,"FAILED invalid movie published output");
   $display("ALL PASS tb_fat32_movie HQ=%d rejected scenario=%d without publishing audio/video",HQ,SCENARIO);
   $finish;
  end
  wait(ended && ticks>7250);
  if(reader.video_format!=={1'b0,HQ[0]})$fatal(1,"FAILED selected wrong video format");
  if(pixels!=921600 || samples!=2400 || commits!=3 || model_errors!=0 || media.filesystem.fat.bmp_count!=2 || movie_count!=2 || media.filesystem.fat.wav_count!=0)
   $fatal(1,"FAILED movie final counts pixels=%d samples=%d commits=%d errors=%d avfs=%d count=%d wav=%d",pixels,samples,commits,model_errors,media.filesystem.fat.bmp_count,movie_count,media.filesystem.fat.wav_count);
  $display("ALL PASS tb_fat32_movie: real native50 pins, fragmented MBR FAT32 AVF, first video only, 3 exact RGB frames and synchronized PCM, EOF silence");
  $finish;
 end
 initial begin #300000000;$fatal(1,"FAILED movie timeout");end
endmodule
