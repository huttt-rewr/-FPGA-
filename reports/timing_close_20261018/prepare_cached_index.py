from pathlib import Path
r=Path('E:/fpga');h=r/'reports/timing_close_20261018'
s=(h/'initial/sd_card_bmp.v').read_text(encoding='utf-8')
s=s.replace('reg images_present,images_multiple;','reg images_present,images_multiple;\nreg [6:0] last_image_index;')
a=''' if(rst)begin images_present<=0;images_multiple<=0;end
 else begin images_present<=(img_found_count!=0);images_multiple<=(img_found_count>1);end'''
b=''' if(rst)begin images_present<=0;images_multiple<=0;last_image_index<=7'h7f;end
 else begin
  images_present<=(img_found_count!=0);images_multiple<=(img_found_count>1);
  // Mount/scan count settles before the existing images_present launch guard.
  // Prepare the last entry alongside that guard, outside the load priority mux.
  last_image_index<=img_found_count-7'd1;
 end'''
assert a in s;s=s.replace(a,b)
s=s.replace('img_found_count[5:0] - 6\'d1','last_image_index[5:0]')
s=s.replace('next_index_limited(img_idx, img_found_count);', "((!images_present || {1'b0,img_idx}>=last_image_index)?6'd0:img_idx+6'd1);")
a=s.index('function [5:0] next_index_limited;');b=s.index('endfunction',a)+len('endfunction')
s=s[:a]+s[b:]
(h/'image_index_registered_candidate.v').write_text(s,encoding='utf-8')
print('Prepared isolated registered-index candidate outside build inputs')
