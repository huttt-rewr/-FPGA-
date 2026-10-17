"""Prepare independent wide file-count OSD extension, legacy profile unchanged."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
s=(ROOT/'src/modules/osd/status_osd.v').read_text(encoding='utf-8')
s=s.replace('parameter AUDIO_DIAGNOSTICS=0)', 'parameter AUDIO_DIAGNOSTICS=0,parameter FILE_UI=0)')
s=s.replace('input audio_underflow);','''input audio_underflow,
    input [6:0] file_image_index,file_image_count,file_audio_index,file_audio_count,
    input file_table_truncated);''')
assert 'file_table_truncated' in s
s=s.replace('    reg [319:0] menu_text;', '''    // Metadata decimal conversion stays off the per-pixel font lookup path.
    reg [7:0] it,iu,ct,cu,at,au,nt,nu;
    wire [6:0] image_number=(file_image_count==0)?7'd0:file_image_index+7'd1;
    wire [6:0] audio_number=(file_audio_count==0)?7'd0:file_audio_index+7'd1;
    always @(posedge clk or posedge rst)begin
        if(rst)begin it<=48;iu<=48;ct<=48;cu<=48;at<=48;au<=48;nt<=48;nu<=48;end
        else begin
            it<=48+image_number/10;iu<=48+image_number%10;
            ct<=48+file_image_count/10;cu<=48+file_image_count%10;
            at<=48+audio_number/10;au<=48+audio_number%10;
            nt<=48+file_audio_count/10;nu<=48+file_audio_count%10;
        end
    end
    reg [319:0] menu_text;''')
line='PLAY:OFF IMG:00/00 AUD:00/00 LOAD:-'.ljust(40)
assert len(line)==40
print({c:[i for i,v in enumerate(line) if v==c] for c in ('0','-')})
needle='        if(BOARD_UI)begin'
s=s.replace(needle,'''        if(FILE_UI && row==1)begin
            menu_text="'''+line+'''";
            board_ascii=(col<40)?(menu_text >> ((39-col)*8)):8'h20;
            case(col)
                5:board_ascii="O";6:board_ascii=auto_play?"N":"F";7:board_ascii=auto_play?" ":"F";
                13:board_ascii=it;14:board_ascii=iu;16:board_ascii=ct;17:board_ascii=cu;
                23:board_ascii=at;24:board_ascii=au;26:board_ascii=nt;27:board_ascii=nu;
                34:board_ascii=error?"E":(busy?"B":"-");
                39:board_ascii=file_table_truncated?"T":" ";
            endcase
        end
'''+needle)
(ROOT/'reports/keyboard_20261016/stage2/status_osd.v').write_text(s,encoding='utf-8')
