// 48kHz PCM test tone in pixel domain, not decoded media audio.
// At 25MHz pixel clock, HDMI N=6144 CTS=25000.
module audio_test_source #(parameter CLK_HZ=25000000,parameter SAMPLE_HZ=48000)(
    input clk,input rst,input [4:0] volume,input mute,
    output reg valid,output reg [23:0] left_pcm,output reg [23:0] right_pcm);
    reg [31:0] acc,phase;
    wire [32:0] sum={1'b0,acc}+SAMPLE_HZ;
    wire signed [23:0] amp=$signed({2'b00,volume,17'd0});
    always @(posedge clk or posedge rst) begin
        if(rst) begin acc<=0;phase<=0;valid<=0;left_pcm<=0;right_pcm<=0;end
        else begin
            valid<=0;
            if(sum>=CLK_HZ) begin
                acc<=sum-CLK_HZ;phase<=phase+32'd39370534;valid<=1;
                left_pcm<=mute ? 24'd0 : (phase[31] ? amp : -amp);
                right_pcm<=mute ? 24'd0 : (phase[31] ? amp : -amp);
            end else acc<=sum[31:0];
        end
    end
endmodule
