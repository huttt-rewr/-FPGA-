param([string]$ModelSim='J:\win64')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
 python scripts/prepare_refresh_test.py
 if($LASTEXITCODE -ne 0) { throw 'Cannot extract public refresh counter' }
 & "$ModelSim\vlog.exe" -work sim/msim_work +incdir+src/ip/sdram reports/display_fix_20261013/sdr_init_ref_public_test.v sim/tb_sdram_refresh.v
 if($LASTEXITCODE -ne 0) { throw 'Refresh test compilation failed' }
 & "$ModelSim\vsim.exe" -c -lib sim/msim_work tb_sdram_refresh -do 'run -all; quit -f' -l reports/display_fix_20261013/refresh_after.log
 if($LASTEXITCODE -ne 0 -or (Get-Content reports/display_fix_20261013/refresh_after.log -Raw) -notmatch 'ALL PASS') {
  throw 'Refresh test failed'
 }
 Write-Host 'ALL PASS public refresh counter test'
} finally { Pop-Location }
