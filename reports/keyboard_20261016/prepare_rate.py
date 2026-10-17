"""Prepare stage-four consumers outside the formal source tree."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).resolve().parent
s=(ROOT/'src/modules/bmp/sd_card_bmp.v').read_text(encoding='utf-8')
s=s.replace('parameter integer INDEXED=0,', 'parameter integer RATE_CONTROLS=0,parameter integer INDEXED=0,')
s=s.replace('    output media_truncated\n', '    output media_truncated,\n    input [3:0] fps_mode,output rate_limited\n')
s=s.replace('wire auto_tick;', '''wire auto_tick,rate_tick;
generate if(RATE_CONTROLS)begin:rate_control
 fps_control #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) timer(.clk(clk),.rst(rst),
 .enable(scan_done && auto_play_en && display_valid && first_image_committed && images_multiple),
 .busy(load_busy || !bmp_ready || next_req_pending),.mode(fps_mode),
 .tick(rate_tick),.limited(rate_limited),.requested_fps());
end else begin:legacy_rate
 assign rate_tick=0;assign rate_limited=0;
end endgenerate''')
s=s.replace('assign auto_tick  = (auto_cnt == (CLK_FREQ_HZ - 1));', 'assign auto_tick  = RATE_CONTROLS?rate_tick:(auto_cnt == (CLK_FREQ_HZ - 1));')
s=s.replace('if (scan_done && auto_play_en && display_valid && !load_busy && first_image_committed', 'if (!RATE_CONTROLS && scan_done && auto_play_en && display_valid && !load_busy && first_image_committed')
(OUT/'sd_card_bmp_rate.v').write_text(s,encoding='utf-8')
s=(OUT/'top_mode_candidate.v').read_text(encoding='utf-8')
s=s.replace('wire media_truncated;', 'wire media_truncated,rate_limited;wire [6:0] rate_video;reg [6:0] frame_rate;')
s=s.replace('frame_media<=0;', 'frame_media<=0;frame_rate<=0;')
s=s.replace('frame_media<=media_video;', 'frame_media<=media_video;frame_rate<=rate_video;')
s=s.replace('.INDEXED(1),.MAX_FILES(64),','.INDEXED(1),.MAX_FILES(64),.RATE_CONTROLS(1),')
s=s.replace('.media_truncated(media_truncated),','.media_truncated(media_truncated),.fps_mode(fps_mode),.rate_limited(rate_limited),')
s=s.replace('// Independent bus: historical', '''cdc_snapshot #(.WIDTH(7)) rate_cdc(.src_clk(sd_card_clk),.src_rst(rst_controls),
 .src_data({res_mode,rate_limited,fps_mode}),.dst_clk(video_clk),.dst_rst(rst_video),.dst_data(rate_video));
// Independent bus: historical''')
s=s.replace('.FILE_UI(1)) osd(','.FILE_UI(1),.RATE_UI(1)) osd(')
s=s.replace('.file_table_truncated(frame_media[28]));','.file_table_truncated(frame_media[28]),.slide_rate_mode(frame_rate[3:0]),.slide_rate_limited(frame_rate[4]),.requested_res_mode(frame_rate[6:5]));')
s=s.replace('.stream_rst(audio_fx_reset),', '.stream_rst(audio_fx_reset || video_mute || video_volume==0),')
(OUT/'top_rate_candidate.v').write_text(s,encoding='utf-8')
s=(ROOT/'src/modules/osd/status_osd.v').read_text(encoding='utf-8')
s=s.replace('parameter FILE_UI=0)', 'parameter FILE_UI=0,parameter RATE_UI=0)')
s=s.replace('input file_table_truncated);', 'input file_table_truncated,input [3:0] slide_rate_mode,input slide_rate_limited,input [1:0] requested_res_mode);')
s=s.replace('    reg [319:0] menu_text;', '''    function [15:0] rate_digits;
        input [3:0] rate_mode;
        begin case(rate_mode)
            1:rate_digits="02";2:rate_digits="05";3:rate_digits="10";
            4:rate_digits="15";5:rate_digits="30";default:rate_digits="01";
        endcase end
    endfunction
    wire [15:0] rate_chars=rate_digits(slide_rate_mode);
    wire [7:0] rate_tens=rate_chars[15:8],rate_units=rate_chars[7:0];
    reg [319:0] menu_text;''')
s=s.replace('        if(BOARD_UI)begin', '''        if(RATE_UI && row==0 && col>=24)begin
            case(col)
                24:board_ascii="T";25:board_ascii="A";26:board_ascii="R";27:board_ascii="G";
                28:board_ascii="E";29:board_ascii="T";30:board_ascii=":";
                31:board_ascii=rate_tens;32:board_ascii=rate_units;
                33:board_ascii=slide_rate_limited?"L":" ";
                35:board_ascii="R";36:board_ascii=":";37:board_ascii="0"+requested_res_mode;
                default:board_ascii=" ";
            endcase
        end
        if(BOARD_UI)begin''')
(OUT/'status_osd_rate.v').write_text(s,encoding='utf-8')
print('Prepared rate timer consumer, independent CDC and explicit TARGET/L OSD')
