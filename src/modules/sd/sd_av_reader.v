// AV16K20 raw-sector stream. Sector 0: header; each record: 4 PCM + video sectors.
// PCM: 800 signed LE16 samples. Video is bottom-up BGR24 or RGB565LE.
// Source payload, audio RAM and SDRAM must all complete before publishing a frame.
module sd_av_reader #(parameter WATCHDOG=100000000)(
 input clk,input rst,input mode_800,input toggle_play,
 input sd_ready,input sd_error,
 output sector_read,output [31:0] sector_address,
 input [7:0] sector_data,input sector_valid,input sector_end,
 output reg write_req,input write_req_ack,input write_finish_toggle,
 output write_en,output [31:0] write_data,input pixel_ready,
 output reg [1:0] write_bank,
 output reg request_toggle,output requested_bank,input ack_toggle,
 output reg audio_we,output reg [10:0] audio_address,output reg [15:0] audio_data,
 output reg playing,output reg error,output reg ended,output busy,
 output [3:0] state_code,output reg [1:0] video_format
);
 localparam INIT=0,HEADER=1,CHECK=2,AUDIO_START=3,AUDIO=4,GAP=5,
  WRITE_REQ=6,SCALE_START=7,SCALE=8,DRAIN=9,PUBLISH=10,ACK=11,END=12,FAIL=15;
 reg [3:0] state;
 reg read_req,scale_start;
 reg [31:0] address,frame_count,record_sector,watchdog;
 reg [19:0] frame_index,last_index;
 reg last_frame;
 reg watchdog_expired,sd_error_q;
 reg [9:0] byte_count;
 reg [3:0] audio_sector;
 reg [7:0] low_byte;
 reg [10:0] audio_byte;
 reg [63:0] magic;
 reg [31:0] geometry,format,record_size,reserved;
 reg write_seen,write_baseline;
 reg header_bad,header_legacy,header_hq,header_native;
 (* async_reg="true" *) reg [2:0] finish_ff,ack_ff;
 (* async_reg="true" *) reg [1:0] write_ack_ff;
 wire scaler_read,scaler_done,scaler_error;
 wire [31:0] scaler_address;
 wire [23:0] pixel;
 wire pixel_valid;
 assign requested_bank=write_bank[0];
 assign busy=state!=END && state!=FAIL;
 assign state_code=state;
 assign sector_read=(state==SCALE)?scaler_read:read_req;
 assign sector_address=(state==SCALE)?scaler_address:address;
 assign write_en=(state==SCALE) && pixel_valid && pixel_ready;
 assign write_data={pixel,8'd0};
 av_fast_scaler scaler(
  .clk(clk),.rst(rst || error),.start(scale_start),
  .video_format(video_format),
  .base_sector(record_sector+32'd4),.sector_read(scaler_read),.sector_address(scaler_address),
  .sector_data(sector_data),.sector_valid(sector_valid && state==SCALE),
  .sector_end(sector_end && state==SCALE),.pixel(pixel),.pixel_valid(pixel_valid),
  .pixel_ready(pixel_ready),.done(scaler_done),.error(scaler_error),.busy());
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   header_bad<=1;header_legacy<=0;header_hq<=0;header_native<=0;video_format<=0;
   watchdog_expired<=0;sd_error_q<=0;last_index<=0;last_frame<=0;state<=INIT;read_req<=0;address<=0;frame_count<=0;frame_index<=0;record_sector<=1;
   byte_count<=0;audio_sector<=0;audio_byte<=0;low_byte<=0;magic<=0;
   geometry<=0;format<=0;record_size<=0;reserved<=0;
   write_req<=0;write_bank<=0;request_toggle<=0;scale_start<=0;
   audio_we<=0;audio_address<=0;audio_data<=0;playing<=1;error<=0;ended<=0;
   finish_ff<=0;ack_ff<=0;write_ack_ff<=0;write_seen<=0;write_baseline<=0;watchdog<=0;
  end else begin
   header_legacy<=geometry==32'h007800a0 && record_size==117 && reserved==0;
   header_hq<=geometry==32'h00f00140 && record_size==304 && reserved==1;
   header_native<=geometry==32'h01e00280 && record_size==1204 && reserved==2;
   header_bad<=mode_800 || magic!=64'h0030324b36315641 || frame_count==0 || frame_count>1000000 ||
       format!=32'h3e800014 || !(header_legacy || header_hq || header_native);
   last_frame<=frame_index==last_index;
   sd_error_q<=sd_error;
   watchdog_expired<=(state!=INIT && state!=ACK && state!=END && state!=FAIL && watchdog==WATCHDOG-2);
   finish_ff<={finish_ff[1:0],write_finish_toggle};ack_ff<={ack_ff[1:0],ack_toggle};
   write_ack_ff<={write_ack_ff[0],write_req_ack};audio_we<=0;scale_start<=0;
   if(toggle_play && !error)playing<=!playing;
   if(finish_ff[2]!=write_baseline)write_seen<=1;
   if(state==INIT || state==ACK || state==END || state==FAIL)watchdog<=0;
   else watchdog<=watchdog+1'b1;
   if(state!=FAIL && (sd_error_q || (state!=INIT && state!=ACK && state!=END && watchdog_expired)))begin
    state<=FAIL;error<=1;playing<=0;read_req<=0;write_req<=0;
   end else case(state)
    INIT:if(sd_ready)begin read_req<=1;address<=0;byte_count<=0;state<=HEADER;end
    HEADER:begin
     if(sector_valid)begin
      if(byte_count<8)magic<={sector_data,magic[63:8]};
      else if(byte_count<12)frame_count<={sector_data,frame_count[31:8]};
      else if(byte_count<16)geometry<={sector_data,geometry[31:8]};
      else if(byte_count<20)format<={sector_data,format[31:8]};
      else if(byte_count<24)record_size<={sector_data,record_size[31:8]};
      else if(byte_count<28)reserved<={sector_data,reserved[31:8]};
      if(byte_count<513)byte_count<=byte_count+1'b1;
     end
     if(sector_end)begin
      read_req<=0;
      if(byte_count+sector_valid!=512)begin error<=1;state<=FAIL;playing<=0;end
      else state<=CHECK;
     end
    end
    CHECK:begin
     video_format<=header_native?2'd2:(header_hq?2'd1:2'd0);
     last_index<=frame_count[19:0]-20'd1;
     if(header_bad)begin error<=1;state<=FAIL;playing<=0;end
     else begin audio_sector<=0;audio_byte<=0;state<=AUDIO_START;end
    end
    AUDIO_START:begin address<=record_sector+audio_sector;read_req<=1;byte_count<=0;state<=AUDIO;end
    AUDIO:begin
     if(sector_valid)begin
      if(byte_count<513)byte_count<=byte_count+1'b1;
      if(audio_byte<1600)begin
       if(!audio_byte[0])low_byte<=sector_data;
       else begin audio_we<=1;audio_address<={write_bank[0],audio_byte[10:1]};audio_data<={sector_data,low_byte};end
      end
      audio_byte<=audio_byte+1'b1;
     end
     if(sector_end)begin
      read_req<=0;
      if(byte_count+sector_valid!=512)begin error<=1;state<=FAIL;playing<=0;end
      else state<=GAP;
     end
    end
    GAP:begin
     if(audio_sector==3)begin write_req<=1;write_seen<=0;write_baseline<=finish_ff[2];state<=WRITE_REQ;end
     else begin audio_sector<=audio_sector+1'b1;state<=AUDIO_START;end
    end
    WRITE_REQ:if(write_ack_ff[1])begin write_req<=0;state<=SCALE_START;end
    SCALE_START:begin scale_start<=1;state<=SCALE;end
    SCALE:begin
     if(scaler_error)begin error<=1;state<=FAIL;playing<=0;end
     else if(scaler_done)state<=DRAIN;
    end
    DRAIN:if(write_seen)state<=PUBLISH;
    PUBLISH:begin request_toggle<=!request_toggle;state<=ACK;end
    ACK:if(ack_ff[2]==request_toggle)begin
     if(last_frame)begin ended<=1;state<=END;end
     else begin
      frame_index<=frame_index+1'b1;record_sector<=record_sector+(video_format==2'd2 ? 32'd1204:(video_format==2'd1 ? 32'd304:32'd117));
      write_bank<={1'b0,!write_bank[0]};audio_sector<=0;audio_byte<=0;state<=AUDIO_START;
     end
    end
    END:begin end
    FAIL:begin read_req<=0;write_req<=0;playing<=0;end
    default:begin error<=1;state<=FAIL;playing<=0;end
   endcase
  end
 end
endmodule
