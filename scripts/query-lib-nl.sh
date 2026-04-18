#!/usr/bin/env bash
# query-lib-nl.sh — SE-031 slice 2
# Natural language → Query Library ID (heuristic, deterministic, no LLM).
# Ref: docs/propuestas/SE-031-query-library-nl.md
#
# Pipeline:
#   1. Exact match: NL description token set == candidate description tokens
#   2. Fuzzy match: Jaccard(NL tokens, desc+tags tokens) ≥ threshold
#   3. Fallback: emit schema prompt + placeholder
#
# Usage:
#   bash scripts/query-lib-nl.sh "PBIs blocked more than 3 days"
#   bash scripts/query-lib-nl.sh --lang wiql "blocked items"
#   bash scripts/query-lib-nl.sh --json "velocity last 3 sprints"
#   bash scripts/query-lib-nl.sh --min-score 0.5 "my open bugs"
#
# Exit codes:
#   0 = match found (unique)
#   1 = no match (fallback prompt emitted)
#   2 = multiple candidates (disambiguation needed)
#   3 = input error

set -uo pipefail

LANG_FILTER=""
JSON_OUT=false
MIN_SCORE="0.30"
TOPK=3
NL=""

usage() {
  sed -n '2,18p' "$0" | sed 's/^# \?//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lang)      LANG_FILTER="$2"; shift 2 ;;
    --json)      JSON_OUT=true; shift ;;
    --min-score) MIN_SCORE="$2"; shift 2 ;;
    --topk)      TOPK="$2"; shift 2 ;;
    --help|-h)   usage ;;
    --*)         echo "Error: unknown flag $1" >&2; exit 3 ;;
    *)           NL="${NL:+$NL }$1"; shift ;;
  esac
done

[[ -z "$NL" ]] && { echo "Error: NL query required" >&2; exit 3; }

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}" || REPO_ROOT="."
QUERIES_DIR="$REPO_ROOT/.claude/queries"

[[ ! -d "$QUERIES_DIR" ]] && { echo "Error: queries dir not found: $QUERIES_DIR" >&2; exit 3; }

export REPO_ROOT NL LANG_FILTER MIN_SCORE TOPK JSON_OUT

python3 <<'PY'
import os, re, sys, json, unicodedata

REPO = os.environ["REPO_ROOT"]
NL = os.environ["NL"]
LANG = os.environ.get("LANG_FILTER", "")
MIN_SCORE = float(os.environ.get("MIN_SCORE", "0.30"))
TOPK = int(os.environ.get("TOPK", "3"))
JSON_OUT = os.environ.get("JSON_OUT", "false") == "true"

Q_DIR = os.path.join(REPO, ".claude/queries")

STOPWORDS = set("""
a al an and are as at be but by de del el en es for from has have he i in is it its la
las le les los me mi mis my no nos not of on or por para que se si sin sobre su sus that the
their them they this to un una unas uno with without y your you hace con mas more than menos
than los las
""".split())

# Alias expansion (domain terms → canonical tokens)
ALIASES = {
    "blocked":     ["blocked", "bloqueado", "bloqueados", "stuck"],
    "sprint":      ["sprint", "iteracion", "iteration"],
    "pbi":         ["pbi", "pbis", "backlog", "item", "items"],
    "bug":         ["bug", "bugs", "defect", "defecto", "defectos"],
    "velocity":    ["velocity", "velocidad"],
    "review":      ["review", "reviews", "revision", "revisiones"],
    "owner":       ["owner", "assignee", "asignado", "asignada", "assigned"],
    "estimate":    ["estimate", "estimacion", "estimation", "puntos"],
    "days":        ["days", "dias"],
    "open":        ["open", "abiertos", "abiertas", "activos", "activas"],
    "current":     ["current", "actual", "active"],
    "my":          ["my", "mis", "me"],
    "jira":        ["jira"],
    "azure":       ["azure", "devops"],
    "savia":       ["savia", "saviaflow", "savia-flow"],
}

# Reverse alias map: variant → canonical
ALIAS_MAP = {}
for canon, variants in ALIASES.items():
    for v in variants:
        ALIAS_MAP[v] = canon

