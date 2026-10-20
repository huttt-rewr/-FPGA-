from pathlib import Path
import hashlib,json,shutil,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
TASK=Path(__file__).resolve().parent
def inputs():
    return [p for base in ('src','scripts','sim') for p in (ROOT/base).rglob('*')
            if p.is_file() and p.suffix in ('.v','.vh','.vhd','.adc','.sdc','.al','.ipc','.tcl','.ps1','.py','.txt','.mem')
            and not any(x.endswith('_work') for x in p.parts)]+[ROOT/'video_improve.al']
def backup():
    dest=TASK/'before'
    assert not dest.exists()
    record={'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'files':{}}
    paths=inputs()+[ROOT/p for p in ('README.md','docs/USER_GUIDE.md','docs/KEY_SW_OPERATION.md','docs/BUILD_STATUS.md')]
    paths += [ROOT/'reports'/n for n in ('build_manifest.json','timing_status.txt','routed_timing_paths20.txt',
             'physical_area.txt','synthesis.log','implementation.log','hold_finalization.log')]
    for p in paths:
        rel=p.relative_to(ROOT);q=dest/rel;q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,q)
        record['files'][rel.as_posix()]=hashlib.sha256(p.read_bytes()).hexdigest()
    (TASK/'baseline.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
    print('Backed up',len(paths),'files at',record['head'])
def register(names):
    manifest=ROOT/'scripts/design_files.txt'
    s=manifest.read_text()
    for name in names:
        if name not in s:s+=name+'\n'
    manifest.write_text(s,encoding='utf-8')
    for proj,prefix in ((ROOT/'video_improve.al',''),(ROOT/'src/td_project/video_improve.al','../../')):
        s=proj.read_text(encoding='utf-8-sig')
        for name in names:
            if prefix+name in s:continue
            order=max(map(int,__import__('re').findall(r'Name="CompileOrder" Val="(\d+)"',s)))+1
            entry=f'''            <File Path="{prefix+name}">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&amp;R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="{order}"/>
                </FileInfo>
            </File>
'''
            s=s.replace('        </Verilog>',entry+'        </Verilog>')
        proj.write_text(s,encoding='utf-8')
def archive(label):
    dest=TASK/label
    assert not dest.exists()
    for p in inputs():
        q=dest/p.relative_to(ROOT);q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,q)
    for name in ('build_manifest.json','timing_status.txt','timing_summary.txt','routed_timing_paths20.txt',
                 'physical_area.txt','gate_area.txt','synthesis.log','implementation.log','hold_finalization.log'):
        p=ROOT/'reports'/name
        if p.exists():
            q=dest/'reports'/name;q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,q)
    for p in (ROOT/'reports').glob('tb_*.log'):
        q=dest/'regression'/p.name;q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,q)
    print('Archived',label)
if sys.argv[1]=='backup':backup()
elif sys.argv[1]=='register':register(sys.argv[2:])
elif sys.argv[1]=='archive':archive(sys.argv[2])
