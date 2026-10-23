from pathlib import Path
import difflib
import hashlib
import json
import re
import runpy

ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
baseline=json.loads((OUT/'baseline_sources.json').read_text())
planned={'src/top.v','scripts/design_files.txt','scripts/run_tests.ps1',
         'video_improve.al','src/td_project/video_improve.al',
         'README.md','docs/BUILD_STATUS.md','docs/KEY_SW_OPERATION.md','docs/SOURCE_MAP.md',
         'scripts/implement.tcl'}
changed=[];diff=[]
for relative,sha in baseline.items():
 path=ROOT/relative
 assert path.is_file(),f'Unexpected removal: {relative}'
 if hashlib.sha256(path.read_bytes()).hexdigest()==sha:continue
 assert relative in planned,f'Unexpected modification: {relative}'
 changed.append(relative)
 diff.extend(difflib.unified_diff((OUT/'baseline'/relative).read_text(encoding='utf-8-sig').splitlines(True),
              path.read_text(encoding='utf-8-sig').splitlines(True),
              fromfile='baseline/'+relative,tofile='current/'+relative))
new_sources=['src/modules/audio/spectrum_coefficients.v','src/modules/audio/spectrum_fft256.v',
             'src/modules/audio/spectrum_analyzer.v','src/modules/video/music_spectrum.v']
for relative in new_sources+['scripts/gen_spectrum_coefficients.py','scripts/make_spectrum_vectors.py',
                            'sim/tb_spectrum_fft.v','sim/tb_spectrum_bands.v',
                            'sim/tb_music_waveform.v','sim/tb_music_spectrum.v']:
 diff.extend(difflib.unified_diff([], (ROOT/relative).read_text().splitlines(True),
              fromfile='/dev/null',tofile='current/'+relative))
old=(OUT/'baseline/src/top.v').read_text(encoding='utf-8-sig')
new=(ROOT/'src/top.v').read_text(encoding='utf-8-sig')
assert old.replace('audio_visualizer #(.BRAM_HISTORY(1)) waveform(',
                   'music_spectrum_overlay waveform(')==new,'Unexpected top integration change'
def status(source):
 return re.search(r'wire\s+\[69:0\]\s+status_source\s*=.*?;',source,re.S).group(0)
assert status(old)==status(new),'70-bit status_source changed'
assert (OUT/'baseline/scripts/implement.tcl').read_text().replace('set_param place seed 25',
 'set_param place seed 26')==(ROOT/'scripts/implement.tcl').read_text(),'Only placement seed may change'
generated=runpy.run_path(str(ROOT/'scripts/gen_spectrum_coefficients.py'))['generate']()
assert (ROOT/'src/modules/audio/spectrum_coefficients.v').read_text()==generated
protected=[p for p in baseline if p.startswith(('src/modules/sd/','src/modules/bmp/',
 'src/modules/memory/','src/modules/control/','src/modules/osd/','src/modules/game/',
 'src/ip/','src/constraints/'))]
record={'changed_existing':changed,'new_synthesis_sources':new_sources,
        'protected_files_unchanged':len(protected),'status_source_70_bits_unchanged':True,
        'top_only_replaces_active_visualizer_instance':True,'coefficient_reproducibility':True,
        'reference_project_modified':False}
(OUT/'changes.diff').write_text(''.join(diff),encoding='utf-8')
(OUT/'scope_audit.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
print('ALL PASS scope audit:',len(protected),'protected source/IP/constraint files unchanged; only top visualizer instance replaced')
