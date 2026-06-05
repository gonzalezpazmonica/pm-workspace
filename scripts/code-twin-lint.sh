#!/usr/bin/env bash
# code-twin-lint.sh — Valida Code Twin Files (CTF), CTI (index.md) y seeds JSONL
# Spec: SPEC-190 · AC-1, AC-2, AC-9
# Usage:
#   code-twin-lint.sh <ctf.md>              validate CTF (exit 0/2)
#   code-twin-lint.sh --index <index.md>    validate CTI (exit 0/2)
#   code-twin-lint.sh --seeds <dir>         validate seeds JSONL dir (exit 0/2)
# Exit: 0 OK | 2 INVALID
set -uo pipefail

VALID_LAYERS="domain application infrastructure api frontend cross-cutting"
MAX_TOKEN_BUDGET=800
MAX_CTI_TOKENS=300
MIN_SEED_ROWS=5
ERRORS=0

# --- helpers ----------------------------------------------------------------
frontmatter()  { awk '/^---$/{c++;if(c==2)exit;next} c==1{print}' "$1"; }
fm_field()     { frontmatter "$1" | grep -E "^${2}:" | head -1 \
                   | sed -E "s/^${2}:[[:space:]]*//" | tr -d '"'; }
fm_has_key()   { frontmatter "$1" | grep -qE "^${2}:"; }
# Approximate token count: chars / 4 (consistent with twin-linter.sh + SPEC-156 convention)
token_approx() { LC_NUMERIC=C awk '{c+=length($0)+1} END{printf "%d\n", c/4}' "$1"; }

mode="${1:-}"

# ── CTI (index) mode ─────────────────────────────────────────────────────────
if [[ "$mode" == "--index" ]]; then
  FILE="${2:-}"
  [[ -z "$FILE" ]] && { echo "Usage: code-twin-lint.sh --index <index.md>" >&2; exit 2; }
  [[ ! -f "$FILE" ]] && { echo "ERROR: file not found: $FILE" >&2; exit 2; }

  for field in total_modules total_token_cost; do
    fm_has_key "$FILE" "$field" || {
      echo "INVALID: CTI missing '${field}' in frontmatter" >&2; ERRORS=$((ERRORS+1));
    }
  done

  for col in module_id layer path provides tokens; do
    grep -qE "\|\s*${col}\s*\|" "$FILE" || {
      echo "INVALID: CTI table missing column '${col}'" >&2; ERRORS=$((ERRORS+1));
    }
  done

  tok=$(token_approx "$FILE")
  [[ "$tok" -gt "$MAX_CTI_TOKENS" ]] && {
    echo "INVALID: CTI token count ${tok} > ${MAX_CTI_TOKENS}" >&2; ERRORS=$((ERRORS+1));
  }

  [[ "$ERRORS" -gt 0 ]] && exit 2
  echo "OK (index): $FILE"
  exit 0
fi

