from pathlib import Path
import json,zipfile
root=Path(__file__).resolve().parents[2]
out=Path(__file__).resolve().parent
record={'path':'backups/audio_effects_20261014_211158',
        'hashes':json.loads((root/'backups/audio_effects_20261014_211158/manifest.json').read_text())}
(out/'backup_record.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
with zipfile.ZipFile(root/record['path']/'workspace.zip') as z:
    before=z.read('video_improve.al')
entry=b'''            <File Path="src/modules/audio/audio_effects.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&amp;R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="62"/>
                </FileInfo>
            </File>
'''.replace(b'\n',b'\r\n')
assert before.count(b'        </Verilog>')==1
(root/'video_improve.al').write_bytes(before.replace(b'        </Verilog>',entry+b'        </Verilog>'))
print('Restored original root TD metadata plus the ONE new source entry')
