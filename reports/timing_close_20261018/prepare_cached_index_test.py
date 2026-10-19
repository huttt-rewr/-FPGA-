from pathlib import Path
r=Path('E:/fpga');h=r/'reports/timing_close_20261018'
s=(r/'sim/tb_image_index_equivalence.v').read_text()
s=s.replace(' integer cur,count,errors=0,checks=0;',' integer cur,count,back,errors=0,checks=0;\n reg [5:0] probe_index=0;reg [6:0] probe_count=0;reg probe_back=0;')
a=s.index('  // Call the real production function.');b=s.index('  if(errors==0)',a)
s=s[:a]+'''  force dut.img_found_count=probe_count;force dut.img_idx=probe_index;
  force dut.prev_requested=probe_back;
  force dut.sd_init_done=1'b0;
  repeat(3)@(negedge clk);rst=0;
  // Count settling uses the same cycle as the existing images_present guard.
  // Exercise both directions through the production output, including count
  // transitions each iteration, zero and all declared out-of-range patterns.
  for(count=0;count<128;count=count+1)begin
   for(cur=0;cur<64;cur=cur+1)begin
    for(back=0;back<2;back=back+1)begin
     @(negedge clk);probe_count=count;probe_index=cur;probe_back=back;
     @(posedge clk);#1;
     if(back)expected=(cur==0)?((count-1)&63):cur-1;
     else expected=(count==0 || cur>=count-1)?6'd0:cur+1;
     if(dut.next_from_current!==expected)begin
      errors=errors+1;
      if(errors<10)$display("FAILED cached image index cur=%0d count=%0d back=%0d got=%0d want=%0d",cur,count,back,dut.next_from_current,expected);
     end
     if(dut.images_present!==(count!=0) || dut.last_image_index!==((count-1)&127))begin
      errors=errors+1;$display("FAILED cached count/guard alignment");
     end
     checks=checks+1;
    end
   end
  end
  @(negedge clk);rst=1;#1;
  if(dut.images_present!==0 || dut.last_image_index!==7'h7f)errors=errors+1;
''' + s[b:]
s=s.replace('exhaustive production-function cases, zero count, max index, carry and out-of-range counts','exhaustive production next/previous cases, cached count/guard alignment, zero/max/out-of-range and reset')
(h/'image_index_registered_test.v').write_text(s,encoding='ascii')
