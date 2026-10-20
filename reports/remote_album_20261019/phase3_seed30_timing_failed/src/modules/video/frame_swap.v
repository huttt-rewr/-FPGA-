// Source owns both buffers until ack. Only vblank changes frame/animation state.
// ENABLE_EFFECTS=0 retains the original single-vblank handshake for other users.
module frame_swap #(parameter ENABLE_EFFECTS=0,parameter ADAPTIVE=0)(input clk,input rst,input vblank,input request_toggle,
    input [1:0] requested_buffer,output reg ack_toggle,
    output reg [1:0] active_buffer,output reg display_valid,
    input [1:0] transition_mode,output reg [2:0] effect_mode,
    output reg [5:0] fade_level,output reg [9:0] slide_offset,
    output wire transition_busy,input mode_800);
    wire [9:0] slide_step=(ADAPTIVE && mode_800)?25:20;
    (* async_reg="true" *) reg [2:0] req_ff;
    (* async_reg="true" *) reg [1:0] buf_ff1,buf_ff2;
    localparam IDLE=2'd0,OUT=2'd1,SWITCH=2'd2,IN=2'd3;
    reg [1:0] state,pending_buffer;
    reg pending_toggle;
    // Slot 3 cycles fade, slide, wipe, iris, checker. Captured once per request.
    reg [2:0] rotation_effect;
    assign transition_busy=(state!=IDLE);
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            req_ff<=0;buf_ff1<=0;buf_ff2<=0;
            ack_toggle<=0;active_buffer<=0;display_valid<=0;
            state<=IDLE;pending_buffer<=0;pending_toggle<=0;
            effect_mode<=0;fade_level<=32;slide_offset<=0;
            rotation_effect<=3'd1;
        end else begin
            req_ff<={req_ff[1:0],request_toggle};
            buf_ff1<=requested_buffer;buf_ff2<=buf_ff1;
            if(vblank) begin
                case(state)
                    IDLE: if(req_ff[2]!=ack_toggle) begin
                        if(!ENABLE_EFFECTS || !display_valid || transition_mode==0) begin
                            active_buffer<=buf_ff2;display_valid<=1;ack_toggle<=req_ff[2];
                            effect_mode<=0;fade_level<=32;slide_offset<=0;
                        end else begin
                            // Capture mode, payload and transaction identity once.
                            pending_buffer<=buf_ff2;pending_toggle<=req_ff[2];
                            effect_mode<=(transition_mode==3)?rotation_effect:{1'b0,transition_mode};
                            if(transition_mode==3)
                                rotation_effect<=(rotation_effect==5)?3'd1:rotation_effect+1'b1;
                            state<=OUT;
                            fade_level<=31;slide_offset<=slide_step;
                        end
                    end
                    OUT: begin
                        fade_level<=fade_level-1'b1;slide_offset<=slide_offset+slide_step;
                        if(fade_level==1) state<=SWITCH;
                    end
                    SWITCH: begin
                        // One completely covered frame on the new buffer before reveal.
                        active_buffer<=pending_buffer;state<=IN;
                    end
                    IN: begin
                        fade_level<=fade_level+1'b1;slide_offset<=slide_offset-slide_step;
                        if(fade_level==31) begin
                            state<=IDLE;ack_toggle<=pending_toggle;
                            effect_mode<=0;
                        end
                    end
                    default: state<=IDLE;
                endcase
            end
        end
    end
endmodule
