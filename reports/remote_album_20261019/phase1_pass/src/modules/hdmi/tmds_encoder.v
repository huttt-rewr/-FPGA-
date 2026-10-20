// DVI 1.0 section 3.2: transition minimization, then DC balancing.
// Parallel symbols only. The existing PHY serializes bit zero first.
// This is TMDS coding, not the unrelated IBM 8b/10b code table.
module tmds_encoder(
    input clk, input rst, input de,
    input [1:0] control, input [7:0] data,
    output reg [9:0] symbol
);
    wire [8:0] qm;
    wire [3:0] data_ones, qm_ones;
    wire use_xnor;
    reg signed [5:0] disparity;
    wire signed [5:0] balance;
    function [3:0] count_ones;
        input [7:0] value;
        integer i;
        begin count_ones=0;for(i=0;i<8;i=i+1)count_ones=count_ones+value[i];end
    endfunction
    assign data_ones=count_ones(data);
    assign use_xnor=(data_ones>4 || (data_ones==4 && !data[0]));
    assign qm[0]=data[0];
    genvar bit_number;
    generate for(bit_number=1;bit_number<8;bit_number=bit_number+1)begin: minimize
        assign qm[bit_number]=qm[bit_number-1]^data[bit_number]^use_xnor;
    end endgenerate
    assign qm[8]=!use_xnor;
    assign qm_ones=count_ones(qm[7:0]);
    assign balance=$signed({1'b0,qm_ones,1'b0})-6'sd8;
    always @(posedge clk or posedge rst) begin
        if(rst) begin symbol<=10'b1101010100; disparity<=0; end
        else if(!de) begin
            disparity<=0;
            case(control)
                2'b00:symbol<=10'b1101010100;
                2'b01:symbol<=10'b0010101011;
                2'b10:symbol<=10'b0101010100;
                2'b11:symbol<=10'b1010101011;
            endcase
        end else if(disparity==0 || balance==0) begin
            symbol<={~qm[8],qm[8],(qm[8]?qm[7:0]:~qm[7:0])};
            disparity<=disparity+(qm[8]?balance:-balance);
        end else if((disparity>0 && balance>0) || (disparity<0 && balance<0)) begin
            symbol<={1'b1,qm[8],~qm[7:0]};
            disparity<=disparity+(qm[8]?6'sd2:6'sd0)-balance;
        end else begin
            symbol<={1'b0,qm[8],qm[7:0]};
            disparity<=disparity+balance-(qm[8]?6'sd0:6'sd2);
        end
    end
endmodule
