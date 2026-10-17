from pathlib import Path
import re,json
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent
names=['README.md','docs/USER_GUIDE.md','docs/SOURCE_MAP.md',
 'docs/KEYBOARD_USAGE_20261016.md','docs/KEYBOARD_REMAINING_20261016.md',
 'docs/MEDIA_INDEX_20261016.md']
errors=[];links=0
for name in names:
 p=R/name;s=p.read_text(encoding='utf-8')
 assert '\ufffd' not in s,name
 for target in re.findall(r'\]\(([^)]+)\)',s):
  if '://' in target or target.startswith('#'):continue
  target=target.split('#')[0];links+=1
  if not (p.parent/target).exists():errors.append([name,target])
result={'documents':names,'links_checked':links,'missing_links':errors}
(O/'docs_validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
assert not errors,errors
print('ALL PASS current manuals: '+str(links)+' local links')
