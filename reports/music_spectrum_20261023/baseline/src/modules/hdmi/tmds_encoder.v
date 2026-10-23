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
        reg [1:0] pair0,pair1,pair2,pair3;
        reg [2:0] half0,half1;
        begin
            pair0={1'b0,value[0]}+{1'b0,value[1]};
            pair1={1'b0,value[2]}+{1'b0,value[3]};
            pair2={1'b0,value[4]}+{1'b0,value[5]};
            pair3={1'b0,value[6]}+{1'b0,value[7]};
            half0={1'b0,pair0}+{1'b0,pair1};
            half1={1'b0,pair2}+{1'b0,pair3};
            count_ones={1'b0,half0}+{1'b0,half1};
        end
    endfunction
    assign data_ones=count_ones(data);
    assign use_xnor=(data_ones>4 || (data_ones==4 && !data[0]));
    assign qm[0]=data[0];
    genvar bit_number;
    generate for(bit_number=1;bit_number<8;bit_number=bit_number+1)begin: minimize
        // The recurrence is prefix parity; XNOR contributes on odd indices.
        assign qm[bit_number]=(^data[bit_number:0])^
                                   ((bit_number%2)?use_xnor:1'b0);
    end endgenerate
    assign qm[8]=!use_xnor;
    assign qm_ones=count_ones(qm[7:0]);
    assign balance=$signed({1'b0,qm_ones,1'b0})-6'sd8;
    wire invert=(disparity==0 || balance==0) ? !qm[8] :
                (disparity[5]==balance[5]);
    wire signed [5:0] delta_keep=balance-(qm[8]?6'sd0:6'sd2);
    wire signed [5:0] delta_invert=(qm[8]?6'sd2:6'sd0)-balance;
    wire signed [5:0] delta=invert?delta_invert:delta_keep;
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
        end else begin
            symbol<={invert,qm[8],(qm[7:0]^{8{invert}})};
            disparity<=disparity+delta;
        end
    end
endmodule
