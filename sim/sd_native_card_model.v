`timescale 1ns/1ps
// Logical SD card peer: works only from pins, never peeks at DUT state.
// CRC7 uses polynomial long division, independently of the host implementation.
module sd_native_card_model #(parameter integer IMAGE_MODE=0)(
 input rst,SD_CLK,inout SD_CMD,inout [3:0] SD_DAT,
 input ccs,input [3:0] fault,
 output reg [31:0] last_read_argument,
 output reg [31:0] commands,reads,errors
);
 // fault: 1=R7 echo, 2=response CRC, 3..6=CRC DAT0..3,
 // 7=bad start, 8=bad end, 9=no data, 10=no response, 11=busy forever,
 // 12=ACMD41 never ready, 13=R1 error, 14=R2 CRC, 15=bad R6.
 reg cmd_oe=0,cmd_out=1,dat_oe=0;
 reg [3:0] dat_out=15;
 assign SD_CMD=cmd_oe?cmd_out:1'bz;
 assign SD_DAT=dat_oe?dat_out:4'bzzzz;
 reg [47:0] command_frame;
 integer cmd_bits=0,resp_bits=0,response_delay=0,data_pos=-1,busy_left=0;
 reg [135:0] resp_frame;
 reg data_pending=0,busy_pending=0,app=0,selected=0,wide=0;
 reg [15:0] rca=16'h4567;
 integer attempts=0,i,lane;
 integer fd=0,seek_result,got;
 reg [5:0] command_index;
 reg [31:0] arg,value;
 reg [7:0] payload [0:511];
 reg [15:0] data_crc [0:3];
 reg [119:0] cid=120'h123456789abcdef0123456789abcde;
 function [6:0] reference_crc7;
  input [135:0] bits;input integer length;
  reg [7:0] rem;integer j;
  begin
   rem=0;
   for(j=length-1;j>=-7;j=j-1)begin
    rem={rem[6:0],1'b0};
    if(j>=0)rem[0]=bits[j];
    if(rem[7])rem=rem^8'h89;
   end
   reference_crc7=rem[6:0];
  end
 endfunction
 function [15:0] reference_crc16;
  input [15:0] c;input b;
  reg [16:0] rem;
  begin
   rem={c,b};
   if(rem[16])rem=rem^17'h11021;
   reference_crc16=rem[15:0];
  end
 endfunction
 function [7:0] pattern;
  input integer pos;input [31:0] sector;
  begin pattern=(pos*37) ^ (pos>>3) ^ sector[7:0] ^ (sector>>9);end
 endfunction
 task reply;
  input [5:0] idx;input [31:0] body;reg [39:0] header;
  begin
   header={2'b00,idx,body};
   resp_frame={88'd0,header,reference_crc7({96'd0,header},40),1'b1};
   if(fault==2 && command_index==17)resp_frame[5]=!resp_frame[5];
   resp_bits=48;response_delay=2;
  end
 endtask
 task prepare_data;
  begin
   if(IMAGE_MODE!=0)begin
    seek_result=$fseek(fd,(ccs?arg:(arg>>9))*512,0);
    got=$fread(payload,fd);
    if(seek_result!=0 || got!=512)begin
     $display("FAILED native card image seek/read LBA=%0d bytes=%0d",arg,got);$finish;
    end
   end
   for(lane=0;lane<4;lane=lane+1)data_crc[lane]=0;
   for(i=0;i<512;i=i+1)begin
    if(IMAGE_MODE==0)payload[i]=pattern(i,arg);
    for(lane=0;lane<4;lane=lane+1)begin
     data_crc[lane]=reference_crc16(data_crc[lane],payload[i][lane+4]);
     data_crc[lane]=reference_crc16(data_crc[lane],payload[i][lane]);
    end
   end
   // Polynomial division of the complete payload followed by sixteen zeros.
   for(i=0;i<16;i=i+1)
    for(lane=0;lane<4;lane=lane+1)data_crc[lane]=reference_crc16(data_crc[lane],1'b0);
  end
 endtask
 task handle_command;
  begin
   commands=commands+1;command_index=command_frame[45:40];arg=command_frame[39:8];
   if(command_frame[47:46]!=2'b01 || !command_frame[0] ||
      command_frame[7:1]!=reference_crc7({96'd0,command_frame[47:8]},40))begin
    errors=errors+1;$display("MODEL command CRC/frame error cmd=%0d frame=%h",command_index,command_frame);
   end
   if(fault!=10 || command_index==0)case(command_index)
    0:begin app=0;selected=0;wide=0;attempts=0;end
    8:reply(8,fault==1?32'h1ab:32'h1aa);
    55:begin
     if(arg!=(selected?{rca,16'd0}:32'd0))errors=errors+1;
     app=1;reply(55,32'h20);
    end
    41:begin
     if(!app || arg!=32'h40ff8000)errors=errors+1;
     app=0;attempts=attempts+1;
     reply(63,{(attempts>=2 && fault!=12),ccs,6'd0,24'hff8000});
     // R3 has reserved CRC bits, deliberately unrelated to its body.
     resp_frame[7:1]=7'h7f;
    end
    2:begin
     resp_frame={8'h3f,cid,reference_crc7({16'd0,cid},120),1'b1};
     if(fault==14)resp_frame[4]=!resp_frame[4];
     resp_bits=136;response_delay=2;
    end
    3:reply(3,fault==15?32'h4567e000:{rca,16'd0});
    7:begin
     if(arg!={rca,16'd0})errors=errors+1;
     selected=1;reply(7,32'h900);busy_pending=1;
    end
    6:begin
     if(!app || !selected || arg!=2)errors=errors+1;
     app=0;wide=1;reply(6,32'h900);
    end
    16:begin if(!wide || arg!=512)errors=errors+1;reply(16,32'h900);end
    17:begin
     if(!wide || !selected)errors=errors+1;
     reads=reads+1;last_read_argument=arg;prepare_data;
     reply(17,fault==13?32'h00400900:32'h900);
     data_pending=(fault!=9 && fault!=13);
    end
    default:begin errors=errors+1;reply(command_index,32'h00400000);end
   endcase
  end
 endtask
 initial begin
  commands=0;reads=0;errors=0;last_read_argument=0;
  if(IMAGE_MODE==1)fd=$fopen("../reports/fat32_20261015/vectors/super.img","rb");
  if(IMAGE_MODE==2)fd=$fopen("../reports/fat32_20261015/vectors/mbr.img","rb");
  if(IMAGE_MODE!=0 && fd==0)begin $display("FAILED native card image missing");$finish;end
 end
 always @(posedge rst)begin
  cmd_oe=0;dat_oe=0;cmd_bits=0;resp_bits=0;response_delay=0;
  data_pos=-1;busy_left=0;data_pending=0;busy_pending=0;app=0;selected=0;wide=0;attempts=0;
 end
 always @(posedge SD_CLK)if(!rst && !cmd_oe)begin
  if(cmd_bits==0)begin if(SD_CMD===1'b0)begin command_frame=0;cmd_bits=1;end end
  else begin
   command_frame={command_frame[46:0],SD_CMD};
   if(cmd_bits==47)begin cmd_bits=0;handle_command;end
   else cmd_bits=cmd_bits+1;
  end
 end
 always @(negedge SD_CLK)if(!rst)begin
  if(response_delay>0)response_delay=response_delay-1;
  else if(resp_bits>0)begin
   cmd_oe=1;cmd_out=resp_frame[resp_bits-1];resp_bits=resp_bits-1;
  end else if(cmd_oe)begin
   cmd_oe=0;
   if(data_pending)begin data_pos=0;data_pending=0;end
   if(busy_pending)begin busy_left=8;busy_pending=0;end
  end
  if(busy_left>0)begin
   dat_oe=1;dat_out=14;
   if(fault!=11)busy_left=busy_left-1;
  end else if(data_pos>=0)begin
   dat_oe=1;
   if(data_pos==0)dat_out=(fault==7)?4'b1110:4'd0;
   else if(data_pos<=1024)begin
    if(data_pos[0])dat_out=payload[(data_pos-1)/2][7:4];
    else dat_out=payload[(data_pos-1)/2][3:0];
   end else if(data_pos<=1040)begin
    for(lane=0;lane<4;lane=lane+1)dat_out[lane]=data_crc[lane][1040-data_pos];
    if(data_pos==1027)case(fault)
     3:dat_out[0]=!dat_out[0];4:dat_out[1]=!dat_out[1];
     5:dat_out[2]=!dat_out[2];6:dat_out[3]=!dat_out[3];
    endcase
   end else if(data_pos==1041)dat_out=(fault==8)?4'b0111:4'b1111;
   else begin dat_oe=0;data_pos=-2;end
   data_pos=data_pos+1;
  end else dat_oe=0;
 end
endmodule
