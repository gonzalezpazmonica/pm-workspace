#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C
# agents-opencode-convert.sh — SPEC-127 Slice 2b-ii (final migration prep)
#
# Converts .claude/agents/*.md (Claude Code schema) into OpenCode v1.14
# compatible agent files written to .opencode/agents/*.md. Differences:
#
#   Claude Code                    OpenCode v1.14
#   --------------------------    --------------------------
#   tools: [Read, Bash, ...]       tools: { read: true, bash: true, ... }
#   color: lime                    color: "#9ACD32"   (named → hex)
#   model: claude-sonnet-4-6       model: claude-sonnet-4-6 (passthrough)
#   permission_level: L4           permission_level: L4 (passthrough)
#   max_context_tokens: ...        max_context_tokens: ... (passthrough)
#
# Modes: default print, --apply (write target tree), --check (drift detect).
#
# This converter is provider-agnostic (PV-06): it does NOT translate model
# names — that is done at runtime by `scripts/savia-env.sh` reading
# `~/.savia/preferences.yaml` model_alias. The output keeps canonical
# claude-X model names; OpenCode resolves via preferences.
#
# Reference: SPEC-127 Slice 2b-ii (agents converter)

ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SRC_DIR="${SRC_DIR:-${ROOT}/.claude/agents}"
DST_DIR="${DST_DIR:-${ROOT}/.opencode/agents}"
MODE="generate"

usage() {
  cat <<USG
Usage: agents-opencode-convert.sh [--apply | --check]

Modes:
  (default)  Print summary to stdout (dry run)
  --apply    Write converted .md files to ${DST_DIR}
  --check    Exit 1 if conversion would produce different content
USG
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) MODE="apply"; shift ;;
    --check) MODE="check"; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -d "$SRC_DIR" ]] || { echo "ERROR: source dir not found: $SRC_DIR" >&2; exit 3; }

# Named color → hex map (OpenCode v1.14 strict schema).
named_color_hex() {
  case "$1" in
    red)        echo "#FF0000" ;;
    green)      echo "#00CC00" ;;
    blue)       echo "#0066FF" ;;
    yellow)     echo "#FFD700" ;;
    cyan)       echo "#00CCCC" ;;
    magenta)    echo "#CC00CC" ;;
    purple)     echo "#9933CC" ;;
    orange)     echo "#FF8800" ;;
    pink)       echo "#FF66CC" ;;
    lime)       echo "#9ACD32" ;;
    teal)       echo "#008080" ;;
    navy)       echo "#000080" ;;
    olive)      echo "#808000" ;;
    maroon)     echo "#800000" ;;
    silver)     echo "#C0C0C0" ;;
    gray|grey)  echo "#808080" ;;
    white)      echo "#FFFFFF" ;;
    black)      echo "#000000" ;;
    *)
      # Already-hex pass-through, otherwise default neutral
      if [[ "$1" =~ ^#[0-9A-Fa-f]{6}$ ]]; then echo "$1"
      else echo "#808080"; fi
      ;;
  esac
}

# Convert a single agent file from Claude schema to OpenCode schema.
# Stdin = source content; stdout = converted content.
convert_one() {
  python3 - "$1" <<'PY'
import sys, re

path = sys.argv[1]
with open(path) as f:
    src = f.read()

# Split frontmatter
m = re.match(r"^---\n(.*?)\n---\n(.*)$", src, re.DOTALL)
if not m:
    sys.stderr.write(f"WARN: no frontmatter in {path}, passthrough\n")
    sys.stdout.write(src)
    sys.exit(0)

fm, body = m.group(1), m.group(2)

# Parse simple YAML frontmatter (key: value or key: [a, b, c])
lines = fm.splitlines()
out_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    s = line.strip()

    # tools inline array → tools object
    mt = re.match(r'^tools:\s*\[(.*)\]\s*$', s)
    if mt:
        items = [t.strip().strip('"\'') for t in mt.group(1).split(",") if t.strip()]
        out_lines.append("tools:")
        for tool in items:
            key = tool.lower()
            out_lines.append(f"  {key}: true")
        i += 1
        continue

    # tools YAML list (multi-line) → tools object
    if re.match(r'^tools:\s*$', s):
        # collect following lines that start with `  - ` or `- `
        items = []
        j = i + 1
        while j < len(lines):
            t = lines[j]
            mli = re.match(r'^\s*-\s*(\S.*)$', t)
            if mli:
                items.append(mli.group(1).strip().strip('"\''))
                j += 1
            else:
                break
        if items:
            out_lines.append("tools:")
            for tool in items:
                out_lines.append(f"  {tool.lower()}: true")
            i = j
            continue
        # no list items — passthrough
        out_lines.append(line)
        i += 1
        continue

    # color: name → hex
    mc = re.match(r'^color:\s*(\S+)\s*$', s)
    if mc:
        col = mc.group(1).strip('"\'')
        if col.startswith("#"):
            out_lines.append(f'color: "{col}"')
        else:
            named = {
                "red":"#FF0000","green":"#00CC00","blue":"#0066FF","yellow":"#FFD700",
                "cyan":"#00CCCC","magenta":"#CC00CC","purple":"#9933CC","orange":"#FF8800",
                "pink":"#FF66CC","lime":"#9ACD32","teal":"#008080","navy":"#000080",
                "olive":"#808000","maroon":"#800000","silver":"#C0C0C0","gray":"#808080",
                "grey":"#808080","white":"#FFFFFF","black":"#000000",
            }
            hex_val = named.get(col.lower(), "#808080")
            out_lines.append(f'color: "{hex_val}"')
        i += 1
        continue

    # passthrough other lines
    out_lines.append(line)
    i += 1

new_fm = "\n".join(out_lines)
sys.stdout.write(f"---\n{new_fm}\n---\n{body}")
PY
}

# Iterate, dispatching by mode.
applied=0
checked_drift=0
case "$MODE" in
  generate)
    count=0
    while IFS= read -r src; do
      count=$((count + 1))
    done < <(find "$SRC_DIR" -maxdepth 1 -type f -name "*.md" ! -name "README.md")
    echo "would convert $count agents from $SRC_DIR → $DST_DIR"
    ;;
  apply)
    mkdir -p "$DST_DIR"
    while IFS= read -r src; do
      bn=$(basename "$src")
      [[ "$bn" == "README.md" ]] && continue
      converted=$(convert_one "$src")
      printf '%s' "$converted" > "$DST_DIR/$bn"
      applied=$((applied + 1))
    done < <(find "$SRC_DIR" -maxdepth 1 -type f -name "*.md" | LC_ALL=C sort)
    echo "wrote $applied agents to $DST_DIR"
    ;;
  check)
    while IFS= read -r src; do
      bn=$(basename "$src")
      [[ "$bn" == "README.md" ]] && continue
      target="$DST_DIR/$bn"
      converted=$(convert_one "$src")
      if [[ ! -f "$target" ]]; then
        echo "drift: missing $target" >&2
        checked_drift=$((checked_drift + 1))
        continue
      fi
      if ! diff -q <(printf '%s' "$converted") "$target" >/dev/null 2>&1; then
        echo "drift: $bn differs" >&2
        checked_drift=$((checked_drift + 1))
      fi
    done < <(find "$SRC_DIR" -maxdepth 1 -type f -name "*.md" | LC_ALL=C sort)
    if [[ $checked_drift -gt 0 ]]; then
      echo "drift: $checked_drift agent(s) out of sync — run --apply" >&2
      exit 1
    fi
    echo "in sync"
    ;;
esac
