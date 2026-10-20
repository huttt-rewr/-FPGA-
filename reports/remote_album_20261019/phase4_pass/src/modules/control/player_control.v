// Commands in SD clock domain. Lowercase ASCII, one byte per command.
module player_control #(parameter PC_COMMANDS=0)(input clk,input rst,input [7:0] uart_data,input uart_valid,
    input [7:0] ir_command,input ir_valid,
    output reg next_pulse,output reg prev_pulse,output reg toggle_pulse,
    output reg [4:0] volume,output reg mute,output reg osd_enable,
    output reg signed [7:0] brightness,output reg test_pattern,
    output reg reply_valid,output reg [7:0] reply,
    output reg [1:0] transition_mode,output reg captions_enable,
    output reg scroll_enable,output reg [1:0] slogan_select,output reg auto_enh_en,output reg slide_enable,zh_enable,large_clock);
    reg [7:0] cmd;
    always @* begin
        cmd=uart_valid ? uart_data : 0;
        if(!uart_valid && ir_valid) begin
            case(ir_command)
                8'h15:cmd=PC_COMMANDS?"p":"b";8'h40:cmd="n";8'h44:cmd=PC_COMMANDS?"b":"p";
                8'h46:cmd="+";8'h16:cmd="-";8'h45:cmd="m";8'h47:cmd="o";
                default:cmd=0;
            endcase
        end
    end
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            next_pulse<=0;prev_pulse<=0;toggle_pulse<=0;
            volume<=8;mute<=1;osd_enable<=1;brightness<=0;test_pattern<=0;
            reply_valid<=0;reply<=0;
            transition_mode<=1;captions_enable<=1;scroll_enable<=1;slogan_select<=0;auto_enh_en<=0;slide_enable<=0;zh_enable<=0;large_clock<=0;
        end else begin
            next_pulse<=0;prev_pulse<=0;toggle_pulse<=0;reply_valid<=0;
            if(uart_valid || ir_valid) begin
                reply_valid<=uart_valid;reply<="K";
                case(cmd)
                    "a":auto_enh_en<=~auto_enh_en;
                    "s":slide_enable<=~slide_enable;
                    "h":zh_enable<=~zh_enable;
                    "l":large_clock<=~large_clock;
                    "n":next_pulse<=1;
                    "b":if(PC_COMMANDS)toggle_pulse<=1;else prev_pulse<=1;
                    "p":if(PC_COMMANDS)prev_pulse<=1;else toggle_pulse<=1;
                    "+":if(volume<16) volume<=volume+1'b1;
                    "-":if(volume>0) volume<=volume-1'b1;
                    "m":mute<=~mute;
                    "o":osd_enable<=~osd_enable;
                    "]":if(brightness<64) brightness<=brightness+8'sd8;
                    "[":if(brightness> -64) brightness<=brightness-8'sd8;
                    "t":test_pattern<=~test_pattern;
                    "e":transition_mode<=(transition_mode==2)?0:transition_mode+1'b1;
                    "c":captions_enable<=~captions_enable;
                    "r":scroll_enable<=~scroll_enable;
                    "g":slogan_select<=(slogan_select==2)?0:slogan_select+1'b1;
                    default:reply<="?";
                endcase
            end
        end
    end
endmodule
