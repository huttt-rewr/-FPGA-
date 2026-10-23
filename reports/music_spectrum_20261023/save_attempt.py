from pathlib import Path
import shutil
import sys
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent/sys.argv[1]
for relative in ['src/modules/audio/spectrum_coefficients.v','scripts/gen_spectrum_coefficients.py',
                 'src/modules/audio/spectrum_fft256.v','src/modules/audio/spectrum_analyzer.v',
                 'src/modules/video/music_spectrum.v','scripts/implement.tcl',
                 'reports/build_manifest.json','reports/gate_area.txt','reports/rtl_area.txt',
                 'reports/physical_area.txt','reports/timing_status.txt','reports/timing_summary.txt',
                 'reports/routed_timing_paths20.txt','reports/implementation.log','reports/synthesis.log',
                 'reports/music_spectrum_20261023/build_console.log',
                 'reports/music_spectrum_20261023/main_validation.json']:
 source=ROOT/relative
 if source.is_file():
  target=OUT/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
print('Preserved attempt',OUT)
