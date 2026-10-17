from pathlib import Path
import re

p = Path(__file__).resolve().parents[2]/'src/modules/sd/sd_fat32.v'
s = p.read_text(encoding='utf-8')
constants = dict(re.findall(r'\b(\w+)=40\x27h([0-9a-fA-F]+)', s))
a = s.index('   case(state)')
head, body = s[:a], s[a:]
body = body.replace('case(state)', "case(1'b1) // synthesis parallel_case", 1)
for name, value in constants.items():
    n = int(value, 16)
    assert n and n & (n-1) == 0
    body = re.sub(r'^(\s*)'+name+r':', r'\g<1>state['+str(n.bit_length()-1)+']:', body, flags=re.M)
p.write_text(head+body, encoding='utf-8')
print('Converted', len(constants), 'one-hot branches to direct parallel bit selection')
