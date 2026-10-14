// 原始连续扇区WAV：PCM/48kHz/16bit/单声道，遍历RIFF块和奇数字节填充。
// 每扇区先缓存，收到成功end（CRC已通过）后才解析/输出，坏扇区不泄漏样本。
module audio_wav #(parameter [31:0] START_SECTOR=131072,
 parameter [31:0] MAX_BYTES=16777216)(
 input clk,rst,sd_init_done,enable,sector_room,sample_ready,
 output req,output [31:0] addr,input [7:0] data,input data_valid,sector_end,read_error,
 output reg sample_valid,output reg [23:0] sample,output reg error,
 output reg ready);
 localparam IDLE=0,ENSURE=1,FETCH=2,WAIT_BYTE=3,CONSUME=4,
 RIFF_CHECK=5,CHUNK_CHECK=6,FMT_CHECK=7,WAIT_SPACE=8,FAILED=9,
 CHUNK_BOUNDS=10,CHUNK_APPLY=11,RIFF_APPLY=12;
 localparam RIFF=0,CHUNK=1,FMT=2,PCM=3;
 reg [3:0] state;
 reg [1:0] kind;
 reg [31:0] position,file_end,chunk_size,chunk_id,chunk_next;
 reg [31:0] available,trailing;
 reg [32:0] padded_size;
 reg position_ok,bounds_ok,riff_ok;
 reg [31:0] pcm_start,pcm_length,remaining;
 reg [31:0] cache_tag;
 reg cache_valid,fmt_valid,low_valid;
 reg [7:0] low_byte,q;
 reg [7:0] sector_mem[0:511];
 reg [9:0] count;
 reg [4:0] field;
 reg [31:0] riff_id,riff_size,wave_id,rate,byte_rate;
 reg [15:0] format,channels,align,bits;
 assign req=state==FETCH;
 assign addr=START_SECTOR+cache_tag;
 // 同步RAM端口；ENSURE/WAIT_BYTE留出读延迟。
 always @(posedge clk)begin
  if(state==FETCH && data_valid && count<512)sector_mem[count[8:0]]<=data;
  q<=sector_mem[position[8:0]];
 end
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   state<=IDLE;kind<=RIFF;position<=0;file_end<=0;chunk_size<=0;chunk_id<=0;
   chunk_next<=0;pcm_start<=0;pcm_length<=0;remaining<=0;
   available<=0;trailing<=0;padded_size<=0;position_ok<=0;bounds_ok<=0;riff_ok<=0;
   cache_tag<=0;cache_valid<=0;fmt_valid<=0;low_valid<=0;low_byte<=0;
   count<=0;field<=0;riff_id<=0;riff_size<=0;wave_id<=0;rate<=0;byte_rate<=0;
   format<=0;channels<=0;align<=0;bits<=0;sample_valid<=0;sample<=0;error<=0;ready<=0;
  end else begin
   sample_valid<=0;
   if(!sd_init_done)begin
    state<=IDLE;cache_valid<=0;fmt_valid<=0;ready<=0;low_valid<=0;error<=0;
   end else case(state)
    IDLE:if(enable)begin
     position<=0;kind<=RIFF;field<=0;cache_valid<=0;fmt_valid<=0;error<=0;state<=ENSURE;
    end
    ENSURE:begin
     // 初始RIFF最小长度及每次块尾检查保证下一个8字节块头在界内。
     if(position>=MAX_BYTES)begin error<=1;state<=FAILED;end
     else if(kind==PCM && (!enable || !sector_room))state<=WAIT_SPACE;
     else if(cache_valid && cache_tag==position[31:9])state<=WAIT_BYTE;
     else begin cache_tag<=position[31:9];cache_valid<=0;count<=0;state<=FETCH;end
    end
    FETCH:begin
     if(data_valid && count<513)count<=count+1'b1;
     if(read_error)begin error<=1;ready<=0;state<=FAILED;end
     else if(sector_end)begin
      if(count+data_valid!=512)begin error<=1;ready<=0;state<=FAILED;end
      else begin cache_valid<=1;state<=WAIT_BYTE;end
     end
    end
    WAIT_BYTE:state<=CONSUME;
    CONSUME:begin
     if(kind==PCM)begin
      // 只在完整样本可被FIFO接受时推进；低字节可跨扇区保存。
      if(!enable || (low_valid && !sample_ready))state<=CONSUME;
      else begin
       position<=position+1'b1;remaining<=remaining-1'b1;
       if(!low_valid)begin low_byte<=q;low_valid<=1;end
       else begin sample<={{8{q[7]}},q,low_byte};sample_valid<=1;low_valid<=0;end
       if(remaining==1)begin position<=pcm_start;remaining<=pcm_length;low_valid<=0;state<=WAIT_SPACE;end
       else if(position[8:0]==511)state<=WAIT_SPACE;
       else state<=ENSURE;
      end
     end else begin
      position<=position+1'b1;field<=field+1'b1;state<=ENSURE;
      if(kind==RIFF)begin
       if(field<4)riff_id[field*8+:8]<=q;
       else if(field<8)riff_size[(field-4)*8+:8]<=q;
       else wave_id[(field-8)*8+:8]<=q;
       if(field==11)state<=RIFF_CHECK;
      end else if(kind==CHUNK)begin
       if(field<4)chunk_id[field*8+:8]<=q;else chunk_size[(field-4)*8+:8]<=q;
       if(field==7)state<=CHUNK_CHECK;
      end else begin
       case(field)
        0,1:format[field*8+:8]<=q;
        2,3:channels[(field-2)*8+:8]<=q;
        4,5,6,7:rate[(field-4)*8+:8]<=q;
        8,9,10,11:byte_rate[(field-8)*8+:8]<=q;
        12,13:align[(field-12)*8+:8]<=q;
        14,15:bits[(field-14)*8+:8]<=q;
       endcase
       if(field==15)state<=FMT_CHECK;
      end
     end
    end
    RIFF_CHECK:begin
     riff_ok<=riff_id==32'h46464952 && wave_id==32'h45564157 && riff_size>=36 && riff_size<=MAX_BYTES-8;
     file_end<=riff_size+8;
     state<=RIFF_APPLY;
    end
    RIFF_APPLY:begin
     if(!riff_ok)begin
      error<=1;state<=FAILED;
     end else begin kind<=CHUNK;field<=0;state<=ENSURE;end
    end
    CHUNK_CHECK:begin
     // 每级只做一次加/减，避免边界减法、padding减法、比较串联超出100MHz预算。
     available<=file_end-position;
     position_ok<=position<=file_end;
     padded_size<={1'b0,chunk_size}+chunk_size[0];
     state<=CHUNK_BOUNDS;
    end
    CHUNK_BOUNDS:begin
     bounds_ok<=position_ok && padded_size<={1'b0,available};
     trailing<=available-padded_size[31:0];
     chunk_next<=position+padded_size[31:0];
     state<=CHUNK_APPLY;
    end
    CHUNK_APPLY:begin
     if(!bounds_ok)begin error<=1;state<=FAILED;end
     else if(chunk_id==32'h20746d66)begin
      if(chunk_size<16 || fmt_valid)begin error<=1;state<=FAILED;end
      else begin kind<=FMT;field<=0;state<=ENSURE;end
     end else if(chunk_id==32'h61746164)begin
      if(!fmt_valid || chunk_size<2 || chunk_size[0])begin error<=1;state<=FAILED;end
      else begin
       pcm_start<=position;pcm_length<=chunk_size;remaining<=chunk_size;low_valid<=0;
       kind<=PCM;ready<=1;state<=WAIT_SPACE;
      end
     end else if(trailing<8)begin error<=1;state<=FAILED;end
     else begin position<=chunk_next;field<=0;state<=ENSURE;end
    end
    FMT_CHECK:begin
     if(format!=1 || channels!=1 || rate!=48000 || byte_rate!=96000 || align!=2 || bits!=16 ||
        trailing<8)begin error<=1;state<=FAILED;end
     else begin fmt_valid<=1;position<=chunk_next;kind<=CHUNK;field<=0;state<=ENSURE;end
    end
    WAIT_SPACE:if(enable && sector_room)state<=ENSURE;
    FAILED:begin ready<=0;sample<=0;end
    default:begin error<=1;state<=FAILED;end
   endcase
  end
 end
endmodule
