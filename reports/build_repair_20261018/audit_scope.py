"""Protect original IO, IP, status bus and all nonplanned design files."""
from pathlib import Path
import hashlib
import json
import re
import subprocess

root = Path(__file__).resolve().parents[2]
folder = Path(__file__).resolve().parent
baseline = (folder/'baseline.txt').read_text().strip()
before = json.loads((folder/'before_hashes.json').read_text())
changed = [name for name, old in before.items()
           if (root/name).is_file() and hashlib.sha256((root/name).read_bytes()).hexdigest()!=old]
missing = [name for name in before if not (root/name).is_file()]
old = subprocess.check_output(['git','show',baseline+':src/top.v'], cwd=root).decode('utf-8-sig')
new = (root/'src/top.v').read_text(encoding='utf-8-sig')
def status(text):
    return re.sub(r'\s+', '', re.search(r'wire\s+\[69:0\]\s+status_source\s*=.*?;',text,re.S).group())
def indices(text):
    return re.findall(r'status_video\[[^\]]+\]',text)
def hdmi(text):
    return re.findall(r'hdmi_1_4b_transmitter_core_wrapper\s*#\(.*?\)\s*u_hdmi(?:_1_4b_transmitter_core_wrapper|_svga)\s*\(.*?\);', text, re.S)
def without_moved_declarations(text):
    text=re.sub(r'/\*.*?\*/|//[^\n]*','',text,flags=re.S)
    text=re.sub(r'\s+','',text)
    declarations=['wire '+s+';' for s in ['sd_card_clk','ext_mem_clk','ext_mem_clk_sft',
        'video_clk','hdmi_5x_clk','rst_sd,rst_mem,rst_video,rst_write','rst_controls',
        'tx_overflow,video_overflow','vs','mode_video=mode_vff[1],mode_sd=mode_sff[1],mode_mem=mode_mff[1]']]
    declarations += ['(*async_reg="true"*)reg[1:0]'+s+';' for s in ['mode_vff,mode_sff,mode_mff','edid_good_vff']]
    declarations += ['(*keep="true"*)reg'+s+';' for s in ['[7:0]image_index,audio_index','[1:0]res_mode','[3:0]fps_mode']]
    for declaration in declarations:
        declaration=re.sub(r'\s+','',declaration)
        assert text.count(declaration)==1,declaration
        text=text.replace(declaration,'',1)
    return text
result = dict(baseline=baseline, changed_baseline_files=changed, missing_baseline_files=missing,
              status70_identical=status(old)==status(new), status_indices_identical=indices(old)==indices(new),
              hdmi_instances_identical=len(hdmi(old))==2 and hdmi(old)==hdmi(new),
              top_only_declaration_moves=without_moved_declarations(old)==without_moved_declarations(new),
              official_ip_unchanged=not any(name.startswith('src/ip/') for name in changed+missing),
              constraints_unchanged=not any(name.startswith('src/constraints/') for name in changed+missing))
assert result['status70_identical'] and result['status_indices_identical'] and result['hdmi_instances_identical']
assert result['official_ip_unchanged'] and result['constraints_unchanged'] and not missing
assert result['top_only_declaration_moves']
(folder/'scope.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result,indent=2))
