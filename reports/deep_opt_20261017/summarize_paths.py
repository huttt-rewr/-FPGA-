"""Summarize actual TD path endpoints without confusing hold and removal."""
from pathlib import Path
import json,re,sys
p=Path(sys.argv[1]);s=p.read_text(encoding="utf-8",errors="replace")
pattern=r"Slack\s+: (-?[0-9.]+)ns\s+Begin Point\s+: (.*?)\s+End Point\s+: (.*?)\s+Check Type\s+: (\w+)"
paths=[{"slack_ns":float(m[1]),"check":m[4],"from":m[2].split(" (")[0],"to":m[3].split(" (")[0]} for m in re.finditer(pattern,s)]
result={"report":p.as_posix(),"confidence":re.search(r"Confidence\s+:\s+(\w+)",s)[1],"reported_paths":len(paths),"negative_reported_paths":sum(x["slack_ns"]<0 for x in paths),"worst_by_type":{t:sorted([x for x in paths if x["check"]==t],key=lambda x:x["slack_ns"])[:20] for t in sorted({x["check"] for x in paths})}}
print(json.dumps(result,ensure_ascii=False,indent=2))
