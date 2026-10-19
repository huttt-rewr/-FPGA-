// Runs on the EXISTING fixed 25 MHz EDID boot clock, not the switched pixel clock.
// Never reset this supervisor with its own reset_request (no feedback latch).
module board_supervisor #(
 parameter POWER_CYCLES=250000,parameter TIMEOUT_CYCLES=50000000
)(input clk,input arst,input enable,input heartbeat_toggle,
 output reg reset_request,output reg [7:0] watchdog_resets);
 localparam PW=(POWER_CYCLES<2)?1:$clog2(POWER_CYCLES);
 localparam TW=(TIMEOUT_CYCLES<2)?1:$clog2(TIMEOUT_CYCLES);
 reg [PW-1:0] power_count;
 reg [TW-1:0] elapsed;
 (* async_reg="true" *) reg [2:0] heartbeat_sync;
 reg last_heartbeat;
 // 高有效复位直接由寄存器输出，异步立即置位、保持期结束同步撤销。
 // 避免ready取反和复位OR级联进入各域同步器的recovery路径。
 always @(posedge clk or posedge arst)begin
  if(arst)begin
   power_count<=0;elapsed<=0;reset_request<=1;heartbeat_sync<=0;
   last_heartbeat<=0;watchdog_resets<=0;
  end else begin
   heartbeat_sync<={heartbeat_sync[1:0],heartbeat_toggle};
   last_heartbeat<=heartbeat_sync[2];
   if(reset_request)begin
    elapsed<=0;
    if(power_count==POWER_CYCLES-1)begin reset_request<=0;power_count<=0;end
    else power_count<=power_count+1'b1;
   end else if(!enable || heartbeat_sync[2]!=last_heartbeat)elapsed<=0;
   else if(elapsed==TIMEOUT_CYCLES-1)begin
    // A fresh 10 ms hold follows the timeout; the supervisor itself keeps running.
    reset_request<=1;power_count<=0;elapsed<=0;
    if(watchdog_resets!=255)watchdog_resets<=watchdog_resets+1'b1;
   end else elapsed<=elapsed+1'b1;
  end
 end
endmodule
