param([string]$ModelSim='J:\win64')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location (Join-Path $root 'sim')
try {
 if(!(Test-Path 'msim_work')) { & "$ModelSim\vlib.exe" msim_work }
 & "$ModelSim\vlog.exe" -work msim_work ../src/modules/common/reset_sync.v ../src/modules/audio/*.v ../src/modules/sd/sd_read_arbiter.v ../src/modules/control/picture_controls.v tb_audio_wav.v tb_audio_fifo.v tb_audio_playback.v tb_sd_audio_arbiter.v tb_audio_menu.v
 if($LASTEXITCODE -ne 0){ throw 'Audio compilation failed' }
 foreach($tb in @('tb_audio_wav','tb_audio_fifo','tb_audio_playback','tb_sd_audio_arbiter','tb_audio_menu')) {
  $log="../reports/$tb.log"
  & "$ModelSim\vsim.exe" -c -lib msim_work $tb -do 'run -all; quit -f' -l $log
  $result=Get-Content $log -Raw
  if($LASTEXITCODE -ne 0 -or $result -match 'FAILED|\[FAIL\]|# FAIL |\*\* (Error|Fatal)' -or $result -notmatch 'ALL PASS'){throw "Audio simulation failed: $tb"}
 }
 Write-Host 'ALL AUDIO TESTS PASSED'
} finally { Pop-Location }
