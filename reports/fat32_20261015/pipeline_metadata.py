from pathlib import Path

p = Path(__file__).resolve().parents[2]/'src/modules/sd/sd_fat32.v'
s = p.read_text(encoding='utf-8')
a = s.index('   if(meta_valid)begin')
b = s.index('   case(state)', a)
s = (s[:a] + s[a:b].replace('disk_data', 'meta_data')
     .replace('byte_count', 'meta_index').replace('state==DIR_RX', 'meta_dir') + s[b:])
p.write_text(s, encoding='utf-8')
