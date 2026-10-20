// HX4S20C SW pins from official DEMO/6_cnt10: C8,C7,C6,C5.
// Default: switch closed to GND is ON. Adjust ON_LEVEL only if board wiring differs.
// Debounce the entire word so a mode is accepted only after all contacts settle.
module switch_controls #(parameter DEBOUNCE_CYCLES=2000000,
                         parameter [3:0] ON_LEVEL=4'b0000)(
    input clk,input rst,input [3:0] sw,
    output captions_enable,output scroll_enable,
    output [1:0] transition_mode);
    (* async_reg="true" *) reg [3:0] sw_meta,sw_sync;
    reg [3:0] candidate,stable;
    localparam CW=(DEBOUNCE_CYCLES<2)?1:$clog2(DEBOUNCE_CYCLES);
    reg [CW-1:0] count;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            sw_meta<=~ON_LEVEL;sw_sync<=~ON_LEVEL;
            candidate<=~ON_LEVEL;stable<=~ON_LEVEL;count<=0;
        end else begin
            sw_meta<=sw;sw_sync<=sw_meta;
            if(sw_sync!=candidate) begin candidate<=sw_sync;count<=0;end
            else if(count==DEBOUNCE_CYCLES-1) stable<=candidate;
            else count<=count+1'b1;
        end
    end
    wire [3:0] enabled=~(stable ^ ON_LEVEL);
    assign captions_enable=enabled[0];
    assign scroll_enable=enabled[1];
    assign transition_mode=enabled[3:2];
endmodule
