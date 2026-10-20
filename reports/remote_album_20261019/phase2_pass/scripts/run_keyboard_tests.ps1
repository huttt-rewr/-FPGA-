param([string]$ModelSim='J:\win64')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location (Join-Path $root 'sim')
try {
 New-Item -ItemType Directory -Force -Path '../reports/keyboard_20261016' | Out-Null
 if(!(Test-Path 'keyboard_work')) {
  & "$ModelSim/vlib.exe" keyboard_work
  if($LASTEXITCODE -ne 0){throw 'Cannot create keyboard simulation library'}
 }
 $files=@('../src/modules/input/*.v','../src/modules/control/picture_controls.v','tb_ps2_keyboard.v','tb_ps2_controls.v')
 & "$ModelSim/vlog.exe" -work keyboard_work @files
 if($LASTEXITCODE -ne 0){throw 'Keyboard compile failed'}
 foreach($tb in @('tb_ps2_keyboard','tb_ps2_controls')) {
  $log="../reports/keyboard_20261016/$tb.log"
  & "$ModelSim/vsim.exe" -c -lib keyboard_work $tb -do 'run -all; quit -f' -l $log
  $result=Get-Content $log -Raw
  if($LASTEXITCODE -ne 0 -or $result -match 'FAILED|\[FAIL\]|# FAIL |\*\* (Error|Fatal)' -or $result -notmatch 'ALL PASS') {
   throw "Keyboard simulation failed: $tb"
  }
 }
 Write-Host 'ALL KEYBOARD TESTS PASSED'
} finally { Pop-Location }
