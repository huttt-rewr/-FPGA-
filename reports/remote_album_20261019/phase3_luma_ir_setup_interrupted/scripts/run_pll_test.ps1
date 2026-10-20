param([string]$ModelSim='J:\win64',[string]$TD='J:\Anlogic\td.6.2.1')
$ErrorActionPreference='Stop'
Push-Location (Join-Path (Split-Path $PSScriptRoot -Parent) 'sim')
try {
 New-Item -ItemType Directory -Force -Path ../reports | Out-Null
 if(!(Test-Path 'pll_work')) { & "$ModelSim\vlib.exe" pll_work }
 & "$ModelSim\vlog.exe" -work pll_work "$TD\sim_release\eg4\eg_logic_clk.v" "$TD\sim_release\eg4\eg_phy_pll.v" ../src/ip/pll/sys_pll.v ../src/ip/pll/video_pll.v tb_pll_clocks.v
 if($LASTEXITCODE -ne 0) { throw 'PLL compile failed' }
 & "$ModelSim\vsim.exe" -c -lib pll_work tb_pll_clocks -do 'run -all; quit -f' -l ../reports/tb_pll_clocks.log
 $log=Get-Content ../reports/tb_pll_clocks.log -Raw
 if($LASTEXITCODE -ne 0 -or $log -match '\*\* (Error|Fatal)' -or $log -notmatch 'ALL PASS tb_pll_clocks') { throw 'PLL simulation failed' }
} finally { Pop-Location }
