// 单写单读异步FIFO；格雷指针双拍同步。RAM不复位，只有有效指针可读。
// 公共异步复位在两个域分别同步释放，错误流可整队列清空。
module audio_async_fifo #(parameter ADDRESS_BITS=10)(
 input wr_clk,rd_clk,rst,input wr_en,input [23:0] wr_data,output full,
 input rd_en,output reg [23:0] rd_data,output empty,
 output [ADDRESS_BITS:0] wr_used,rd_used);
 localparam P=ADDRESS_BITS+1;
 reg [23:0] memory[0:(1<<ADDRESS_BITS)-1];
 reg [P-1:0] wb,rb,wg,rg;
 (* async_reg="true" *) reg [P-1:0] rgs0,rgs1,wgs0,wgs1;
 wire wr_rst,rd_rst;
 reset_sync wreset(.clk(wr_clk),.arst(rst),.rst(wr_rst));
 reset_sync rreset(.clk(rd_clk),.arst(rst),.rst(rd_rst));
 function [P-1:0] binary;
  input [P-1:0] gray;integer k;
  begin binary[P-1]=gray[P-1];for(k=P-2;k>=0;k=k-1)binary[k]=binary[k+1]^gray[k];end
 endfunction
 assign full=wr_rst || (wg=={~rgs1[P-1:P-2],rgs1[P-3:0]});
 assign empty=rd_rst || (rg==wgs1);
 assign wr_used=wb-binary(rgs1);assign rd_used=binary(wgs1)-rb;
 wire [P-1:0] wn=wb+1'b1,rn=rb+1'b1;
 always @(posedge wr_clk)if(wr_en && !full)memory[wb[ADDRESS_BITS-1:0]]<=wr_data;
 always @(posedge rd_clk)if(rd_en && !empty)rd_data<=memory[rb[ADDRESS_BITS-1:0]];
 always @(posedge wr_clk or posedge wr_rst)begin
  if(wr_rst)begin wb<=0;wg<=0;rgs0<=0;rgs1<=0;end
  else begin rgs0<=rg;rgs1<=rgs0;if(wr_en && !full)begin wb<=wn;wg<=(wn>>1)^wn;end end
 end
 always @(posedge rd_clk or posedge rd_rst)begin
  if(rd_rst)begin rb<=0;rg<=0;wgs0<=0;wgs1<=0;end
  else begin wgs0<=wg;wgs1<=wgs0;if(rd_en && !empty)begin rb<=rn;rg<=(rn>>1)^rn;end end
 end
endmodule
