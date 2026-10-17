// Native SD SDR PHY. All state uses the 100 MHz host clock; SD_CLK is an
// output, never an internal clock. Launch falling; sample rising at25MHz,
// one host cycle after rising at50MHz (board I/O signoff remains separate).
// Six-wire mapping is documented; physical interface validation remains pending.
module sd_bus_phy #(
 parameter integer LOW_HALF_CYCLES=250,
 parameter integer WAIT_TIMEOUT_CYCLES=67108864
)(
 input clk,rst,high_speed,open_drain,
 input high_speed_50,input [9:0] read_length,
 output reg SD_CLK,
 inout SD_CMD,
 inout [3:0] SD_DAT,
 output rise_tick,fall_tick,
 input cmd_start,input [5:0] cmd_index,input [31:0] cmd_argument,
 // 0=no response, 1=R1, 2=R2, 3=R3 (no CRC), 4=R6, 5=R7, 6=R1b.
 input [2:0] response_type,
 output cmd_ready,output reg cmd_done,cmd_error,
 output reg [135:0] response,
 input read_arm,read_cancel,
 output reg [7:0] read_data,output reg read_valid,read_done,read_error
);
 reg [15:0] divider,half_cycles;
 assign rise_tick=(divider==half_cycles-1'b1) && !SD_CLK;
 assign fall_tick=(divider==half_cycles-1'b1) && SD_CLK;
 always @(posedge clk or posedge rst) begin
  if(rst)begin divider<=0;half_cycles<=LOW_HALF_CYCLES;SD_CLK<=0;end
  else if(divider==half_cycles-1'b1)begin
   divider<=0;SD_CLK<=!SD_CLK;
   // Change division only at a full-cycle boundary: no runt clock pulses.
   if(SD_CLK)half_cycles<=high_speed_50 ? 16'd1 : (high_speed ? 16'd2 : LOW_HALF_CYCLES);
  end else divider<=divider+1'b1;
 end
 // SDR50 samples one host cycle after the nominal rising edge. At 100MHz
 // this places the sample 20ns after the previous card launch, rather than
 // assuming a zero-delay card. External I/O setup/hold still needs signoff.
 reg delayed_rise;
 always @(posedge clk or posedge rst)begin
  if(rst)delayed_rise<=0;else delayed_rise<=rise_tick;
 end
 wire sample_tick=high_speed_50?delayed_rise:rise_tick;
 reg cmd_oe,cmd_out;
 assign SD_CMD=(cmd_oe && (!open_drain || !cmd_out)) ? cmd_out : 1'bz;
 // This read-only transport never drives DAT, including during initialization.
 // Keep the tri-state at the I/O boundary when integrated in the board top.
 assign SD_DAT=4'bzzzz;
 function [6:0] crc7_bit;
  input [6:0] c;input b;
  begin crc7_bit={c[5:0],1'b0} ^ ((c[6]^b)?7'h09:7'd0);end
 endfunction
 function [15:0] crc16_bit;
  input [15:0] c;input b;
  begin crc16_bit={c[14:0],1'b0} ^ ((c[15]^b)?16'h1021:16'd0);end
 endfunction
 localparam C_IDLE=0,C_TX=1,C_TURN=2,C_WAIT=3,C_RX=4,C_CHECK=5,C_BUSY=6,C_RELEASE=7;
 reg [2:0] cstate,kind;
 reg [5:0] index;
 reg [39:0] tx_header;
 reg [5:0] tx_bit;
 reg [7:0] rx_count,rx_length;
 reg [6:0] tx_crc,rx_crc;
 reg [31:0] cmd_timer;
 reg [3:0] command_gap;
 // SD Ncc requires at least eight clocks between commands. This is protocol
 // spacing, not a software delay; data reception remains fully concurrent.
 always @(posedge clk or posedge rst)begin
  if(rst)command_gap<=0;
  else if(cstate!=C_RELEASE)command_gap<=0;
  else if(rise_tick && command_gap<8)command_gap<=command_gap+1'b1;
 end
 assign cmd_ready=(cstate==C_IDLE);
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   cstate<=C_IDLE;kind<=0;index<=0;tx_header<=0;tx_bit<=0;
   rx_count<=0;rx_length<=0;tx_crc<=0;rx_crc<=0;response<=0;
   cmd_timer<=0;cmd_oe<=0;cmd_out<=1;cmd_done<=0;cmd_error<=0;
  end else begin
   cmd_done<=0;cmd_error<=0;
   if(cstate==C_IDLE || cstate==C_RELEASE)cmd_timer<=0;
   else cmd_timer<=cmd_timer+1'b1;
   if(cstate!=C_IDLE && cstate!=C_RELEASE && cmd_timer>=WAIT_TIMEOUT_CYCLES-1)begin
    cmd_oe<=0;cmd_done<=1;cmd_error<=1;cstate<=C_RELEASE;
   end else case(cstate)
    C_IDLE:if(cmd_start)begin
     tx_header<={2'b01,cmd_index,cmd_argument};tx_crc<=0;tx_bit<=47;
     index<=cmd_index;kind<=response_type;response<=0;rx_crc<=0;
     rx_length<=(response_type==2)?136:48;cstate<=C_TX;
    end
    C_TX:if(fall_tick)begin
     cmd_oe<=1;
     if(tx_bit>=8)begin
      cmd_out<=tx_header[39];tx_header<={tx_header[38:0],1'b0};
      tx_crc<=crc7_bit(tx_crc,tx_header[39]);
     end else if(tx_bit!=0)begin cmd_out<=tx_crc[6];tx_crc<={tx_crc[5:0],1'b0};end
     else begin cmd_out<=1;cstate<=C_TURN;end
     tx_bit<=tx_bit-1'b1;
    end
    C_TURN:if(fall_tick)begin
     cmd_oe<=0;
     if(kind==0)begin cmd_done<=1;cstate<=C_RELEASE;end
     else cstate<=C_WAIT;
    end
    C_WAIT:if(sample_tick && SD_CMD==1'b0)begin
     response<=0;rx_count<=1;rx_crc<=0;cstate<=C_RX;
    end
    C_RX:if(sample_tick)begin
     response<={response[134:0],SD_CMD};
     // R2 CRC covers CID/CSD bits 127:8, excluding its eight-bit header.
     if(rx_count<rx_length-8 && (kind!=2 || rx_count>=8))
      rx_crc<=crc7_bit(rx_crc,SD_CMD);
     rx_count<=rx_count+1'b1;
     if(rx_count==rx_length-1'b1)cstate<=C_CHECK;
    end
    C_CHECK:begin
     if(!response[0] || (kind!=3 && response[7:1]!=rx_crc) ||
        (kind==2 ? response[135:128]!=8'h3f :
         (response[47:46]!=0 || response[45:40]!=(kind==3?6'd63:index))))begin
      cmd_done<=1;cmd_error<=1;cstate<=C_RELEASE;
     end else if(kind==6)cstate<=C_BUSY;
     else begin cmd_done<=1;cstate<=C_RELEASE;end
    end
    C_BUSY:if(sample_tick && SD_DAT[0]==1'b1)begin cmd_done<=1;cstate<=C_RELEASE;end
    C_RELEASE:if(!cmd_start && command_gap>=8)cstate<=C_IDLE;
    default:cstate<=C_IDLE;
   endcase
  end
 end
 localparam D_IDLE=0,D_WAIT=1,D_DATA=2,D_CRC=3,D_END=4,D_DROP=5;
 reg [2:0] dstate;
 reg [9:0] nibble_count,last_nibble;
 reg [3:0] upper_nibble,crc_count;
 reg [15:0] crc0,crc1,crc2,crc3;
 reg crc_bad;
 reg [31:0] data_timer;
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   dstate<=D_IDLE;nibble_count<=0;last_nibble<=1023;upper_nibble<=0;crc_count<=0;
   crc0<=0;crc1<=0;crc2<=0;crc3<=0;crc_bad<=0;data_timer<=0;
   read_data<=0;read_valid<=0;read_done<=0;read_error<=0;
  end else begin
   read_valid<=0;read_done<=0;read_error<=0;
   if(dstate==D_IDLE || rise_tick)data_timer<=0;
   else data_timer<=data_timer+1'b1;
   // Start-token waiting needs a total budget; clocks alone are not progress.
   if(dstate==D_WAIT)data_timer<=data_timer+1'b1;
   if(read_cancel)begin dstate<=D_IDLE;data_timer<=0;end
   else if(read_arm)begin
    dstate<=D_WAIT;data_timer<=0;crc0<=0;crc1<=0;crc2<=0;crc3<=0;
    crc_bad<=0;nibble_count<=0;last_nibble<=(read_length==64)?10'd127:10'd1023;
   end else if(dstate!=D_IDLE && data_timer>=WAIT_TIMEOUT_CYCLES-1)begin
    dstate<=D_IDLE;read_error<=1;
   end else if(sample_tick)case(dstate)
    D_WAIT:if(SD_DAT==4'b0000)dstate<=D_DATA;
     else if(SD_DAT!=4'b1111)begin dstate<=D_DROP;nibble_count<=0;end
    D_DATA:begin
     crc0<=crc16_bit(crc0,SD_DAT[0]);crc1<=crc16_bit(crc1,SD_DAT[1]);
     crc2<=crc16_bit(crc2,SD_DAT[2]);crc3<=crc16_bit(crc3,SD_DAT[3]);
     if(!nibble_count[0])upper_nibble<=SD_DAT;
     else begin read_data<={upper_nibble,SD_DAT};read_valid<=1;end
     nibble_count<=nibble_count+1'b1;
     if(nibble_count==last_nibble)begin dstate<=D_CRC;crc_count<=0;end
    end
    D_CRC:begin
     if(SD_DAT!={crc3[15],crc2[15],crc1[15],crc0[15]})crc_bad<=1;
     crc0<=crc0<<1;crc1<=crc1<<1;crc2<=crc2<<1;crc3<=crc3<<1;
     crc_count<=crc_count+1'b1;
     if(crc_count==15)dstate<=D_END;
    end
    D_END:begin
     dstate<=D_IDLE;
     if(crc_bad || SD_DAT!=4'b1111)read_error<=1;
     else read_done<=1;
    end
    // An invalid multi-line start may precede a sector already being sent.
    // Drain its remaining 1024 payload + 16 CRC + 1 end clocks before reuse.
    D_DROP:if(nibble_count==last_nibble)begin dstate<=D_CRC;crc_count<=0;crc_bad<=1;end
     else nibble_count<=nibble_count+1'b1;
    default:dstate<=D_IDLE;
   endcase
  end
 end
endmodule
