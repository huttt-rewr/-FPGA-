#!/usr/bin/env bash
# Run the unmodified F-drive contracts from their fixture-relative directory.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root/legacy/f_drive_video_reference/sim"
modelsim=${MODELSIM_BIN:-/mnt/j/win64}
mkdir -p ../reports/av_test
if [[ ! -f video_work/_info ]]; then "$modelsim/vlib.exe" video_work; fi
"$modelsim/vlog.exe" -work video_work +incdir+../../../src/modules/video+../../.. \
  ../../../src/modules/common/*.v ../../../src/modules/control/*.v \
  ../../../src/modules/osd/*.v ../../../src/modules/video/*.v \
  ../../../src/modules/audio/*.v ../../../src/modules/bmp/*.v \
  ../../../src/modules/sd/*.v ../../../src/modules/sd/native/*.v \
  ../../../src/modules/memory/*.v ../../../src/ip/fifo/*.v \
  ../../../src/modules/input/*.v ../../../sim/sd_native_card_model.v \
  tb_av_sync.v tb_av_controls.v tb_av_phase.v tb_av_fast_scaler.v \
  tb_av_faults.v tb_sd_av.v tb_av_memory.v tb_boot_media_select.v \
  tb_media_mode_switch.v tb_fat32_movie.v
run_case() {
  local tb=$1 tag=$2
  shift 2
  local log="../reports/av_test/$tag.log" code=0
  "$modelsim/vsim.exe" -c -lib video_work "$tb" "$@" \
    -do 'run -all; quit -f' -l "$log" || code=$?
  if [[ $code -ne 0 ]] || grep -Eq 'FAILED|\*\* Fatal' "$log" || \
     ! grep -q "ALL PASS $tb" "$log"; then
    echo "FAILED $tag (exit=$code): $log"
    return 1
  fi
  grep "ALL PASS $tb" "$log"
}
if [[ $# -gt 0 ]]; then
  for tb in "$@"; do run_case "$tb" "$tb"; done
else
  for tb in tb_av_sync tb_av_controls tb_av_phase tb_av_fast_scaler \
    tb_av_faults tb_sd_av tb_av_memory tb_boot_media_select \
    tb_media_mode_switch tb_fat32_movie; do
    run_case "$tb" "$tb"
  done
  run_case tb_av_fast_scaler tb_av_fast_scaler_hq -gHQ=1
  run_case tb_av_memory tb_av_memory_hq -gHQ=1
  run_case tb_fat32_movie tb_fat32_movie_hq -gHQ=1
  for scenario in 1 2; do
    run_case tb_fat32_movie "tb_fat32_movie_reject_$scenario" -gSCENARIO="$scenario"
  done
  for scenario in 2 3; do
    run_case tb_fat32_movie "tb_fat32_movie_hq_reject_$scenario" -gHQ=1 -gSCENARIO="$scenario"
  done
fi
echo 'ALL PASS AVF video regression'
