"""Read-only comparison of the local and teammate source trees; save review evidence."""
from pathlib import Path
import difflib
import hashlib
import json

ROOT = Path(__file__).resolve().parent.parent
TEAM = Path('E:/2/fpga')
OUT = ROOT / 'reports/team_merge_20261008'


def inventory(root):
    return {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in root.rglob('*') if p.is_file()
            and not any(x in p.relative_to(root).parts for x in
                        ('.git', 'reports', 'backups', 'msim_work', 'pll_work'))}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    a, b = inventory(ROOT), inventory(TEAM)
    result = {'local': str(ROOT), 'team': str(TEAM), 'files': []}
    differences = []
    for name in sorted(a.keys() | b.keys()):
        status = ('team_only' if name not in a else 'local_only' if name not in b
                  else 'identical' if a[name] == b[name] else 'different')
        result['files'].append({'path': name, 'status': status,
                                'local_sha256': a.get(name), 'team_sha256': b.get(name)})
        if status == 'different' and Path(name).suffix in ('.v', '.sv', '.sdc', '.adc', '.al', '.md'):
            differences.extend(difflib.unified_diff(
                (ROOT/name).read_text(encoding='utf-8-sig').splitlines(True),
                (TEAM/name).read_text(encoding='utf-8-sig').splitlines(True),
                fromfile='local/'+name, tofile='team/'+name))
    (OUT/'comparison.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    (OUT/'team.diff').write_text(''.join(differences), encoding='utf-8')
    print(''.join(differences))


if __name__ == '__main__':
    main()
