"""Check new/edited documentation links and current-use storage instructions."""
from pathlib import Path
import re
import zipfile

root = Path(__file__).resolve().parents[2]
names = ['README.md', 'docs/README.md', 'docs/USER_GUIDE.md',
         'docs/CONNECTION_AND_USAGE.md', 'docs/KEY_SW_OPERATION.md',
         'docs/SOURCE_MAP.md', 'docs/WAV_AUDIO_20261014.md',
         'docs/FAT32_USAGE_20261015.md', 'docs/BUILD_STATUS.md',
         'reports/fat32_20261015/RESULT.md']
links = lambda text: set(re.findall(r'\]\(([^)]+)\)', text))
checked = 0
with zipfile.ZipFile(root/'backups/fat32_20261015/before.zip') as old:
    for name in names:
        current = root/name
        previous = links(old.read(name).decode('utf-8-sig')) if name in old.namelist() else set()
        for link in links(current.read_text(encoding='utf-8-sig')) - previous:
            target = link.split('#')[0]
            if not target or '://' in target:
                continue
            assert (current.parent/target).exists(), f'Broken new link: {name} -> {link}'
            checked += 1
for name in ('README.md', 'docs/USER_GUIDE.md', 'docs/WAV_AUDIO_20261014.md'):
    text = (root/name).read_text(encoding='utf-8-sig')
    for wrong in ('不支持FAT目录/簇链', '当前读取原始LBA131072', '查SD初始化和固定WAV地址',
                  '确认写的是合成镜像而非FAT文件复制'):
        assert wrong not in text, (name, wrong)
print(f'ALL PASS docs: {len(names)} files, {checked} new local links, current FAT32 instructions')
