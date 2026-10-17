"""Keep each timing experiment and the starting workspace evidence separate."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
TARGET = ROOT/'src/modules/sd/sd_fat32.v'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def inputs():
    return {p.relative_to(ROOT).as_posix(): digest(p)
            for folder in ('src', 'scripts', 'sim')
            for p in (ROOT/folder).rglob('*') if p.is_file()
            and p.suffix in ('.v', '.vhd', '.tcl', '.adc', '.sdc', '.py', '.ps1', '.txt', '.al', '.ipc')
            and 'msim_work' not in p.parts and 'pll_work' not in p.parts}

mode = sys.argv[1]
if mode == 'backup':
    path = ROOT/'backups/fat32_setup_20261016/before.zip'
    assert not path.exists(), 'Backup already exists; refusing to replace baseline'
    path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
        for p in [TARGET, ROOT/'scripts/synth.tcl', *[p for p in (ROOT/'reports').iterdir() if p.is_file()]]:
            z.write(p, p.relative_to(ROOT).as_posix())
    (OUT/'baseline_sources.json').write_text(json.dumps(inputs(), indent=2))
    shutil.copy2(TARGET, OUT/'baseline_sd_fat32.v.txt')
    print('Backup saved:', path)
elif mode == 'capture':
    dest = OUT/sys.argv[2]
    dest.mkdir(exist_ok=True)
    manifest = json.loads((ROOT/'reports/build_manifest.json').read_text())
    for name, expected in manifest['sources'].items():
        assert digest(ROOT/name) == expected, f'Source/build mismatch: {name}'
    for name in ('build_manifest.json', 'timing_status.txt', 'timing_summary.txt',
                 'physical_area.txt', 'synthesis.log', 'implementation.log', 'video_improve_routed.db'):
        shutil.copy2(ROOT/'reports'/name, dest/name)
    shutil.copy2(TARGET, dest/'sd_fat32.v.txt')
    summary = (dest/'timing_summary.txt').read_text()
    paths = re.findall(r'Slack\s+: ([+-]?[\d.]+)ns\s+Begin Point\s+: ([^\n]+)\nEnd Point\s+: ([^\n]+)\nCheck Type\s+: setup', summary)
    negative = [{'slack_ns': float(s), 'begin': a.split(' (')[0], 'end': b.split(' (')[0]}
                for s,a,b in paths if float(s)<0]
    result = {'timing_ns': manifest['timing_ns'], 'source_sha256': digest(TARGET), 'negative_setup_paths': negative}
    (dest/'result.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))
elif mode == 'restore':
    TARGET.write_bytes((OUT/'baseline_sd_fat32.v.txt').read_bytes())
    print('Restored exact starting FAT32 RTL')
elif mode == 'apply':
    baseline = (OUT/'baseline_sd_fat32.v.txt').read_bytes()
    assert TARGET.read_bytes() == baseline, 'Restore the failed candidate before applying another'
    text = baseline.decode('utf-8').replace('\r\n', '\n')
    def replace(old, new):
        global text
        assert text.count(old)==1, old
        text=text.replace(old,new)
    number = int(sys.argv[2])
    if number == 2:
        replace('fat_capacity_bad<=(fat_sectors<<7)<=max_cluster;',
                '// GEOM_FIELDS已拒绝fat_sectors高8位非零，左移无溢出，比较等价。\n     fat_capacity_bad<=fat_sectors<=max_cluster[31:7];')
    elif number == 3:
        replace("     if(ext_flags[7] && ext_flags[3:0]==1)first_fat<=first_fat+fat_sectors;\n", '')
        replace('    state[6]:begin data_sectors<=total_sectors-overhead;state<=GEOM4;end',
                "    state[6]:begin\n     data_sectors<=total_sectors-overhead;\n     // first_data已在GEOM2按FAT1基址计算，本拍才选择活动FAT。\n     if(ext_flags[7] && ext_flags[3:0]==1)first_fat<=first_fat+fat_sectors;\n     state<=GEOM4;\n    end")
    elif number == 4:
        replace(' reg geometry_bad,root_bad,fat_capacity_bad,boot_signature_ok,boot_super_ok,boot_partition_ok,geom_fields_bad;',
                ' reg geometry_bad,root_bad,fat_capacity_bad,boot_signature_ok,boot_super_ok,boot_partition_ok,geom_fields_bad;\n reg cmp_to,cmp_vol,cmp_lo,cmp_hi;')
        replace('   boot_signature_ok<=0;boot_super_ok<=0;boot_partition_ok<=0;geom_fields_bad<=0;',
                '   boot_signature_ok<=0;boot_super_ok<=0;boot_partition_ok<=0;geom_fields_bad<=0;\n   cmp_to<=0;cmp_vol<=0;cmp_lo<=0;cmp_hi<=0;')
        replace('    state[6]:begin data_sectors<=total_sectors-overhead;state<=GEOM4;end',
                '    state[6]:begin\n     data_sectors<=total_sectors-overhead;\n     // 依赖GEOM2已寄存的overhead/volume_last，提前完成宽比较。\n     cmp_to<=total_sectors<=overhead;cmp_vol<=volume_last<partition_lba;\n     state<=GEOM4;\n    end')
        replace("    state[28]:begin max_cluster<=data_clusters+1'b1;state<=GEOM6;end",
                "    state[28]:begin\n     max_cluster<=data_clusters+1'b1;\n     // data_clusters在上一拍GEOM4稳定，此处与加一并行。\n     cmp_lo<=data_clusters<65525;cmp_hi<=data_clusters>=32'h0fffffee;\n     state<=GEOM6;\n    end")
        replace("     geometry_bad<=total_sectors<=overhead || volume_last<partition_lba || data_clusters<65525 ||\n       data_clusters>=32'h0fffffee ||",
                '     geometry_bad<=cmp_to || cmp_vol || cmp_lo || cmp_hi ||')
    else:
        raise ValueError(number)
    newline = '\r\n' if b'\r\n' in baseline else '\n'
    TARGET.write_bytes(text.replace('\n',newline).encode('utf-8'))
    print('Applied isolated optimization', number)
elif mode == 'scope':
    old = json.loads((OUT/'baseline_sources.json').read_text())
    new = inputs()
    changed = [p for p in old.keys() | new.keys() if old.get(p)!=new.get(p)]
    assert set(changed) <= {'src/modules/sd/sd_fat32.v', 'scripts/synth.tcl'}, changed
    print('Allowed source changes:', changed)
else:
    raise ValueError(mode)
