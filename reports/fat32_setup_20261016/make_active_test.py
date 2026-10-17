"""Reuse the real-image SD fixture, requiring FAT2 when BPB selects it."""
from pathlib import Path

root=Path(__file__).resolve().parents[2]
out=Path(__file__).resolve().parent
fixture=(root/'sim/tb_fat32_mount.v').read_text(encoding='utf-8').split('\nmodule tb_fat32_mount;',1)[0]
fixture=fixture.replace('module fat32_fixture(', 'module fat32_active_fixture(')
marker='seek_result=$fseek(fd,addr*512,0);got=$fread(sector,fd);'
assert fixture.count(marker)==1
fixture=fixture.replace(marker,marker+'''
    // ExtFlags: mirroring disabled, active FAT index 1. Primary FAT reads forbidden.
    if(addr==0)sector[40]=8'h81;
    if(addr>=32 && addr<545)begin $display("FAILED active FAT: primary FAT read");$finish;end
''')
tb=(root/'sim/tb_fat32_stream.v').read_text(encoding='utf-8').split(' initial begin',1)[0]
tb=tb.replace('module tb_fat32_stream;', 'module tb_active_fat;')
tb=tb.replace('fat32_fixture card(', 'fat32_active_fixture card(')
tb+='''
 initial begin
  reset_card(0);
  check(count==4 && found,"active FAT root enumeration");
  for(which=0;which<5;which=which+1)begin
   file_idx=which;load_expected(which);
   for(j=0;j<(expected_size+511)/512;j=j+1)sector_read(which==4,j,0);
  end
  if(errors==0)$display("ALL PASS active_fat: FAT2-only root and five fragmented files, exact Python bytes");
  else $display("FAILED active_fat errors=%0d",errors);
  $finish;
 end
 initial begin #10000000;$display("FAILED active FAT watchdog");$finish;end
endmodule
'''
(out/'tb_active_fat.v').write_text(fixture+'\n'+tb,encoding='utf-8')
print('Generated active-FAT reference test without modifying sim sources')
