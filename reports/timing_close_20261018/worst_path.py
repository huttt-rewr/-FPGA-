from pathlib import Path
s=Path('reports/routed_timing_paths20.txt').read_text()
a=s.index('Slack               : -1.284ns');b=s.index('End of Path',a) if 'End of Path' in s[a:] else a+19000
print(s[a:min(b,a+19000)])
