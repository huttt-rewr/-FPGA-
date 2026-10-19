from pathlib import Path
import shutil
r=Path('E:/fpga'); h=r/'reports/timing_close_20261018'
p=r/'src/modules/sd/sd_fat32.v'
s=(h/'initial/sd_fat32.v').read_text(encoding='utf-8')
a='     target_index<=relative_shifted;\n     state<=STREAM_LIMIT;'
b='''     target_index<=relative_shifted;
     // Preselect the owner cursor while the target shift is registered.
     // STREAM_LIMIT then compares two registers, without an array mux in
     // series. CURSOR_APPLY still commits exactly the original cursor/zero.
     working_index<=cursor_index[owner];
     state<=STREAM_LIMIT;'''
assert s.count(a)==1;s=s.replace(a,b)
a='cursor_index[owner]<=target_index;';assert s.count(a)==1
s=s.replace(a,'working_index<=target_index;');p.write_text(s,encoding='utf-8')
p=r/'sim/tb_fat32_schedule.v';s=p.read_text(encoding='utf-8')
shutil.copy2(p,h/'build2/tb_fat32_schedule.v')
s=s.replace('dut.state=dut.STREAM_LIMIT;reference.state=reference.STREAM_LIMIT;','dut.state=dut.STREAM_INIT;reference.state=reference.STREAM_INIT;')
s=s.replace('dut.request_size=size_bytes;reference.request_size=size_bytes;','dut.legacy_files.legacy_wav_size=size_bytes;reference.legacy_files.legacy_wav_size=size_bytes;\n   dut.image_size[1]=size_bytes;reference.image_size[1]=size_bytes;\n   dut.spc_shift=0;reference.spc_shift=0;')
s=s.replace('   step; // limit -> apply','''   step; // init -> limit: cursor is preselected only in the candidate
   @(negedge clk);
   dut.target_index=target;reference.target_index=target;
   step; // limit -> apply''')
s=s.replace('   step; // apply -> check; sector comparison partials become available here','   step; // apply -> check: working_index must again match the original')
a='''   if({dut.state,dut.working_cluster,dut.working_index,dut.request_sectors,br,ar,be,ae,berr,aerr}!==
      {reference.state,reference.working_cluster,reference.working_index,reference.request_sectors,rbr,rar,rbe,rae,rberr,raerr})begin'''
b='''   if({dut.state,dut.working_cluster,dut.request_sectors,br,ar,be,ae,berr,aerr}!==
      {reference.state,reference.working_cluster,reference.request_sectors,rbr,rar,rbe,rae,rberr,raerr} ||
      (!(dut.state==dut.STREAM_LIMIT || dut.state==dut.CURSOR_APPLY) &&
       dut.working_index!==reference.working_index))begin'''
assert a in s;s=s.replace(a,b)
s=s.replace('   run_request(0,0,0,0,0,i);','''   run_request(0,0,0,0,0,i);
   run_request(4096,0,24'h00ffff,24'h010000,32'hffffffff,i);
   run_request(4096,0,24'h010000,24'h00ffff,32'hffffffff,i);
   run_request(4096,0,24'h800000,24'h7fffff,32'hffffffff,i);''')
p.write_text(s,encoding='utf-8')
print('Installed isolated cursor preselection; baseline sector range logic restored')