# ── Seeds mode ───────────────────────────────────────────────────────────────
if [[ "$mode" == "--seeds" ]]; then
  DIR="${2:-}"
  [[ -z "$DIR" ]] && { echo "Usage: code-twin-lint.sh --seeds <dir>" >&2; exit 2; }
  [[ ! -d "$DIR" ]] && { echo "ERROR: directory not found: $DIR" >&2; exit 2; }

  # Locate schema.md — search parent dirs (seeds live inside db/seeds/)
  SCHEMA_MD=""
  for candidate in "${DIR}/../schema.md" "${DIR}/../../db/schema.md" "${DIR}/../db/schema.md"; do
    cpath="$(realpath "$candidate" 2>/dev/null || true)"
    [[ -n "$cpath" && -f "$cpath" ]] && { SCHEMA_MD="$cpath"; break; }
  done

  shopt -s nullglob
  jsonl_files=("${DIR}"/*.jsonl)
  [[ "${#jsonl_files[@]}" -eq 0 ]] && {
    echo "ERROR: no .jsonl files found in $DIR" >&2; exit 2;
  }

  for jsonl in "${jsonl_files[@]}"; do
    table="$(basename "$jsonl" .jsonl)"
    linecount=$(grep -c '' "$jsonl" 2>/dev/null || echo 0)

    [[ "$linecount" -lt "$MIN_SEED_ROWS" ]] && {
      echo "INVALID: ${table}.jsonl has ${linecount} lines (min ${MIN_SEED_ROWS})" >&2
      ERRORS=$((ERRORS+1)); continue
    }

    lineno=0
    while IFS= read -r line; do
      lineno=$((lineno+1))
      [[ -z "$line" ]] && continue
      echo "$line" | jq empty 2>/dev/null || {
        echo "INVALID: ${table}.jsonl line ${lineno} is not valid JSON" >&2
        ERRORS=$((ERRORS+1))
      }
    done < "$jsonl"

    # Cross-reference non-nullable fields from schema.md
    if [[ -n "$SCHEMA_MD" ]]; then
      non_nullable_file="$(mktemp)"
      in_table=0
      while IFS= read -r sline; do
        if echo "$sline" | grep -qiE "^##[[:space:]]+Table:[[:space:]]+${table}[[:space:]]*$"; then
          in_table=1; continue
        fi
        [[ "$in_table" -eq 1 ]] && echo "$sline" | grep -qE "^##" && break
        if [[ "$in_table" -eq 1 ]] && echo "$sline" | grep -qiE "\|\s*(false|NOT NULL)\s*\|"; then
          col=$(echo "$sline" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2}')
          [[ -n "$col" && "$col" != "column" && ! "$col" =~ ^-+$ ]] && echo "$col" >> "$non_nullable_file"
        fi
      done < "$SCHEMA_MD"

      first_line=$(grep -m1 '{' "$jsonl" || true)
      while IFS= read -r col; do
        echo "$first_line" | jq -e "has(\"$col\")" >/dev/null 2>&1 || {
          echo "INVALID: ${table}.jsonl missing non-nullable field '${col}' (line 1, col ${col})" >&2
          ERRORS=$((ERRORS+1))
        }
      done < "$non_nullable_file"
      rm -f "$non_nullable_file"
    fi
  done

  [[ "$ERRORS" -gt 0 ]] && exit 2
  echo "OK (seeds): $DIR"
  exit 0
fi

# ── CTF mode (default) ───────────────────────────────────────────────────────
FILE="$mode"
[[ -z "$FILE" ]] && {
  echo "Usage: code-twin-lint.sh <ctf.md> | --index <index.md> | --seeds <dir>" >&2; exit 2;
}
[[ ! -f "$FILE" ]] && { echo "ERROR: file not found: $FILE" >&2; exit 2; }

# 8 required frontmatter fields (AC-2)
for field in module_id layer version last_sync token_budget depends_on provides stale_after_days; do
  fm_has_key "$FILE" "$field" || {
    echo "INVALID: CTF missing '${field}' in frontmatter" >&2; ERRORS=$((ERRORS+1));
  }
done

# layer must be one of 6 valid values (AC-2)
layer=$(fm_field "$FILE" "layer")
if [[ -n "$layer" ]]; then
  valid=0
  for vl in $VALID_LAYERS; do [[ "$layer" == "$vl" ]] && { valid=1; break; }; done
  [[ "$valid" -eq 0 ]] && {
    echo "INVALID: layer '${layer}' not in valid set (${VALID_LAYERS})" >&2; ERRORS=$((ERRORS+1));
  }
fi

# token_budget ≤ 800 (AC-2)
budget=$(fm_field "$FILE" "token_budget")
if [[ -n "$budget" && "$budget" =~ ^[0-9]+$ ]]; then
  [[ "$budget" -gt "$MAX_TOKEN_BUDGET" ]] && {
    echo "INVALID: token_budget ${budget} > ${MAX_TOKEN_BUDGET}" >&2; ERRORS=$((ERRORS+1));
  }
fi

# DRAFT status rejected in production lint (Risk-3)
status=$(fm_field "$FILE" "status")
[[ "$status" == "DRAFT" ]] && {
  echo "INVALID: CTF status=DRAFT rejected in production lint" >&2; ERRORS=$((ERRORS+1));
}

[[ "$ERRORS" -gt 0 ]] && exit 2
echo "OK: $FILE"
exit 0
