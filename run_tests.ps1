param([string]$ModelSim='J:\win64')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location (Join-Path $root 'sim')
try {
 if(!(Test-Path 'msim_work')) { & "$ModelSim\vlib.exe" msim_work }
 $files=@('../rtl/common/*.v','../rtl/control/*.v','../rtl/osd/*.v','../rtl/video/*.v','../rtl/audio/*.v','../rtl/optional/*.v','../src/user_source/hdl_source/video_rgb_to_axis_640x480.v','tb_uart_rx.v','tb_ir_nec_rx.v','tb_video_scaler.v','tb_upgrade.v','tb_cdc.v')
 & "$ModelSim\vlog.exe" -work msim_work @files
 if($LASTEXITCODE -ne 0) { throw 'Verilog compilation failed' }
 foreach($tb in @('tb_uart_rx','tb_ir_nec_rx','tb_video_scaler','tb_upgrade','tb_cdc')) {
  $log="../reports/$tb.log"
  & "$ModelSim\vsim.exe" -c -lib msim_work $tb -do 'run -all; quit -f' -l $log
  $result=Get-Content $log -Raw
  if($LASTEXITCODE -ne 0 -or $result -match 'FAILED|\[FAIL\]|# FAIL |\*\* Error' -or $result -notmatch 'ALL PASS') {
   throw "Simulation failed: $tb. See $log"
  }
 }
 Write-Host 'ALL TESTS PASSED'
} finally { Pop-Location }
