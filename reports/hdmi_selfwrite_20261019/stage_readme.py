"""Prepare a reviewable index patch without staging the user's prior edit."""
from pathlib import Path
import difflib
import subprocess

r=Path(__file__).resolve().parents[2]
here=Path(__file__).resolve().parent
original=subprocess.check_output(['git','show','HEAD:README.md'],cwd=r).decode('utf-8')
baseline=(here/'before/README.md').read_text(encoding='utf-8-sig')
current=(r/'README.md').read_text(encoding='utf-8-sig')
old='| `reports/`、`backups/`、`legacy/` | 构建/实验冻结证据、修改前备份、未启用历史参考源 |'
user='| `reports/`、`legacy/` | 构建/实验冻结证据、未启用历史参考源 |'
assert baseline==original.replace(old,user),'Unexpected prior README changes'
staged=current.replace(user,old)
patch=''.join(difflib.unified_diff(original.splitlines(True),staged.splitlines(True),
                               fromfile='a/README.md',tofile='b/README.md'))
(here/'readme_index.patch').write_text(patch,encoding='utf-8',newline='\n')
print('Prepared README index patch; original user line remains unstaged')
