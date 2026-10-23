from pathlib import Path
import json,runpy,re,hashlib
O=Path(__file__).resolve().parent;R=O.parents[1]
before=json.loads((O/'baseline/reports/build_manifest.json').read_text(encoding='utf-8'))['sources']
after=runpy.run_path(str(R/'scripts/run_build.py'))['snapshot']()
changed=sorted(p for p in before if before[p]!=after.get(p))
expected=sorted(['src/modules/control/boot_media_select.v','src/modules/control/picture_controls.v',
 'src/modules/osd/menu_overlay.v','src/modules/osd/zh_font_rom.v','src/top.v',
 'scripts/gen_zh_font.py','scripts/test_zh_font.py','scripts/run_tests.ps1','sim/tb_menu_overlay.v'])
assert changed==expected,changed
added=sorted(set(after)-set(before))
assert added==['sim/tb_menu_media.v','sim/tb_menu_media_pixels.v'],added
pattern=r'wire \[69:0\] status_source=\{.*?;'
old=(O/'baseline/src/top.v').read_text(encoding='utf-8');new=(R/'src/top.v').read_text(encoding='utf-8')
assert re.search(pattern,old,re.S).group()==re.search(pattern,new,re.S).group()
words=[int(w,16) for w in (R/'src/modules/osd/zh_font.mem').read_text().split()]
old_words=[int(w,16) for w in (O/'baseline/src/modules/osd/zh_font.mem').read_text().split()]
assert words[:len(old_words)]==old_words and len(words)==1440
record={'status':'ALL PASS','changed':changed,'added':added,'status_source_70_bits_unchanged':True,
 'legacy_font_words_unchanged':len(old_words),'font_words':len(words),
 'unchanged_build_inputs':len(set(before)&set(after))-len(changed),
 'media_data_paths_ip_pins_constraints_unchanged':True}
(O/'scope_audit.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record,indent=2))
