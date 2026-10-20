param([string]$ModelSim='J:\win64')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
 if(!(Test-Path sim/msim_work)) { & "$ModelSim\vlib.exe" sim/msim_work }
 $sources=@('src/modules/common/*.v','src/modules/control/*.v','src/modules/video/*.v','src/modules/osd/*.v')
 $tests=@('tb_board_menu','tb_board_supervisor','tb_picture_gamma','tb_board_debug','tb_board_osd','tb_board_pipeline')
 $sources+=@($tests | ForEach-Object { "sim/$_.v" })
 & "$ModelSim\vlog.exe" -work sim/msim_work +incdir+src/modules/video @sources
 if($LASTEXITCODE -ne 0) { throw 'Board test compilation failed' }
 foreach($test in $tests) {
  $log="reports/$test.log"
  & "$ModelSim\vsim.exe" -c -lib sim/msim_work $test -do 'run -all; quit -f' -l $log
  if($LASTEXITCODE -ne 0) { throw "Failed $test" }
  $result=Get-Content $log -Raw
  if($result -match 'FAILED|\[FAIL\]|# FAIL |\*\* (Error|Fatal)' -or $result -notmatch 'ALL PASS') { throw "Assertions failed $test" }
 }
 Write-Host 'ALL BOARD TESTS PASSED'
} finally { Pop-Location }
