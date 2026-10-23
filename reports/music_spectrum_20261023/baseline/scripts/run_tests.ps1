param([string]$ModelSim='J:\win64')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location (Join-Path $root 'sim')
try {
 New-Item -ItemType Directory -Force -Path '../reports' | Out-Null
 New-Item -ItemType Directory -Force -Path '../reports/effects_20261009' | Out-Null
 & python ../scripts/make_fat32_image.py fixtures --out ../reports/fat32_20261015/vectors
 if($LASTEXITCODE -ne 0) { throw 'FAT32 fixture generation/verification failed' }
 & python ../scripts/make_indexed_media.py
 if($LASTEXITCODE -ne 0) { throw 'Indexed media fixture generation failed' }
 & python ../scripts/test_prepare_video.py
 if($LASTEXITCODE -ne 0) { throw 'AVF conversion/packing tests failed' }
 & python ../scripts/test_zh_font.py
 if($LASTEXITCODE -ne 0) { throw 'Chinese menu font test failed' }
 if(!(Test-Path 'msim_work')) { & "$ModelSim\vlib.exe" msim_work; if($LASTEXITCODE -ne 0) { throw 'Cannot create simulation library' } }
 $files=@('../src/modules/common/*.v','../src/modules/control/*.v','../src/modules/osd/*.v','../src/modules/video/*.v','../src/modules/audio/*.v','../src/modules/optional/*.v','../src/modules/bmp/bmp_read.v','../src/modules/bmp/sd_card_bmp.v','../src/modules/sd/sd_card_top.v','../src/modules/sd/sd_card_sec_read_write.v','../src/modules/sd/sd_card_cmd.v','../src/modules/sd/spi_master.v','tb_uart_rx.v','tb_ir_nec_rx.v','tb_video_scaler.v','tb_upgrade.v','tb_cdc.v','tb_stream_queue.v','tb_uart_queue.v','tb_sd_address.v','tb_load_recovery.v','tb_bmp_stream.v','../src/modules/memory/frame_fifo_write.v','../src/ip/fifo/afifo_16_32_256.v','tb_fifo_boundary.v','tb_frame_writer.v','../src/modules/memory/frame_fifo_read.v','../src/modules/memory/frame_read_write.v','../src/ip/fifo/afifo_32_16_256.v','tb_frame_tail.v','tb_osd_text.v')
 $files += @('tb_bmp_headers.v','tb_hdmi_line_contract.v','tb_sd_watchdog.v')
 $files += @('tb_sd_crc.v','tb_read_drain.v','tb_memory_refresh.v')
 $files += @('../src/modules/sd/sd_read_arbiter.v','../src/modules/sd/sd_fat32.v')
 $mergeTests=@('tb_sd_waits','tb_edid_timeout','tb_bmp_stall','tb_commit_timeout','tb_write_backpressure')
 $mergeTests += @('tb_svga_writer','tb_svga_pipeline','tb_svga_memory','tb_edid_display_mode','tb_adaptive_raster','tb_scaled_svga','tb_svga_osd','tb_scaled_bmp','tb_picture_controls','tb_picture_adjust','tb_picture_osd','tb_switch_controls','tb_transition','tb_transition_pixels','tb_caption_overlay','tb_effects_pipeline')
 $mergeTests += @('tb_sd_crc','tb_read_drain','tb_memory_refresh')
 $mergeTests += @('tb_board_menu','tb_board_supervisor','tb_picture_gamma','tb_board_debug','tb_board_osd','tb_board_pipeline')
 $mergeTests += @('tb_audio_wav','tb_audio_fifo','tb_audio_playback','tb_sd_audio_arbiter','tb_audio_menu')
 $mergeTests += @('tb_audio_sd_integration')
 $mergeTests += @('tb_audio_osd')
 $mergeTests += @('tb_audio_retry','tb_audio_retry_edges','tb_audio_diagnostics')
 $mergeTests += @('tb_audio_effects','tb_audio_stream_flush','tb_audio_fifo_room')
 $mergeTests += @('tb_fat32_mount','tb_fat32_stream','tb_fat32_player')
 $files += @('../src/modules/sd/native/*.v','sd_native_card_model.v')
 $mergeTests += @('tb_sd_native','tb_sd_native_clock','tb_sd_native_fat32','tb_sd_native_player')
 $files += @('../src/modules/input/*.v')
 $mergeTests += @('tb_ps2_keyboard','tb_ps2_controls')
 $mergeTests += @('tb_fat32_indexed','tb_indexed_player','tb_file_osd')
 $mergeTests += @('tb_video_mode_control','tb_mode_reload','tb_mode_request_cdc')
 $mergeTests += @('tb_fps_control','tb_rate_player','tb_sd_native_integrated','tb_sd_highspeed','tb_sd_highspeed_player')
 $mergeTests += @('tb_caption_pipeline','tb_pixel_effects','tb_glass_osd','tb_audio_visualizer','tb_visual_pipeline','tb_shared_luma')
 $files += @('../src/modules/game/*.v')
 $mergeTests += @('tb_snake_game','tb_snake_controls','tb_snake_pipeline')
$mergeTests += @('tb_snake_bram')
 $mergeTests += @('tb_bram_window','tb_osd_bcd','tb_bram_waveform')
 $mergeTests += @('tb_scaler_row_address')
 $mergeTests += @('tb_fat32_compare')
 $mergeTests += @('tb_fps_equivalence')
 $mergeTests += @('tb_fat32_schedule')
 $mergeTests += @('tb_image_index_equivalence')
 $mergeTests += @('tb_audio_rx_boundary')
 $files += @('../src/modules/hdmi/tmds_encoder.v','../src/modules/hdmi/hdmi_tmds_vga.v','../src/modules/hdmi/edid_i2c.v')
 $mergeTests += @('tb_tmds_encoder','tb_hdmi_tmds_vga','tb_edid_i2c')
 $mergeTests += @('tb_transition_effects')
 $mergeTests += @('tb_remote_uart')
 $mergeTests += @('tb_remote_ir')
 $mergeTests += @('tb_auto_enhance')
 $mergeTests += @('tb_album_timer','tb_zh_overlay','tb_album_clock')
 $files += @('../src/modules/display/seg_scan.v')
 $mergeTests += @('tb_seg_scan_timing','tb_hdmi_video_stage')
 $mergeTests += @('tb_chinese_menu','tb_menu_overlay','tb_menu_popup','tb_menu_mode_popup','tb_menu_media','tb_menu_media_pixels')
 $files += @($mergeTests | ForEach-Object { "$_.v" })
 & "$ModelSim\vlog.exe" -work msim_work +incdir+../src/modules/video @files
 if($LASTEXITCODE -ne 0) { throw 'Verilog compilation failed' }
 foreach($tb in (@('tb_uart_rx','tb_ir_nec_rx','tb_video_scaler','tb_upgrade','tb_cdc','tb_stream_queue','tb_uart_queue','tb_sd_address','tb_load_recovery','tb_bmp_stream','tb_fifo_boundary','tb_frame_writer','tb_frame_tail','tb_osd_text','tb_bmp_headers','tb_hdmi_line_contract','tb_sd_watchdog') + $mergeTests)) {
  $log="../reports/$tb.log"
  & "$ModelSim\vsim.exe" -c -lib msim_work $tb -do 'run -all; quit -f' -l $log
  $result=Get-Content $log -Raw
  if($LASTEXITCODE -ne 0 -or $result -match 'FAILED|\[FAIL\]|# FAIL |\*\* Fatal' -or $result -notmatch 'ALL PASS') {
   throw "Simulation failed: $tb. See $log"
  }
 }
 Write-Host 'ALL TESTS PASSED'
} finally { Pop-Location }