def normalize(s):
    """Lowercase, strip accents, remove punctuation."""
    if not s:
        return ""
    s = s.lower().strip()
    # Strip accents (NFD + drop combining)
    s = "".join(c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn")
    # Replace punctuation with space
    s = re.sub(r"[^\w\s]", " ", s)
    return re.sub(r"\s+", " ", s).strip()

def tokenize(s):
    """Normalize + split + drop stopwords + alias-expand."""
    norm = normalize(s)
    toks = [t for t in norm.split() if t and t not in STOPWORDS]
    # Expand aliases to canonical form
    expanded = []
    for t in toks:
        expanded.append(ALIAS_MAP.get(t, t))
    return set(expanded)

def f1_score(a, b):
    """F1 / Dice coefficient — less diluted by haystack size than Jaccard."""
    if not a or not b:
        return 0.0
    inter = len(a & b)
    if inter == 0:
        return 0.0
    return 2 * inter / (len(a) + len(b))

# Load all snippets
candidates = []
for root, dirs, files in os.walk(Q_DIR):
    for f in sorted(files):
        if f == "INDEX.md":
            continue
        if not f.endswith((".wiql", ".jql", ".yaml")):
            continue
        path = os.path.join(root, f)
        try:
            with open(path) as fd:
                content = fd.read()
        except Exception:
            continue
        m = re.search(r'^---\n(.*?)\n---', content, re.DOTALL | re.MULTILINE)
        fm = m.group(1) if m else ""
        def grab(k, block=fm):
            mm = re.search(r'^' + re.escape(k) + r':\s*(.+)$', block, re.MULTILINE)
            return mm.group(1).strip().strip('"') if mm else ""
        qid  = grab("id") or f.rsplit(".", 1)[0]
        qlang = grab("lang") or "unknown"
        if LANG and qlang != LANG:
            continue
        desc = grab("description")
        tags = grab("tags").strip("[]")
        candidates.append({
            "id": qid,
            "lang": qlang,
            "description": desc,
            "tags": tags,
            "path": os.path.relpath(path, REPO),
        })

# Score each candidate
nl_tokens = tokenize(NL)
# Also include the raw id tokens (split kebab-case) as a boost signal
scored = []
for c in candidates:
    desc_tokens = tokenize(c["description"])
    tag_tokens  = tokenize(c["tags"].replace(",", " "))
    id_tokens   = tokenize(c["id"].replace("-", " "))
    haystack = desc_tokens | tag_tokens | id_tokens
    score = f1_score(nl_tokens, haystack)
    # Exact phrase boost: if any multi-token substring of NL appears in desc
    if c["description"] and len(nl_tokens) >= 2:
        nl_norm = normalize(NL)
        desc_norm = normalize(c["description"])
        # 3-token shingle match
        nl_words = nl_norm.split()
        for i in range(len(nl_words) - 1):
            shingle = " ".join(nl_words[i:i+2])
            if shingle in desc_norm:
                score = min(1.0, score + 0.1)
                break
    scored.append((score, c))

scored.sort(key=lambda x: (-x[0], x[1]["id"]))
top = [s for s in scored if s[0] >= MIN_SCORE][:TOPK]

if not top:
    # Fallback: schema prompt
    fallback = {
        "match": None,
        "reason": "no_match",
        "nl": NL,
        "available_langs": sorted({c["lang"] for c in candidates}),
        "nearest": [
            {"id": c["id"], "score": round(s, 3), "description": c["description"]}
            for s, c in scored[:3]
        ],
        "schema_prompt": (
            "No query matched '{nl}'.\n"
            "Available fields for a WIQL skeleton:\n"
            "  [System.Id] [System.Title] [System.State] [System.AssignedTo]\n"
            "  [System.WorkItemType] [System.IterationPath] [System.AreaPath]\n"
            "  [System.ChangedDate] [System.CreatedDate] [Microsoft.VSTS.Common.Priority]\n"
            "  [Microsoft.VSTS.Scheduling.OriginalEstimate] [Microsoft.VSTS.Scheduling.RemainingWork]\n"
            "Propose a snippet at .claude/queries/<lang>/<kebab-id>.<ext> with frontmatter,\n"
            "then re-run the NL query or use query-lib-resolve.sh --id directly."
        ).format(nl=NL),
    }
    if JSON_OUT:
        print(json.dumps(fallback))
    else:
        print("# NO MATCH")
        print("# NL: " + NL)
        print("# Min-score: " + str(MIN_SCORE))
        if fallback["nearest"]:
            print("# Nearest candidates (below threshold):")
            for n in fallback["nearest"]:
                print("#   {0} ({1}) — {2}".format(n["id"], n["score"], n["description"]))
        print("# ---")
        print(fallback["schema_prompt"])
    sys.exit(1)

if len(top) == 1 or (len(top) > 1 and top[0][0] > top[1][0] + 0.15):
    # Unique winner (or clear leader by >0.15 margin)
    winner = top[0][1]
    if JSON_OUT:
        print(json.dumps({
            "match": winner["id"],
            "score": round(top[0][0], 3),
            "lang": winner["lang"],
            "description": winner["description"],
            "path": winner["path"],
            "resolved_by": "query-lib-resolve.sh --id " + winner["id"],
        }))
    else:
        print(winner["id"])
    sys.exit(0)

# Multiple candidates — emit disambiguation list
if JSON_OUT:
    print(json.dumps({
        "match": None,
        "reason": "ambiguous",
        "nl": NL,
        "candidates": [
            {"id": c["id"], "score": round(s, 3), "lang": c["lang"],
             "description": c["description"]}
            for s, c in top
        ],
    }))
else:
    print("# AMBIGUOUS — multiple candidates (score order):")
    for s, c in top:
        print("#   {0} ({1}) [{2}] — {3}".format(c["id"], round(s, 3), c["lang"], c["description"]))
    print("# Pick one: query-lib-resolve.sh --id <id>")
sys.exit(2)
PY
