// 扇区级仲裁：音频按需优先，授权后直到成功/失败才释放。
// 完成后留两个空拍，避免旧请求撤销前被重复授权。
module sd_read_arbiter #(parameter TIMEOUT_CYCLES=67108864)(
 input clk,rst,sd_ready,
 input bmp_req,input [31:0] bmp_addr,output [7:0] bmp_data,
 output bmp_valid,bmp_end,bmp_error,bmp_grant,
 input aud_req,input [31:0] aud_addr,output [7:0] aud_data,
 output aud_valid,aud_end,aud_error,
 output sd_req,output reg [31:0] sd_addr,
 input [7:0] sd_data,input sd_valid,sd_end,sd_error,
 output reg transport_reset);
 reg active,owner;
 reg [1:0] gap;
 localparam CW=(TIMEOUT_CYCLES<2)?1:$clog2(TIMEOUT_CYCLES);
 reg [CW-1:0] timer;
 reg timeout_due;
 // 提前一拍计算末值译码，下一拍与原计数到期时刻一致。
 // 客户端error/valid不再经过26bit计数比较的组合长路径。
 wire expired=active && timeout_due;
 wire failed=sd_error || expired || !sd_ready;
 assign sd_req=active && !failed;
 assign bmp_data=sd_data;assign aud_data=sd_data;
 assign bmp_grant=active && !owner;
 assign bmp_valid=active && !owner && sd_valid && !failed;
 assign aud_valid=active && owner && sd_valid && !failed;
 assign bmp_end=active && !owner && sd_end && !failed;
 assign aud_end=active && owner && sd_end && !failed;
 assign bmp_error=active && !owner && failed;
 assign aud_error=active && owner && failed;
 always @(posedge clk or posedge rst)begin
  if(rst)begin active<=0;owner<=0;gap<=0;timer<=0;timeout_due<=0;sd_addr<=0;transport_reset<=0;end
  else begin
   transport_reset<=0;
   if(active)begin
    if(sd_end || failed)begin
     active<=0;gap<=2;timer<=0;timeout_due<=0;
     if(expired)transport_reset<=1;
    end else if(sd_valid)begin timer<=0;timeout_due<=TIMEOUT_CYCLES==1;end
    else begin
     timer<=timer+1'b1;
     timeout_due<=(TIMEOUT_CYCLES==1) || (timer==TIMEOUT_CYCLES-2);
    end
   end else if(gap!=0)gap<=gap-1'b1;
   else if(sd_ready && (aud_req || bmp_req))begin
    active<=1;owner<=aud_req;sd_addr<=aud_req?aud_addr:bmp_addr;timer<=0;
    timeout_due<=TIMEOUT_CYCLES==1;
   end
  end
 end
endmodule
