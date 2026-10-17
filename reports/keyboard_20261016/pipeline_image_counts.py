from pathlib import Path
R=Path(__file__).resolve().parents[2]
p=R/'src/modules/bmp/sd_card_bmp.v';s=p.read_text(encoding='utf-8')
needle='wire auto_tick;'
assert needle in s
s=s.replace(needle,'''// Counts settle before media requests. Predecode them outside the priority
// load/commit mux so a 7-bit count is not on every frame-control enable path.
reg images_present,images_multiple;
always @(posedge clk or posedge rst)begin
 if(rst)begin images_present<=0;images_multiple<=0;end
 else begin images_present<=(img_found_count!=0);images_multiple<=(img_found_count>1);end
end
wire auto_tick;''')
for old,new in [('(img_found_count > 3\'d0)','images_present'),
 ('(img_found_count != 3\'d0)','images_present'),
 ('(img_found_count > 3\'d1)','images_multiple'),
 ('&& img_found_count!=0','&& images_present')]:s=s.replace(old,new)
p.write_text(s,encoding='utf-8')
p=R/'src/top.v';s=p.read_text(encoding='utf-8')
s=s.replace('wire media_truncated;','wire media_truncated;wire player_display_valid;')
s=s.replace('.status_busy(status_busy),.status_error(status_error),',
 '.status_busy(status_busy),.status_error(status_error),.display_valid(player_display_valid),')
s=s.replace('if(!rst_sd && media_image_count!=0 && !status_busy',
 'if(!rst_sd && player_display_valid && media_image_count!=0 && !status_busy')
p.write_text(s,encoding='utf-8')
p=R/'sim/tb_mode_reload.v';s=p.read_text(encoding='utf-8')
s=s.replace(' task select_image;',''' // Mirror top's selected-index feedback; a remount must not overwrite the
 // saved request with the player's reset index before its first commit.
 always @(posedge clk)if(!rst && shown && ic!=0 && !busy && !image_valid)
  image<=ii;
 task select_image;''')
s=s.replace('select_image(3);complete_image(3);','''select_image(3);complete_image(3);
  @(negedge clk);next_cmd=1;@(negedge clk);next_cmd=0;complete_image(4);
  check(image==4,"arrow-selected index fed back before mode restart");''')
s=s.replace('check(ii==3 &&','check(ii==4 &&')
p.write_text(s,encoding='utf-8')
print('Pipelined image-count predicates; preserved selected image until real first commit; expanded reload regression')
