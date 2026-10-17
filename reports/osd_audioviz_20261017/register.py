from pathlib import Path
R=Path(__file__).resolve().parents[2]
names=['src/modules/video/pixel_effects.v','src/modules/video/glass_osd.v','src/modules/video/audio_visualizer.v']
p=R/'scripts/design_files.txt';s=p.read_text();assert not any(n in s for n in names);p.write_text(s.rstrip()+'\n'+'\n'.join(names)+'\n')
for name,prefix in [('video_improve.al',''),('src/td_project/video_improve.al','../../')]:
 p=R/name;s=p.read_text(encoding='utf-8');new=''
 for order,n in enumerate(names,73):
  new+=f'''            <File Path="{prefix}{n}">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="{order}"/>
                </FileInfo>
            </File>
'''
 assert s.count('</Verilog>')==1;s=s.replace('        </Verilog>',new+'        </Verilog>');p.write_text(s,encoding='utf-8')
p=R/'scripts/run_tests.ps1';s=p.read_text();s=s.replace(" $mergeTests += @('tb_caption_pipeline')"," $mergeTests += @('tb_caption_pipeline','tb_pixel_effects','tb_glass_osd','tb_audio_visualizer','tb_visual_pipeline')");p.write_text(s)
print('Registered 75 design sources and 84 regression cases')
