from pathlib import Path
import hashlib
import json
import re
import zipfile

ROOT = Path(__file__).resolve().parents[2]
D = Path(__file__).resolve().parent
before = json.loads((D / 'before_hashes.json').read_text(encoding='utf-8'))
allowed = {'src/top.v', 'src/modules/input/ps2_controls.v', 'src/td_project/video_improve.al'}
protected = {n: h for n, h in before.items() if n.startswith('src/') and n not in allowed}
changed = [n for n, h in protected.items() if not (ROOT / n).exists()
           or hashlib.sha256((ROOT / n).read_bytes()).hexdigest() != h]
assert not changed, changed
with zipfile.ZipFile(ROOT / 'backups/snake_20261017/before.zip') as z:
    old = z.read('src/top.v').decode('utf-8').replace('\r\n', '\n')
new = (ROOT / 'src/top.v').read_text(encoding='utf-8')
source = lambda s: re.search(r'wire \[69:0\] status_source=.*?;', s, re.S).group(0)
assert source(old) == source(new)
indices = lambda s: re.findall(r'^.*status_video\[.*$', s, re.M)
assert indices(old) == indices(new)
clean = new.replace('''wire game_vs,game_de,game_on,game_tick,game_over;
wire [23:0] game_rgb;wire [7:0] game_score;
wire kb_game_on,kb_held_up,kb_held_down,kb_held_left,kb_held_right;
wire [4:0] game_controls_video;wire [1:0] game_dir;
wire [9:0] game_x,game_y;
''', '')
clean = clean.replace('.I_vs          (game_vs)', '.I_vs          (osd_vs)')
clean = clean.replace('.I_de          (game_de)', '.I_de          (osd_de)')
clean = clean.replace('.I_rgb         (game_rgb)', '.I_rgb         (osd_rgb)')
clean = clean.replace(' .game_enable(kb_game_on),.held_up(kb_held_up),.held_down(kb_held_down),.held_left(kb_held_left),.held_right(kb_held_right),\n', '')
a = clean.index('// Separate game control snapshot:')
b = clean.index('// 音频流有效标志', a)
clean = clean[:a] + clean[b:]
assert clean == old, 'Unexpected top changes beyond planned game integration'
sources = [ROOT / 'src/top.v', ROOT / 'src/modules/input/ps2_controls.v',
           ROOT / 'src/modules/game/snake_game.v', *sorted((ROOT / 'sim').glob('tb_snake*.v'))]
result = {
    'protected_src_count': len(protected), 'protected_src_changed': changed,
    'status_source_70bit_unchanged': True, 'status_video_selectors_unchanged': True,
    'top_only_game_changes': True,
    'sources': {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},
}
(D / 'scope_audit.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(f'ALL PASS scope audit: {len(protected)} protected sources, 70-bit status and selectors, game-only top edits')
