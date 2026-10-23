from pathlib import Path
import shutil

R=Path(__file__).resolve().parents[2]
O=Path(__file__).resolve().parent
paths=['src/modules/control/picture_controls.v','src/modules/control/boot_media_select.v',
       'src/modules/osd/menu_overlay.v','src/modules/osd/zh_font_rom.v','src/modules/osd/zh_font.mem',
       'src/top.v','scripts/gen_zh_font.py','scripts/test_zh_font.py','scripts/run_tests.ps1',
       'sim/tb_menu_overlay.v','reports/build_manifest.json','reports/physical_area.txt','reports/timing_status.txt']
for p in paths:
 dst=O/'baseline'/p
 dst.parent.mkdir(parents=True,exist_ok=True)
 assert not dst.exists(), 'Already implemented'
 shutil.copy2(R/p,dst)

def edit(path, pairs):
 p=R/path;s=p.read_text(encoding='utf-8')
 for a,b in pairs:
  assert a in s,(path,a)
  s=s.replace(a,b,1)
 p.write_text(s,encoding='utf-8')

edit('src/modules/control/picture_controls.v',[
 ('parameter KEYBOARD_CONTROLS=0,', 'parameter MEDIA_MENU=0,parameter KEYBOARD_CONTROLS=0,'),
 ('ir_con_up,ir_con_dn);','ir_con_up,ir_con_dn,\n output reg menu_page,output reg image_next,movie_next,wav_next,res_down,res_up);'),
 ('&& menu_edit && pulse[1:0]==1;', '&& menu_edit && (!MEDIA_MENU || !menu_page) && pulse[1:0]==1;'),
 ('&& menu_edit && pulse[1:0]==2;', '&& menu_edit && (!MEDIA_MENU || !menu_page) && pulse[1:0]==2;'),
 ('next_pulse<=0;toggle_pulse<=0;brightness<=0;', 'menu_page<=0;image_next<=0;movie_next<=0;wav_next<=0;res_down<=0;res_up<=0;\n   next_pulse<=0;toggle_pulse<=0;brightness<=0;'),
 ('next_pulse<=0;toggle_pulse<=0;\n   if(BOARD_MENU', 'next_pulse<=0;toggle_pulse<=0;image_next<=0;movie_next<=0;wav_next<=0;res_down<=0;res_up<=0;\n   if(BOARD_MENU'),
 ('if(CHINESE_MENU)menu_item<=0;end','if(CHINESE_MENU)begin menu_item<=0;menu_page<=0;end end'),
 ('else if(menu_item==7)begin','else if(menu_item==7 && !menu_page)begin'),
 ('end else if(menu_edit)begin\n     if(submenu_toggle)',
  '''end else if(menu_edit)begin
     if(MEDIA_MENU && menu_page && (pulse[1:0]==1 || pulse[1:0]==2))begin
      case(menu_item)
       0:image_next<=1;
       1:movie_next<=1;
       2:wav_next<=1;
       3:begin res_down<=pulse[0];res_up<=pulse[1];end
      endcase
     end
     if(submenu_toggle)'''),
 ('if(pulse[1:0]==1)menu_item<=menu_item-1\'b1;\n     else if(pulse[1:0]==2)menu_item<=menu_item+1\'b1;',
  '''if(pulse[1:0]==1)begin
      if(MEDIA_MENU && menu_item==0)begin menu_page<=~menu_page;menu_item<=menu_page?7:3;end
      else menu_item<=menu_item-1'b1;
     end else if(pulse[1:0]==2)begin
      if(MEDIA_MENU && menu_item==(menu_page?3:7))begin menu_page<=~menu_page;menu_item<=0;end
      else menu_item<=menu_item+1'b1;
     end''')])

edit('scripts/gen_zh_font.py',[
 ("CHARS = ORIGINAL_CHARS + MENU_CHARS + SYMBOLS", "EXTRA_CHARS = '图片视频乐分辨率一张段首×'\nCHARS = ORIGINAL_CHARS + MENU_CHARS + SYMBOLS + EXTRA_CHARS"),
 ('len(CHARS) == 77','len(CHARS) == 90'),
 ('menu indices 32..76.', 'menu indices 32..89.'),
 ('mem[0:1231]', 'mem[0:1439]'),
 ('menu_words[0:719]', 'menu_words[0:927]'),
 ('16*8)', '16*9)'),
 ('range(77)', 'range(90)'),
 ('77 glyphs, 1232 words', '90 glyphs, 1440 words')])
edit('scripts/test_zh_font.py',[
 ('len(words), 1232','len(words), 1440'),('range(1232)','range(1440)'),('len(font.CHARS),77','len(font.CHARS),90')])
edit('sim/tb_menu_overlay.v',[('words[0:1231]','words[0:1439]')])

