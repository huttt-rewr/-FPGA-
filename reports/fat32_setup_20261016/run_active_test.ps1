$ErrorActionPreference='Stop'
Push-Location (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
try {
 & python reports/fat32_setup_20261016/make_active_test.py
 if($LASTEXITCODE -ne 0) { throw 'Active-FAT test generation failed' }
 $work='reports/fat32_setup_20261016/active_work'
 if(!(Test-Path $work)) { & J:/win64/vlib.exe $work }
 & J:/win64/vlog.exe -work $work src/modules/sd/sd_fat32.v src/modules/sd/sd_read_arbiter.v reports/fat32_setup_20261016/tb_active_fat.v
 if($LASTEXITCODE -ne 0) { throw 'Active-FAT compile failed' }
 Push-Location sim
 try {
  $log='../reports/fat32_setup_20261016/active_fat.log'
  & J:/win64/vsim.exe -c -lib "../$work" tb_active_fat -do 'run -all; quit -f' -l $log
  $text=Get-Content $log -Raw
  if($LASTEXITCODE -ne 0 -or $text -match 'FAILED|\*\* (Error|Fatal)' -or $text -notmatch 'ALL PASS') { throw 'Active-FAT test failed' }
 } finally { Pop-Location }
} finally { Pop-Location }
