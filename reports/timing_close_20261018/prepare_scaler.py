from pathlib import Path
import shutil
r=Path('E:/fpga');h=r/'reports/timing_close_20261018'
shutil.copy2(r/'sim/tb_fat32_schedule.v',h/'build3/tb_fat32_schedule.v')
shutil.copy2(h/'initial/sd_fat32.v',r/'src/modules/sd/sd_fat32.v')
p=r/'src/modules/video/bmp_scale_loader.v';s=p.read_text(encoding='utf-8')
a='wire [23:0] upper_row=y0[0]?horizontal1:horizontal0;';assert a in s
s=s.replace(a,'''// ROW captures both taps before cache reads and all interpolation waits.
 // They stay fixed until SEND accepts the final pixel of this output row.
 // Use those stable taps instead of repeating y_acc -> clamp -> compare
 // on the pixel output path; the Q8 weights and rounding remain unchanged.
 wire [23:0] upper_row=row_y0[0]?horizontal1:horizontal0;''')
s=s.replace('wire [23:0] lower_row=y0[0]?horizontal0:horizontal1;','wire [23:0] lower_row=row_y0[0]?horizontal0:horizontal1;')
a='if(y0==y1)pixel<=y0[0]?horizontal1:horizontal0;';assert a in s
s=s.replace(a,'if(row_y0==row_y1)pixel<=upper_row;')
p.write_text(s,encoding='utf-8')
print('Restored FAT32 baseline; isolated registered-row scaler selection')
