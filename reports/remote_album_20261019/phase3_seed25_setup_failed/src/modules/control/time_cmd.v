// Atomic T+HHMMSS parser. No publication until six digits and calendar bounds pass.
module time_cmd #(parameter TIMEOUT_CYCLES=50000000)(
 input clk,input rst,input [7:0] uart_data,input uart_valid,
 output reg [23:0] time_bcd,output reg [7:0] time_seq,
 output reg time_set,output busy,output reg reply_valid,output reg reply_ok);
 localparam CW=(TIMEOUT_CYCLES<2)?1:$clog2(TIMEOUT_CYCLES);
 reg [CW-1:0] wait_count;
 reg [2:0] digits;
 reg [23:0] acc;
 wire digit=(uart_data>=8'h30 && uart_data<=8'h39);
 wire [23:0] candidate={acc[19:0],uart_data[3:0]};
 wire legal_time=(candidate[23:20]<=2) &&
                  (candidate[23:20]!=2 || candidate[19:16]<=3) &&
                  candidate[15:12]<=5 && candidate[7:4]<=5;
 assign busy=(digits!=0);
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   wait_count<=0;digits<=0;acc<=0;time_bcd<=0;time_seq<=0;time_set<=0;
   reply_valid<=0;reply_ok<=0;
  end else begin
   reply_valid<=0;
   if(uart_valid)begin
    wait_count<=0;
    if(!busy)begin
     if(uart_data=="T")begin digits<=1;acc<=0;end
    end else if(!digit)begin
     digits<=0;reply_valid<=1;reply_ok<=0;
    end else if(digits==6)begin
     digits<=0;reply_valid<=1;reply_ok<=legal_time;
     if(legal_time)begin time_bcd<=candidate;time_seq<=time_seq+1'b1;time_set<=1;end
    end else begin acc<=candidate;digits<=digits+1'b1;end
   end else if(busy)begin
    if(wait_count==TIMEOUT_CYCLES-1)begin
     digits<=0;wait_count<=0;reply_valid<=1;reply_ok<=0;
    end else wait_count<=wait_count+1'b1;
   end else wait_count<=0;
  end
 end
endmodule
