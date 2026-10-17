from pathlib import Path
root = Path(__file__).resolve().parents[2]
rtl = root/'src/modules/sd/sd_fat32.v'
rtl.write_text(rtl.read_text(encoding='utf-8-sig'), encoding='utf-8')
source = 'src/modules/sd/sd_fat32.v'
p = root/'scripts/design_files.txt'
text = p.read_text()
if source not in text:
    p.write_text(text.rstrip()+'\n'+source+'\n')
for name, relative in [('video_improve.al', source),
                       ('src/td_project/video_improve.al', '../modules/sd/sd_fat32.v')]:
    p = root/name
    text = p.read_text(encoding='utf-8-sig')
    if 'sd_fat32.v' not in text:
        entry = f'''            <File Path="{relative}">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&amp;R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="63"/>
                </FileInfo>
            </File>
'''
        p.write_text(text.replace('        </Verilog>', entry+'        </Verilog>'), encoding='utf-8')
