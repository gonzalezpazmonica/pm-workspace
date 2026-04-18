#!/usr/bin/env bash
# rules-domain-index.sh — SPEC-115
# Regenerates docs/rules/domain/INDEX.md from the current file list.
# Run after adding/removing/renaming any domain rule file.
#
# Usage:
#   bash scripts/rules-domain-index.sh [--check]
#
# With --check: exits 1 if INDEX.md is stale (does not match current files).

set -uo pipefail

CHECK_MODE=false
[[ "${1:-}" == "--check" ]] && CHECK_MODE=true

REPO_ROOT="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)" || REPO_ROOT="."
cd "$REPO_ROOT" || exit 2

INDEX="docs/rules/domain/INDEX.md"
TMP_INDEX=$(mktemp)
trap 'rm -f "$TMP_INDEX"' EXIT

python3 <<'PY' > "$TMP_INDEX"
import os, re
from collections import defaultdict

D = "docs/rules/domain"
files = sorted(f for f in os.listdir(D) if f.endswith(".md") and f != "INDEX.md")

def describe(fname):
    path = f"{D}/{fname}"
    try:
        with open(path) as f: content = f.read()
    except: return ""
    if content.startswith("---"):
        m = re.match(r'^---\n.*?\n---\n', content, re.DOTALL)
        if m: content = content[m.end():]
    lines = content.split("\n")
    for line in lines[:30]:
        line = line.strip()
        if not line: continue
        if line.startswith("#"):
            t = line.lstrip("# ").strip()
            if t and t.lower().replace(" ", "-").replace("&","").strip("-") != fname.replace(".md","").lower():
                return t[:100]
            continue
        if line.startswith(">"):
            return line.lstrip("> ").strip()[:100]
        if len(line) > 20 and not line.startswith("```") and not line.startswith("|"):
            return line[:100]
    return "(no description)"

KEYWORDS = {
  "agent": "Agent Operation", "memory": "Memory", "context": "Context Mgmt",
  "skill": "Skills", "hook": "Hooks", "audit": "Audit",
  "security": "Security", "savia": "Savia Core", "court": "Court/Review",
  "judge": "Court/Review", "tribunal": "Court/Review", "spec": "Spec Process",
  "sprint": "Sprint Process", "pbi": "PBI Process", "backlog": "Backlog",
  "profile": "Profile", "test": "Testing", "verify": "Verification",
  "verification": "Verification", "validation": "Validation",
  "emergency": "Emergency", "legal": "Legal", "compliance": "Compliance",
  "accessibility": "Accessibility", "pr-": "PR Process", "pm-": "PM Config",
  "banking": "Vertical: Banking", "education": "Vertical: Education",
  "healthcare": "Vertical: Healthcare", "telco": "Vertical: Telco",
  "ai-": "AI Governance", "ml-": "ML", "data-": "Data Governance",
  "governance": "Governance", "risk": "Risk", "eval": "Evaluation",
  "rule": "Meta Rules", "autonomous": "Autonomous Safety",
  "radical-": "Radical Honesty", "drift": "Drift", "mcp": "MCP",
  "orchestr": "Orchestration", "release": "Release", "deploy": "Release",
  "language": "Languages", "infra": "Infrastructure", "bridge": "Infrastructure",
  "shield": "Shield/Security", "travel": "Portability", "plugin": "Plugins",
  "truth": "Court/Review", "adoption": "Adoption", "graphrag": "GraphRAG",
  "receipts": "Receipts", "handoff": "Handoffs",
}

def categorize(fname):
    for kw, cat in KEYWORDS.items():
        if kw in fname: return cat
    return "Other"

cats = defaultdict(list)
for f in files:
    cats[categorize(f)].append((f, describe(f)))

print("# INDEX")
print()
print(f"Auto-generated. {len(files)} files / {len(cats)} cats. Regen: `bash scripts/rules-domain-index.sh`. CI check: `--check`. SPEC-115.")
print()
print("| Cat | File | Description |")
print("|---|---|---|")

for cat in sorted(cats.keys()):
    for fname, desc in sorted(cats[cat]):
        # Escape pipes in desc
        safe_desc = (desc or "").replace("|", "\\|")
        print(f"| {cat} | [`{fname}`](./{fname}) | {safe_desc} |")
PY

if $CHECK_MODE; then
  if diff -q "$INDEX" "$TMP_INDEX" >/dev/null 2>&1; then
    echo "OK: INDEX.md is up-to-date"
    exit 0
  else
    echo "FAIL: INDEX.md is stale — run 'bash scripts/rules-domain-index.sh' to regenerate" >&2
    diff "$INDEX" "$TMP_INDEX" | head -20 >&2
    exit 1
  fi
else
  cp "$TMP_INDEX" "$INDEX"
  echo "Generated $INDEX"
fi
