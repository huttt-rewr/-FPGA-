@echo off
rem 一键生成 bit：综合 + 布局布线 + 时序检查 + bitgen。
rem 为什么用这个而不是 TD 图形界面：本设计 LUT 80.6%%/DSP 79%% 贴着芯片容量，
rem GUI 的"默认综合策略"会综合出 4974 MSlice（超过器件 4900 上限）导致布局失败；
rem 命令行脚本用"面积优先 + 高打包"把 LUT 压到 15794 才装得下。双击本文件即可。
setlocal
cd /d "%~dp0"

echo ============================================
echo  [1/2] 综合 + 布局布线 + 时序检查（约 5-10 分钟）
echo ============================================
python scripts\run_build.py
if errorlevel 1 (
  echo.
  echo  [失败] 综合/布线/时序未通过，bit 未生成。
  echo         查看 reports\timing_status.txt 里的 SWNS/STNS/HWNS/HTNS。
  echo         若 SWNS 为负：说明 100MHz SD 域时序又顶到边了，需先解决再生成。
  pause
  exit /b 1
)

echo.
echo ============================================
echo  [2/2] 生成 bit
echo ============================================
J:\Anlogic\td.6.2.1\bin\td_commands_prompt.exe scripts\bitgen_after_sta.tcl
if errorlevel 1 (
  echo.
  echo  [失败] bitgen 未通过（bitgen 会拒绝生成时序为负的 bit）。
  pause
  exit /b 1
)

echo.
echo ============================================
echo  [成功] bit 已生成： reports\video_improve.bit
echo         用 TD 的"下载/烧录"工具加载该文件即可上板。
echo ============================================
pause