edit('src/modules/osd/menu_overlay.v',[
 ('parameter POPUP_SECONDS=2)', 'parameter POPUP_SECONDS=2,parameter MEDIA_MENU=0)'),
 ('input mode_800);','input mode_800,input menu_page,input [1:0] requested_resolution,input movie_mode);'),
 ('reg [2:0] selected;', 'reg [2:0] selected;\n reg page_q,movie_q;reg [1:0] resolution_q;'),
 ('vol_tens<=0;vol_units<=0;contrast_q<=4;popup_visible<=0;', 'vol_tens<=0;vol_units<=0;contrast_q<=4;popup_visible<=0;page_q<=0;movie_q<=0;resolution_q<=1;'),
 ('opened<=menu_open;selected<=menu_item;editing<=edit_mode;', 'opened<=menu_open;selected<=menu_item;editing<=edit_mode;\n    page_q<=MEDIA_MENU && menu_page;movie_q<=movie_mode;resolution_q<=requested_resolution;'),
 ('case(item)\n    0:case(col)0:label_char=34;',
  '''if(page_q)begin
    case(item)
     0:case(col)0:label_char=77;1:label_char=78;endcase
     1:case(col)0:label_char=79;1:label_char=80;endcase
     2:case(col)0:label_char=44;1:label_char=81;endcase
     3:case(col)0:label_char=82;1:label_char=83;2:label_char=84;endcase
    endcase
   end else case(item)
    0:case(col)0:label_char=34;'''),
 ('case(item)\n    0:case(col)0:value_char=playing?',
  '''if(page_q)begin
    if(item<3)case(col)
     0:value_char=58;1:value_char=85;
     2:value_char=(item==0)?86:((item==1)?87:88);
    endcase
    else if(item==3)begin
     if(movie_q || resolution_q!=2 || !mode_800)begin
      case(col)0:value_char=69;1:value_char=67;2:value_char=63;3:value_char=89;
       4:value_char=67;5:value_char=71;6:value_char=63;endcase
     end else begin
      case(col)0:value_char=71;1:value_char=63;2:value_char=63;3:value_char=89;
       4:value_char=69;5:value_char=63;6:value_char=63;endcase
     end
    end
   end else case(item)
    0:case(col)0:value_char=playing?'''),
 ('if(y>=88+k*40 && y<120+k*40)begin','if((!page_q || k<4) && y>=88+k*40 && y<120+k*40)begin'),
 ('selected_band=1;selected_text=1;\n     char_idx=',
  '''selected_band=1;selected_text=1;
     // Seven resolution glyphs fit at normal size inside the 128px panel.
     if(page_q && selected==3 && y>=144)begin
      column=local_x[3:0];glyph_row=local_y[4:1];cell_col=local_x[7:4];
     end
     char_idx='''),
 ('if(x>=8 && x<104 && ((y>=88', 'if(x>=8 && x<(page_q && selected==3?120:104) && ((y>=88'),
 ('char_idx=local_x[4]?7\'d33:7\'d32;','char_idx=local_x[4]?7\'d33:7\'d32;'),
 ('if(!editing)begin', '''if(MEDIA_MENU && x>=88 && x<104 && y>=40 && y<56)begin
    local_x=x-88;local_y=y-40;glyph_row=local_y[3:0];column=local_x[3:0];
    char_idx=page_q?65:64;
   end
   if(!editing)begin''')])

# Keep the selected mode outside supervisor resets: a media restart must not
# allow stale persistent keyboard/button requests to override the latest menu.
p=R/'src/modules/control/boot_media_select.v'
p.write_text(p.read_text()+'''
// Last explicit request wins. Button levels are synchronized into the SD domain;
// a keyboard make is an event even if the old selection latch has the same value.
module menu_media_request(
 input clk,rst_n,controls_reset,movie_mode,
 input keyboard_event,keyboard_movie,button_valid,button_movie,
 input image_next,movie_next,wav_next,
 output reg select_valid,select_movie,output reg next_picture,next_movie,next_wav);
 (* async_reg="true" *) reg [1:0] bv_ff,bm_ff;
 reg old_valid,old_movie;
 wire button_event=bv_ff[1] && (!old_valid || bm_ff[1]!=old_movie);
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   bv_ff<=0;bm_ff<=0;old_valid<=0;old_movie<=0;
   select_valid<=0;select_movie<=1;next_picture<=0;next_movie<=0;next_wav<=0;
  end else begin
   bv_ff<={bv_ff[0],button_valid};bm_ff<={bm_ff[0],button_movie};
   old_valid<=bv_ff[1];old_movie<=bm_ff[1];
   next_picture<=0;next_movie<=0;next_wav<=0;
   if(button_event)begin select_valid<=1;select_movie<=bm_ff[1];end
   if(!controls_reset)begin
    if(keyboard_event)begin select_valid<=1;select_movie<=keyboard_movie;end
    if(image_next || movie_next || wav_next)begin
     select_valid<=1;select_movie<=movie_next;
     // Cross-type selection restarts at the first file. Same-type selection
     // advances through the existing FAT32 image/movie/WAV request paths.
     next_picture<=image_next && !movie_mode;
     next_movie<=movie_next && movie_mode;
     next_wav<=wav_next && !movie_mode;
    end
   end
  end
 end
endmodule
''',encoding='utf-8')

