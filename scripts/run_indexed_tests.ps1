param([string]$ModelSim='J:\win64')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location (Join-Path $root 'sim')
try {
 & python ../scripts/make_indexed_media.py
 if($LASTEXITCODE -ne 0){throw 'Indexed media generation failed'}
 if(!(Test-Path indexed_work)) { & "$ModelSim/vlib.exe" indexed_work }
 $files=@('../src/modules/common/*.v','../src/modules/control/*.v','../src/modules/video/*.v',
 '../src/modules/audio/*.v','../src/modules/osd/*.v','../src/modules/sd/*.v','../src/modules/bmp/*.v',
 'tb_fat32_indexed.v','tb_indexed_player.v','tb_file_osd.v')
 & "$ModelSim/vlog.exe" -work indexed_work +incdir+../src/modules/video @files
 if($LASTEXITCODE -ne 0){throw 'Indexed compilation failed'}
 foreach($tb in @('tb_fat32_indexed','tb_indexed_player','tb_file_osd')) {
  $log="../reports/keyboard_20261016/stage2/$tb.log"
  & "$ModelSim/vsim.exe" -c -lib indexed_work $tb -do 'run -all; quit -f' -l $log
  $result=Get-Content $log -Raw
  if($LASTEXITCODE -ne 0 -or $result -match 'FAILED|# FAIL |\*\* (Error|Fatal)' -or $result -notmatch 'ALL PASS') {
   throw "Indexed simulation failed: $tb"
  }
 }
 Write-Host 'ALL INDEXED TESTS PASSED'
} finally {Pop-Location}
