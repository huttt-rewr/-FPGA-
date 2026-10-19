from pathlib import Path
p=Path('reports/timing_close_20261018/prepare_guard_partition.py');s=p.read_text(encoding='utf-8-sig')
s=s.replace("assert 'reg stream_bad;' in s;s=s.replace('reg stream_bad;', '''reg [5:0] stream_bad_parts;", "assert 'reg cluster_ok,cluster_eoc,cluster_self,stream_bad,fat_rx_bad;' in s;s=s.replace('reg cluster_ok,cluster_eoc,cluster_self,stream_bad,fat_rx_bad;', '''reg cluster_ok,cluster_eoc,cluster_self,fat_rx_bad;\n reg [5:0] stream_bad_parts;")
p.write_text(s,encoding='utf-8')
