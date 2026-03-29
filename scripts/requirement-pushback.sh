#!/usr/bin/env bash
# requirement-pushback.sh — Analyze a spec and generate pushback questions
# Usage: bash scripts/requirement-pushback.sh <spec-file>
# Output: JSON report to stdout — SPEC-047 Phase 1
set -uo pipefail

SPEC_FILE="${1:-}"
if [[ -z "$SPEC_FILE" ]]; then
  echo '{"error":"Usage: requirement-pushback.sh <spec-file>"}' >&2; exit 1
fi
if [[ ! -f "$SPEC_FILE" ]]; then
  echo "{\"error\":\"File not found: $SPEC_FILE\"}" >&2; exit 1
fi
export _PUSHBACK_SPEC="$SPEC_FILE"
if [[ ! -s "$SPEC_FILE" ]]; then
  python3 -c "
import json,os;from datetime import datetime,timezone
f=os.environ.get('_PUSHBACK_SPEC','')
print(json.dumps({'spec_file':f,'timestamp':datetime.now(timezone.utc).isoformat(),
'questions':[],'summary':{'total_questions':0,'by_type':{}}},indent=2))"
  exit 0
fi

python3 << 'PYEOF'
import json, re, os, sys
from datetime import datetime, timezone

spec_file = os.environ["_PUSHBACK_SPEC"]
with open(spec_file, "r", encoding="utf-8", errors="replace") as f:
    content = f.read()
lines = content.split("\n")
questions = []
current_section = "untitled"

PATTERNS = {
    "assumption": [
        (r'\b(must|shall|always|never|all users|every)\b',
         '"{w}" — what evidence supports this? What if this assumption is wrong?'),
        (r'\b(obviously|clearly|of course|trivially)\b',
         '"{w}" — what evidence supports this? What if this assumption is wrong?'),
        (r'\b(will be|is guaranteed|cannot fail)\b',
         '"{w}" — what evidence supports this? What if this assumption is wrong?'),
    ],
    "ambiguity": [
        (r'\b(fast|quick|scalable|flexible|robust|efficient|smart)\b',
         '"{w}" is vague. Define a measurable threshold or acceptance criterion.'),
        (r'\b(should be easy|intuitive|user.friendly|seamless)\b',
         '"{w}" is vague. Define a measurable threshold or acceptance criterion.'),
        (r'\b(as needed|when appropriate|if necessary|etc\.?)\b',
         '"{w}" is vague. Define a measurable threshold or acceptance criterion.'),
    ],
    "complexity": [
        (r'(\d+)\s*(steps?|phases?|stages?|layers?|components?)',
         'Is this complexity justified? What is the simplest version that delivers value?'),
        (r'pipeline|orchestrat|choreograph',
         'Is this complexity justified? What is the simplest version that delivers value?'),
    ],
}

def scan_line(stripped):
    for qtype, pats in PATTERNS.items():
        for regex, tmpl in pats:
            m = re.search(regex, stripped, re.IGNORECASE)
            if m:
                w = m.group(0)
                questions.append({"type": qtype, "section": current_section,
                    "claim": stripped[:200], "question": tmpl.format(w=w)})
                return

for line in lines:
    stripped = line.strip()
    if stripped.startswith("#"):
        current_section = stripped.lstrip("# ").strip()
        continue
    if not stripped or len(stripped) < 10:
        continue
    scan_line(stripped)

# Scope: sections with >5 list items
sec_items = {}
sec = "untitled"
for line in lines:
    s = line.strip()
    if s.startswith("#"):
        sec = s.lstrip("# ").strip()
    elif re.match(r'^[-*]\s+', s):
        sec_items[sec] = sec_items.get(sec, 0) + 1
for sec, count in sec_items.items():
    if count > 5:
        questions.append({"type": "scope", "section": sec,
            "claim": f"{count} list items in this section",
            "question": f"{count} items here. Reduce to essential 3-5 for first iteration?"})

# Scope: phase/future references
for pat in [r'phase\s*(\d+|[ivx]+)', r'\b(future|later|eventually|roadmap)\b']:
    m = re.search(pat, content, re.IGNORECASE)
    if m:
        ctx = content[max(0,m.start()-40):min(len(content),m.end()+40)].replace("\n"," ").strip()
        questions.append({"type": "scope", "section": current_section,
            "claim": ctx[:200],
            "question": "Future phase reference — is current scope self-contained?"})
        break
# Deduplicate
seen, unique = set(), []
for q in questions:
    key = (q["type"], q["section"], q["question"][:60])
    if key not in seen:
        seen.add(key)
        unique.append(q)

by_type = {}
for q in unique:
    by_type[q["type"]] = by_type.get(q["type"], 0) + 1

print(json.dumps({"spec_file": spec_file,
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "questions": unique,
    "summary": {"total_questions": len(unique), "by_type": by_type}
}, indent=2, ensure_ascii=False))
PYEOF
