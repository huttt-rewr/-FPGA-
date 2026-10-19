$ErrorActionPreference='Stop'
Push-Location E:/fpga/sim
try {
 & J:/win64/vlog.exe -work msim_work +incdir+../src/modules/video ../src/modules/video/bmp_scale_loader.v tb_scaler_row_address.v > ../reports/build_repair_20261018/taps_compile.log 2>&1
 if($LASTEXITCODE -ne 0){throw 'Compile failed'}
 foreach($tb in @('tb_scaler_row_address','tb_scaled_bmp','tb_scaled_svga','tb_visual_pipeline')) {
  $log="../reports/build_repair_20261018/taps_$tb.log"
  & J:/win64/vsim.exe -c -lib msim_work $tb -do 'run -all; quit -f' -l $log > "$log.console" 2>&1
  $code=$LASTEXITCODE
  $result=Get-Content $log -Raw
  if($code -ne 0 -or $result -match 'FAILED|\*\* (Error|Fatal)' -or $result -notmatch 'ALL PASS'){throw "Failed $tb"}
 }
} finally {Pop-Location}
& J:/Anlogic/td.6.2.1/bin/td_commands_prompt.exe scripts/synth.tcl > reports/build_repair_20261018/taps_synthesis.log 2>&1
if($LASTEXITCODE -ne 0){throw 'Synthesis failed'}
New-Item -ItemType Directory -Force reports/build_repair_20261018/taps | Out-Null
Copy-Item reports/gate_area.txt,reports/video_improve_gate.db,reports/build_repair_20261018/taps_synthesis.log reports/build_repair_20261018/taps/
python scripts/static_check.py
if($LASTEXITCODE -ne 0){throw 'Static failed'}
