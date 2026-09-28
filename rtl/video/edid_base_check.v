// First 128-byte EDID block header/checksum diagnostics, not mode negotiation.
module edid_base_check(input clk,input rst,input start,input valid,input [7:0] data,
    output reg done,output reg good);
    reg [7:0] count,sum;reg header_ok;
    wire [7:0] expected=(count==0 || count==7)?8'h00:8'hff;
    wire [7:0] sum_next=sum+data;
    always @(posedge clk or posedge rst) begin
        if(rst) begin count<=0;sum<=0;done<=0;good<=0;header_ok<=1;end
        else if(start) begin count<=0;sum<=0;done<=0;good<=0;header_ok<=1;end
        else if(valid && !done) begin
            sum<=sum_next;count<=count+1'b1;
            if(count<8 && data!=expected) header_ok<=0;
            if(count==127) begin done<=1;good<=header_ok && sum_next==0;end
        end
    end
endmodule
