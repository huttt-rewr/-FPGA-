from pathlib import Path
import re
R=Path(__file__).resolve().parents[2]
p=R/'src/modules/sd/sd_fat32.v';s=p.read_text(encoding='utf-8')
s=s.replace('localparam [47:0] WAIT_INIT', 'localparam [48:0] WAIT_INIT')
s=s.replace("FAT_PROBE=48'h800000000000;", "FAT_PROBE=48'h800000000000,CURSOR_APPLY=49'h1000000000000;")
s=s.replace('reg [47:0] state;', 'reg [48:0] state;\n reg cursor_reusable;')
s=s.replace('cache_hit<=0;state<=WAIT_INIT;', 'cursor_reusable<=0;cache_hit<=0;state<=WAIT_INIT;')
old='''     if(cursor_valid[owner] && (cursor_file[owner]==request_file) && cursor_index[owner]<=target_index)begin'''
assert old in s
s=s.replace(old,'''     cursor_reusable<=cursor_valid[owner] && (cursor_file[owner]==request_file) && cursor_index[owner]<=target_index;
     state<=CURSOR_APPLY;
    end
    state[48]:begin
     if(cursor_reusable)begin''')
p.write_text(s,encoding='utf-8')
p=R/'src/modules/sd/sd_card_cmd.v';s=p.read_text(encoding='utf-8')
states=re.findall(r"parameter\s+(S_\w+)\s*=\s*18'h([0-9A-Fa-f]+)",s)
for name,value in states:
 bit=int(value,16).bit_length()-1
 s=re.sub(r'\bstate\s*==\s*'+name+r'\b',f'state[{bit}]',s)
p.write_text(s,encoding='utf-8')
print('Split cursor compare/apply; directly decoded legal onehot command state outputs without handshake delay')