edit('src/top.v',[
 ('wire [2:0] menu_item;', '''wire [2:0] menu_item;
wire menu_page,menu_image_next,menu_movie_next,menu_wav_next,menu_res_down,menu_res_up;
wire menu_next_picture,menu_next_movie,menu_next_wav;
wire menu_media_valid,menu_media_movie;
wire [4:0] menu_navigation_video;'''),
 ('generate if(AVF_ENABLED)begin: avf_selection', '''menu_media_request menu_requests(.clk(sd_card_clk),.rst_n(boot_select_rst_n),
 .controls_reset(rst_controls),.movie_mode(movie_sd),
 .keyboard_event(kb_valid && !kb_release && !kb_extended && !kb_error && (kb_scan_code==8'h4d || kb_scan_code==8'h2a)),
 .keyboard_movie(kb_scan_code==8'h2a),.button_valid(button_select_valid),.button_movie(button_select_movie),
 .image_next(menu_image_next),.movie_next(menu_movie_next),.wav_next(menu_wav_next),
 .select_valid(menu_media_valid),.select_movie(menu_media_movie),
 .next_picture(menu_next_picture),.next_movie(menu_next_movie),.next_wav(menu_next_wav));
generate if(AVF_ENABLED)begin: avf_selection'''),
 ('.select_valid(media_select_valid || button_select_valid),\n .select_movie(button_select_valid?button_select_movie:media_select_movie),',
  '.select_valid(menu_media_valid),.select_movie(menu_media_movie),'),
 ('assign movie_mode=0;assign media_restart_request=0;', 'assign movie_mode=0;assign media_restart_request=0;\n assign button_select_valid=0;assign button_select_movie=0;'),
 ('assign cmd_next=board_next || kb_next || pc_next || slide_next;',
  'assign cmd_next=board_next || kb_next || pc_next || slide_next ||\n (!rst_sd && !status_busy && ((menu_next_picture && !movie_sd && media_image_count!=0) ||\n (menu_next_movie && movie_sd && movie_count!=0)));'),
 ('media_audio_select<=kb_audio_select;', 'media_audio_select<=kb_audio_select || (menu_next_wav && !rst_sd && !movie_sd && bmp_audio_count!=0 && !status_busy);'),
 ('if(kb_audio_select)audio_index<={4\'d0,kb_digit};', '''if(kb_audio_select)audio_index<={4'd0,kb_digit};
  else if(menu_next_wav && !rst_sd && !movie_sd && bmp_audio_count!=0 && !status_busy)
   audio_index<=(bmp_audio_index+1'b1>=bmp_audio_count)?8'd0:{1'b0,bmp_audio_index}+1'b1;'''),
 ("if(kb_res)res_mode<=(res_mode==2)?0:res_mode+1'b1;", '''if(kb_res)res_mode<=(res_mode==2)?0:res_mode+1'b1;
  else if(!movie_sd && (menu_res_down || menu_res_up))res_mode<=(res_mode==2)?1:2;'''),
 ('.CHINESE_MENU(1)) buttons', '.CHINESE_MENU(1),.MEDIA_MENU(1)) buttons'),
 ('.menu_open(menu_open),.menu_item(menu_item),.menu_edit(menu_edit),',
  '.menu_open(menu_open),.menu_item(menu_item),.menu_edit(menu_edit),\n .menu_page(menu_page),.image_next(menu_image_next),.movie_next(menu_movie_next),.wav_next(menu_wav_next),\n .res_down(menu_res_down),.res_up(menu_res_up),'),
 ('menu_overlay chinese_menu(', '''cdc_snapshot #(.WIDTH(5)) menu_navigation_cdc(.src_clk(sd_card_clk),.src_rst(rst_controls),
 .src_data({menu_page,menu_item,menu_edit}),.dst_clk(video_clk),.dst_rst(rst_video),.dst_data(menu_navigation_video));
menu_overlay #(.MEDIA_MENU(1)) chinese_menu('''),
 ('.menu_open(frame_ui[0]),.menu_item(frame_ui[3:1]),', '.menu_open(frame_ui[0]),.menu_item(menu_navigation_video[3:1]),'),
 ('.edit_mode(menu_edit_video),', '.edit_mode(menu_navigation_video[0]),.menu_page(menu_navigation_video[4]),\n .requested_resolution(frame_rate[6:5]),.movie_mode(movie_video),')])
edit('scripts/run_tests.ps1',[("'tb_chinese_menu','tb_menu_overlay','tb_menu_popup'", "'tb_chinese_menu','tb_menu_overlay','tb_menu_popup','tb_menu_media','tb_menu_media_pixels'")])
print('Implemented menu extension; run font generator and compile next')
