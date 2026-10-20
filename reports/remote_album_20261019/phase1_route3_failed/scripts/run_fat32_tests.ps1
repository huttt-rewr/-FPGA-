param([string]$ModelSim='J:\win64')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
 & python scripts/make_fat32_image.py fixtures
 if($LASTEXITCODE -ne 0) { throw 'FAT32 fixture self-check failed' }
 New-Item -ItemType Directory -Force -Path 'reports/fat32_20261015' | Out-Null
 $work='reports/fat32_20261015/msim_work'
 if(!(Test-Path $work)) { & "$ModelSim/vlib.exe" $work }
 $files=@('src/modules/common/*.v','src/modules/control/*.v','src/modules/video/*.v',
  'src/modules/audio/*.v','src/modules/osd/*.v','src/modules/sd/*.v',
  'src/modules/bmp/*.v','sim/tb_fat32_mount.v','sim/tb_fat32_stream.v','sim/tb_fat32_player.v')
 & "$ModelSim/vlog.exe" -work $work +incdir+src/modules/video @files
 if($LASTEXITCODE -ne 0) { throw 'FAT32 compile failed' }
 Push-Location sim
 try {
  foreach($tb in @('tb_fat32_mount','tb_fat32_stream','tb_fat32_player')) {
   $log="../reports/fat32_20261015/$tb.log"
   & "$ModelSim/vsim.exe" -c -lib "../$work" $tb -do 'run -all; quit -f' -l $log
   $result=Get-Content $log -Raw
   if($LASTEXITCODE -ne 0 -or $result -match 'FAILED|\*\* (Error|Fatal)' -or $result -notmatch 'ALL PASS') {
    throw "FAT32 simulation failed: $tb"
   }
  }
 } finally { Pop-Location }
 Write-Host 'ALL FAT32 TESTS PASSED'
} finally { Pop-Location }
