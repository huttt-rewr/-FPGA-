from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[2]
sources=['src/modules/audio/spectrum_coefficients.v','src/modules/audio/spectrum_fft256.v',
         'src/modules/audio/spectrum_analyzer.v','src/modules/video/music_spectrum.v']
manifest=ROOT/'scripts/design_files.txt'
text=manifest.read_text(encoding='utf-8-sig')
for source in sources:
 if source not in text.splitlines():text=text.rstrip()+'\n'+source+'\n'
manifest.write_text(text,encoding='utf-8')
for project,prefix in [('video_improve.al',''),('src/td_project/video_improve.al','../../')]:
 path=ROOT/project
 text=path.read_text(encoding='utf-8-sig')
 order=max(map(int,re.findall(r'<Attr Name="CompileOrder" Val="(\d+)"',text)))+1
 for source in sources:
  if f'Path="{prefix}{source}"' in text:continue
  block=f'''            <File Path="{prefix}{source}">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="{order}"/>
                </FileInfo>
            </File>
'''
  text=text.replace('</Verilog>',block+'</Verilog>')
  order+=1
 path.write_text(text,encoding='utf-8')
print('Registered four portable spectrum sources in both TD projects and manifest.')
