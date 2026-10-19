"""Stage this task's README additions, preserving the user's existing edit."""
from pathlib import Path
import difflib
import subprocess

r=Path(__file__).resolve().parents[2]
here=Path(__file__).resolve().parent
head=subprocess.check_output(['git','show','HEAD:README.md'],cwd=r).decode('utf-8')
prior=(here/'before/README.md').read_text(encoding='utf-8-sig')
current=(r/'README.md').read_text(encoding='utf-8-sig')
old='| `reports/`、`backups/`、`legacy/` | 构建/实验冻结证据、修改前备份、未启用历史参考源 |'
user='| `reports/`、`legacy/` | 构建/实验冻结证据、未启用历史参考源 |'
assert prior==head.replace(old,user),'Unexpected starting README difference'
index=current.replace(user,old)
patch=''.join(difflib.unified_diff(head.splitlines(True),index.splitlines(True),
                               fromfile='a/README.md',tofile='b/README.md'))
(here/'README_index.patch').write_text(patch,encoding='utf-8',newline='\n')
print('README index patch prepared; prior user line remains unstaged')
