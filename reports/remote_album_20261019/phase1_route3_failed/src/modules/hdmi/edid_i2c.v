// Boot-clock DDC master: A0 write, offset 0, repeated START, A1 read,
// 128 sequential bytes, ACK first 127, NACK last, STOP. No BRAM.
// Both lines drive low or release. SCL remains an OUTPUT to preserve the
// board interface; slave clock stretching cannot be sampled on this port.
// Missing/NACKed devices release the bus; the existing EDID parser times out
// to VGA. A later start can retry. Reset always releases both lines.
module edid_i2c #(
    parameter integer QUARTER_CYCLES=63 // 25 MHz/(4*63) = 99.206 kHz
)(
    input clk,input rst,input start,
    output scl,inout sda,
    output reg valid,output reg [7:0] data,
    output reg busy,output reg done,output reg error
);
    localparam CW=(QUARTER_CYCLES>1)?$clog2(QUARTER_CYCLES):1;
    localparam IDLE=0,START_A=1,START_B=2,START_C=3,
        TX_LOW=4,TX_RISE=5,TX_HIGH=6,TX_FALL=7,
        ACK_LOW=8,ACK_RISE=9,ACK_HIGH=10,ACK_FALL=11,
        RS_LOW=12,RS_HIGH=13,RS_START=14,RS_FALL=15,
        RX_LOW=16,RX_RISE=17,RX_HIGH=18,RX_FALL=19,
        OUT_LOW=20,OUT_RISE=21,OUT_HIGH=22,OUT_FALL=23,
        STOP_LOW=24,STOP_HIGH=25,STOP_RELEASE=26,FINISH=27;
    reg [4:0] state;
    reg [CW-1:0] divider;
    reg scl_low,sda_low,nack;
    reg [1:0] command_byte;
    reg [2:0] bit_index;
    reg [6:0] byte_index;
    reg [7:0] tx,rx;
    (* async_reg="true" *) reg [1:0] sda_sync;
    assign scl=scl_low?1'b0:1'bz;
    assign sda=sda_low?1'b0:1'bz;
    always @(posedge clk or posedge rst) begin
        if(rst)sda_sync<=2'b11;
        else sda_sync<={sda_sync[0],sda};
    end
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            state<=IDLE;divider<=0;scl_low<=0;sda_low<=0;
            valid<=0;data<=0;busy<=0;done<=0;error<=0;nack<=0;
            command_byte<=0;bit_index<=7;byte_index<=0;tx<=0;rx<=0;
        end else begin
            valid<=0;done<=0;
            if(state==IDLE) begin
                divider<=0;scl_low<=0;sda_low<=0;
                if(start)begin
                    busy<=1;error<=0;nack<=0;command_byte<=0;
                    byte_index<=0;bit_index<=7;tx<=8'ha0;rx<=0;
                    state<=START_A;
                end
            end else if(divider==QUARTER_CYCLES-1)begin
                divider<=0;
                case(state)
                    START_A:state<=START_B;
                    START_B:begin sda_low<=1;state<=START_C;end
                    START_C:begin scl_low<=1;state<=TX_LOW;end
                    TX_LOW:begin sda_low<=!tx[bit_index];state<=TX_RISE;end
                    TX_RISE:begin scl_low<=0;state<=TX_HIGH;end
                    TX_HIGH:state<=TX_FALL;
                    TX_FALL:begin
                        scl_low<=1;
                        if(bit_index==0)state<=ACK_LOW;
                        else begin bit_index<=bit_index-1'b1;state<=TX_LOW;end
                    end
                    ACK_LOW:begin sda_low<=0;state<=ACK_RISE;end
                    ACK_RISE:begin scl_low<=0;state<=ACK_HIGH;end
                    ACK_HIGH:begin nack<=sda_sync[1];state<=ACK_FALL;end
                    ACK_FALL:begin
                        scl_low<=1;
                        if(nack)begin error<=1;state<=STOP_LOW;end
                        else case(command_byte)
                            0:begin tx<=0;bit_index<=7;command_byte<=1;state<=TX_LOW;end
                            1:begin command_byte<=2;state<=RS_LOW;end
                            default:begin bit_index<=7;rx<=0;state<=RX_LOW;end
                        endcase
                    end
                    RS_LOW:begin sda_low<=0;state<=RS_HIGH;end
                    RS_HIGH:begin scl_low<=0;state<=RS_START;end
                    RS_START:begin sda_low<=1;state<=RS_FALL;end
                    RS_FALL:begin scl_low<=1;tx<=8'ha1;bit_index<=7;state<=TX_LOW;end
                    RX_LOW:begin sda_low<=0;state<=RX_RISE;end
                    RX_RISE:begin scl_low<=0;state<=RX_HIGH;end
                    RX_HIGH:begin rx[bit_index]<=sda_sync[1];state<=RX_FALL;end
                    RX_FALL:begin
                        scl_low<=1;
                        if(bit_index==0)state<=OUT_LOW;
                        else begin bit_index<=bit_index-1'b1;state<=RX_LOW;end
                    end
                    OUT_LOW:begin sda_low<=(byte_index!=127);state<=OUT_RISE;end
                    OUT_RISE:begin scl_low<=0;state<=OUT_HIGH;end
                    OUT_HIGH:state<=OUT_FALL;
                    OUT_FALL:begin
                        scl_low<=1;sda_low<=0;data<=rx;valid<=1;
                        if(byte_index==127)state<=STOP_LOW;
                        else begin byte_index<=byte_index+1'b1;bit_index<=7;state<=RX_LOW;end
                    end
                    STOP_LOW:begin scl_low<=1;sda_low<=1;state<=STOP_HIGH;end
                    STOP_HIGH:begin scl_low<=0;state<=STOP_RELEASE;end
                    STOP_RELEASE:begin sda_low<=0;state<=FINISH;end
                    FINISH:begin busy<=0;done<=1;state<=IDLE;end
                    default:begin error<=1;state<=STOP_LOW;end
                endcase
            end else divider<=divider+1'b1;
        end
    end
endmodule
