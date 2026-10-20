param([string]$ModelSim='J:\win64')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location (Join-Path $root 'sim')
try {
 New-Item -ItemType Directory -Force -Path '../reports/sd_native_20261016' | Out-Null
 & python ../scripts/make_fat32_image.py fixtures --out ../reports/fat32_20261015/vectors
 if($LASTEXITCODE -ne 0) { throw 'FAT32 fixture generation failed' }
 if(!(Test-Path 'sd_native_work')) {
  & "$ModelSim/vlib.exe" sd_native_work
  if($LASTEXITCODE -ne 0) { throw 'Cannot create native SD simulation library' }
 }
 & "$ModelSim/vlog.exe" -work sd_native_work +incdir+../src/modules/video '../src/modules/common/*.v' '../src/modules/control/*.v' '../src/modules/video/*.v' '../src/modules/audio/*.v' '../src/modules/osd/*.v' '../src/modules/bmp/*.v' '../src/modules/sd/*.v' '../src/modules/sd/native/*.v' sd_native_card_model.v tb_sd_native.v tb_sd_native_clock.v tb_sd_native_fat32.v tb_sd_native_player.v
 if($LASTEXITCODE -ne 0) { throw 'Native SD compile failed' }
 foreach($tb in @('tb_sd_native','tb_sd_native_clock','tb_sd_native_fat32','tb_sd_native_player')) {
  $log="../reports/sd_native_20261016/$tb.log"
  & "$ModelSim/vsim.exe" -c -lib sd_native_work $tb -do 'run -all; quit -f' -l $log
  $result=Get-Content $log -Raw
  if($LASTEXITCODE -ne 0 -or $result -match 'FAILED|\[FAIL\]|# FAIL |\*\* (Error|Fatal)' -or $result -notmatch 'ALL PASS') {
   throw "Native SD simulation failed: $tb. See $log"
  }
 }
 Write-Host 'ALL NATIVE SD TESTS PASSED (logical peer; not a hardware measurement)'
} finally { Pop-Location }
