from pathlib import Path
import shutil
r=Path('E:/fpga');h=r/'reports/timing_close_20261018'
p=r/'sim/tb_fat32_compare.v';s=p.read_text(encoding='utf-8')
s=s.replace('// Execute CURSOR_APPLY too: it now prepares the range predicates without\n   // adding a state or cycle. Restore the chosen cluster boundary afterwards.', '// Execute the real CURSOR_APPLY state instead of forcing STREAM_CHECK.\n   // Restore the chosen cluster boundary after the cursor is applied.')
p.write_text(s,encoding='utf-8')
p=r/'src/modules/bmp/sd_card_bmp.v';shutil.copy2(p,h/'initial/sd_card_bmp.v')
s=p.read_text(encoding='utf-8')
a='''        // Compare the current index against the last entry in parallel with
        // incrementing it. Avoid an add -> compare -> select setup path.
        // Explicit zero handles the unsigned count-1 wrap at an empty table.
        next_index_limited=(count==0 || {1'b0,cur}>=count-7'd1)?6'd0:cur+6'd1;'''
b='''        // Unsigned count <= cur+1 is identical to count==0 || cur>=count-1.
        // Keep the addition seven bits wide: cur=63 needs the carry to 64.
        // This removes subtraction/zero-decode from the count launch path;
        // the six-bit selected increment still wraps exactly as before.
        next_index_limited=(count<=({1'b0,cur}+7'd1))?6'd0:cur+6'd1;'''
assert a in s;s=s.replace(a,b);p.write_text(s,encoding='utf-8')
p=r/'scripts/run_tests.ps1';s=p.read_text();a=" $mergeTests += @('tb_fat32_schedule')";assert a in s
s=s.replace(a,a+"\n $mergeTests += @('tb_image_index_equivalence')");p.write_text(s,encoding='utf-8')
