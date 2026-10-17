// WAV流解析：PCM/48kHz/16bit/单声道，遍历RIFF块和奇数字节填充。
// 每扇区先缓存，收到成功end（CRC已通过）后才解析/输出，坏扇区不泄漏样本。
module audio_wav #(parameter [31:0] START_SECTOR=131072,parameter FILESYSTEM=0,
 parameter [31:0] MAX_BYTES=16777216,
 parameter integer RETRY_CYCLES=100_000_000)(
 input clk,rst,sd_init_done,enable,sector_room,sample_ready,
 output req,output [31:0] addr,input [7:0] data,input data_valid,sector_end,read_error,
 output reg sample_valid,output reg [23:0] sample,output error,
 output reg [3:0] error_code,
 output reg ready);
 // Explicit one-hot states: failure/retry is also observed outside the case,
 // so this tool does not automatically recode the original binary register.
 localparam [14:0] IDLE=15'h0001,ENSURE=15'h0002,FETCH=15'h0004,
 WAIT_BYTE=15'h0008,CONSUME=15'h0010,RIFF_CHECK=15'h0020,
 CHUNK_CHECK=15'h0040,FMT_CHECK=15'h0080,WAIT_SPACE=15'h0100,
 FAILED=15'h0200,CHUNK_BOUNDS=15'h0400,CHUNK_APPLY=15'h0800,
 RIFF_APPLY=15'h1000,WAIT_SAMPLE=15'h2000,CHUNK_CLASSIFY=15'h4000;
 localparam RIFF=0,CHUNK=1,FMT=2,PCM=3;
 reg [14:0] state;
 reg [1:0] kind;
 reg [31:0] position,file_end,chunk_size,chunk_id,chunk_next;
 reg [31:0] available,trailing;
 reg [32:0] padded_size;
 reg position_ok,bounds_ok,riff_ok;
 reg fmt_chunk_ok,data_chunk_ok,tail_ok,is_fmt,is_data;
 reg [31:0] pcm_start,pcm_length,remaining;
 reg [31:0] cache_tag;
 reg cache_valid,fmt_valid,low_valid;
 reg [7:0] low_byte,q;
 reg [7:0] sector_mem[0:511];
 reg [9:0] count;
 reg [4:0] field;
 reg [31:0] riff_id,riff_size,wave_id,rate,byte_rate;
 reg [15:0] format,channels,align,bits;
 localparam RETRY_WIDTH=(RETRY_CYCLES<2)?1:$clog2(RETRY_CYCLES);
 reg [RETRY_WIDTH-1:0] retry_count;
 reg retry_due;
 reg resume_space;
 reg last_pcm_byte,sector_last_byte;
 reg sector_room_q;
 // Break FIFO Gray decode/occupancy arithmetic before WAV state/CE fanout.
 // Top reserves 260 slots for at most 256 sector samples; one-cycle delayed
 // permission cannot exhaust that guard space. WAIT_SAMPLE checks readiness
 // immediately before releasing its held sample, independently of byte parsing.
 always @(posedge clk or posedge rst)begin
  if(rst)sector_room_q<=0;
  else sector_room_q<=sector_room;
 end
 // error is the current failure, not the sticky OSD history. Codes:
 // 1 header/format; 2 SD/timeout; 3 incomplete/overlong sector; 4 chunk/bounds.
 assign error=|error_code;
 // One-hot invariant: use the FETCH bit directly at the arbiter boundary,
 // avoiding a 15-bit equality decode on the read-request/timer path.
 assign req=state[2] && sd_init_done;
 // FAT32 中 addr 是 WAV 文件内的相对扇区，由 sd_fat32 重映射到 LBA。
 assign addr=FILESYSTEM?cache_tag:START_SECTOR+cache_tag;
 // 同步RAM端口；ENSURE/WAIT_BYTE留出读延迟。
 always @(posedge clk)begin
  if(state[2] && data_valid && count<512)sector_mem[count[8:0]]<=data;
  q<=sector_mem[position[8:0]];
 end
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   state<=IDLE;kind<=RIFF;position<=0;file_end<=0;chunk_size<=0;chunk_id<=0;
   chunk_next<=0;pcm_start<=0;pcm_length<=0;remaining<=0;
   available<=0;trailing<=0;padded_size<=0;position_ok<=0;bounds_ok<=0;riff_ok<=0;
   fmt_chunk_ok<=0;data_chunk_ok<=0;tail_ok<=0;is_fmt<=0;is_data<=0;
   cache_tag<=0;cache_valid<=0;fmt_valid<=0;low_valid<=0;low_byte<=0;
   count<=0;field<=0;riff_id<=0;riff_size<=0;wave_id<=0;rate<=0;byte_rate<=0;
   format<=0;channels<=0;align<=0;bits<=0;sample_valid<=0;sample<=0;error_code<=0;ready<=0;
   retry_count<=0;retry_due<=RETRY_CYCLES<=1;
   resume_space<=0;last_pcm_byte<=0;sector_last_byte<=0;
  end else begin
   sample_valid<=0;
   if(!state[9])begin retry_count<=0;retry_due<=RETRY_CYCLES<=1;end
   // Keep the failed-state delay across SD reinitialization. An arbiter timeout
   // resets transport, but must not erase the failure or trigger an immediate retry.
   // Gate SD availability at request/sample boundaries rather than inserting
   // a failed-state/global-init mux on every parser register enable.
   case(state)
    IDLE:begin
     cache_valid<=0;fmt_valid<=0;low_valid<=0;error_code<=0;ready<=0;sample<=0;
     if(enable && sd_init_done)begin
      position<=0;kind<=RIFF;field<=0;count<=0;state<=ENSURE;
     end
    end
    ENSURE:begin
     // 初始RIFF最小长度及每次块尾检查保证下一个8字节块头在界内。
     if(!sd_init_done)begin state<=IDLE;ready<=0;cache_valid<=0;end
     else if(position>=MAX_BYTES)begin error_code<=4;state<=FAILED;end
     else if(kind==PCM && (!enable || !sector_room_q))state<=WAIT_SPACE;
     else if(cache_valid && cache_tag==position[31:9])state<=WAIT_BYTE;
     else begin cache_tag<=position[31:9];cache_valid<=0;count<=0;state<=FETCH;end
    end
    FETCH:begin
     if(data_valid && count<513)count<=count+1'b1;
     if(read_error || !sd_init_done)begin error_code<=2;ready<=0;state<=FAILED;end
     else if(sector_end)begin
      if(count+data_valid!=512)begin error_code<=3;ready<=0;state<=FAILED;end
      else begin cache_valid<=1;state<=WAIT_BYTE;end
     end
    end
    WAIT_BYTE:begin
     // remaining/position are stable here. Compare before CONSUME to keep
     // the 32-bit terminal decode off state and sample-hold transitions.
     last_pcm_byte<=remaining==1;sector_last_byte<=position[8:0]==511;
     state<=CONSUME;
    end
    CONSUME:begin
     if(kind==PCM)begin
      // 只在完整样本可被FIFO接受时推进；低字节可跨扇区保存。
      if(!enable)state<=CONSUME;
      else begin
       position<=position+1'b1;remaining<=remaining-1'b1;
       if(!low_valid)begin low_byte<=q;low_valid<=1;end
       else begin sample<={{8{q[7]}},q,low_byte};low_valid<=0;end
       if(last_pcm_byte)begin position<=pcm_start;remaining<=pcm_length;low_valid<=0;state<=WAIT_SPACE;end
       else if(sector_last_byte)state<=WAIT_SPACE;
       else state<=ENSURE;
       // Hold the completed sample until downstream accepts it. No FIFO-full
       // decode on the 32-bit byte position/remaining counter enables.
       if(low_valid)begin
        resume_space<=last_pcm_byte || sector_last_byte;
        state<=WAIT_SAMPLE;
       end
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
      error_code<=1;state<=FAILED;
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
     state<=CHUNK_CLASSIFY;
    end
    CHUNK_CLASSIFY:begin
     // Classify after bounds arithmetic, before error/state/counter fanout.
     is_fmt<=chunk_id==32'h20746d66;is_data<=chunk_id==32'h61746164;
     fmt_chunk_ok<=chunk_size>=16 && !fmt_valid;
     data_chunk_ok<=fmt_valid && chunk_size>=2 && !chunk_size[0];
     tail_ok<=trailing>=8;
     state<=CHUNK_APPLY;
    end
    CHUNK_APPLY:begin
     if(!bounds_ok)begin error_code<=4;state<=FAILED;end
     else if(is_fmt)begin
      if(!fmt_chunk_ok)begin error_code<=4;state<=FAILED;end
      else begin kind<=FMT;field<=0;state<=ENSURE;end
     end else if(is_data)begin
      if(!data_chunk_ok)begin error_code<=4;state<=FAILED;end
      else begin
       pcm_start<=position;pcm_length<=chunk_size;remaining<=chunk_size;low_valid<=0;
       kind<=PCM;ready<=1;state<=WAIT_SPACE;
      end
     end else if(!tail_ok)begin error_code<=4;state<=FAILED;end
     else begin position<=chunk_next;field<=0;state<=ENSURE;end
    end
    FMT_CHECK:begin
     if(format!=1 || channels!=1 || rate!=48000 || byte_rate!=96000 || align!=2 || bits!=16)
      begin error_code<=1;state<=FAILED;end
     else if(!tail_ok)begin error_code<=4;state<=FAILED;end
     else begin fmt_valid<=1;position<=chunk_next;kind<=CHUNK;field<=0;state<=ENSURE;end
    end
    WAIT_SPACE:begin
     if(!sd_init_done)begin state<=IDLE;ready<=0;end
     else if(enable && sector_room_q)state<=ENSURE;
    end
    WAIT_SAMPLE:begin
     if(!sd_init_done)begin state<=IDLE;ready<=0;sample<=0;end
     else if(enable && sample_ready)begin
      sample_valid<=1;state<=resume_space?WAIT_SPACE:ENSURE;
     end
    end
    FAILED:begin
     ready<=0;sample<=0;cache_valid<=0;low_valid<=0;
     if(retry_due)begin error_code<=0;retry_count<=0;state<=IDLE;end
     else begin
      retry_count<=retry_count+1'b1;
      retry_due<=retry_count==RETRY_CYCLES-2;
     end
    end
    default:begin error_code<=4;state<=FAILED;end
   endcase
  end
 end
endmodule
