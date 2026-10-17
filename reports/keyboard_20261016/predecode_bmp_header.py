"""Decode each BMP header byte in its input pipeline, without adding latency."""
from pathlib import Path
import re
R=Path(__file__).resolve().parents[2]
p=R/'src/modules/bmp/bmp_read.v'
s=p.read_text(encoding='utf-8')
a=s.index('reg header_byte_valid;');b=s.index('\nreg [7:0]  header_0;',a)
s=s[:a]+'''// One strobe per header byte, registered alongside its payload. Independent
// strobes prevent a wide case decoder/priority mux from reaching field CEs.
reg [33:0] header_select;
reg [7:0] header_byte;
integer header_decode;
always @(posedge clk or posedge rst) begin
    if(rst) begin header_select<=0;header_byte<=0;end
    else begin
        header_byte<=sd_sec_read_data;
        for(header_decode=0;header_decode<34;header_decode=header_decode+1)
            header_select[header_decode]<=!load_abort && sd_init_done &&
                sd_sec_read_data_valid && ((state==ST_SCAN)||(state==ST_LOAD_HDR)) &&
                (rd_cnt==header_decode);
    end
end
''' + s[b:]
a=s.index('    // header_byte/index/valid');b=s.index('\nalways @(posedge clk or posedge rst)',a)
old=s[a:b]
assignments=re.findall(r"10'd(\d+)\s*:\s*(\w+(?:\[[\d:]+\])?)\s*<= header_byte;",old)
assert len(assignments)==30,len(assignments)
s=s[:a]+'''    end else begin
        // Current abort still cancels an already-tagged byte.
'''+''.join(f'        if(header_select[{n}] && !load_abort) {field}<=header_byte;\n' for n,field in assignments)+'''    end
end
''' +s[b:]
p.write_text(s,encoding='utf-8')
print('Registered 30 independent field write strobes, same byte latency')
