from pathlib import Path
R=Path(__file__).resolve().parents[2]
p=R/'src/modules/video/bmp_scale_loader.v';s=p.read_text(encoding='utf-8')
assert 'read_x<=x0;fx<=x_acc[15:8];fy<=y_acc[15:8];' in s
s=s.replace('read_x<=x0;fx<=x_acc[15:8];fy<=y_acc[15:8];', 'read_x<=x0;')
s=s.replace('   done<=0;error<=0;\n', '''   done<=0;error<=0;
   // Coordinates do not advance until SEND accepts this pixel. Weight
   // samples therefore settle before either lerp consumes them; no large
   // inside-image/state clock-enable tree is needed for these eight-bit data.
   fx<=x_acc[15:8];fy<=y_acc[15:8];
''')
p.write_text(s,encoding='utf-8')
print('Removed redundant weight enables without adding any pixel or SD wait cycle')
