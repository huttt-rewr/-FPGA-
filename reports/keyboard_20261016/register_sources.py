from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
names = ['src/modules/input/ps2_keyboard.v', 'src/modules/input/ps2_controls.v']
for project, prefix in [('video_improve.al', ''), ('src/td_project/video_improve.al', '../../')]:
    path = root / project
    text = path.read_text(encoding='utf-8-sig')
    last = max(int(x) for x in re.findall(r'Name="CompileOrder" Val="(\d+)"', text))
    entries = ''
    for offset, name in enumerate(names, 1):
        target = prefix + name.removeprefix('src/') if prefix else name
        # The nested project lives in src/td_project: ../modules is canonical.
        if prefix:
            target = '../' + name.removeprefix('src/')
        if f'Path="{target}"' in text:
            continue
        entries += f'''            <File Path="{target}">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="{last+offset}"/>
                </FileInfo>
            </File>
'''
    text = text.replace('        </Verilog>', entries + '        </Verilog>')
    path.write_text(text, encoding='utf-8')
manifest = root / 'scripts/design_files.txt'
lines = manifest.read_text().splitlines()
manifest.write_text('\n'.join(lines + [p for p in names if p not in lines]) + '\n', encoding='utf-8')
