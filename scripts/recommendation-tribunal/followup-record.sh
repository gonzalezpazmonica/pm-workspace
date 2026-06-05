#!/usr/bin/env bash
# followup-record.sh — SPEC-125 Slice 3: Memory feedback loop.
#
# Records a user's reaction to a tribunal verdict on a previous turn. When
# Savia's output included a [TRIBUNAL: WARN] or [TRIBUNAL: VETO] banner and
# the user pushes back ("no, era correcto", "te equivocaste, no debi hacerte
# caso") this is the calibration signal — capture it on the original audit
# record so calibrate.sh can derive feedback memory in a later batch.
#
# Contract:
#   --hash <draft_hash>          REQUIRED  prefix or full sha256 of the draft
#   --text "<user reply>"        REQUIRED  raw next-turn user reply (any locale)
#   --classification (auto|fp|fn|neutral)  default: auto (run heuristic below)
#   --audit-dir <path>           override of $RECOMMENDATION_TRIBUNAL_AUDIT_DIR
#                                (default output/recommendation-tribunal/)
#
# Heuristic (--classification auto):
#   "fp"  (false positive) — tribunal vetoed but user says it was wrong to veto.
#         Patterns: "vetaste de mas", "no era para tanto", "estaba bien",
#         "lo bloqueaste mal", "era correcto", "false positive".
#   "fn"  (false negative) — tribunal passed but user reports the advice was bad.
#         Patterns: "te equivocaste", "no debi hacerte caso", "se te paso",
#         "estaba mal", "false negative", "rompio".
#   "neutral" — neither match. No calibration signal.
#
# Spec: docs/propuestas/SPEC-125-recommendation-tribunal-realtime.md sec 6 + 8.
# Side effect: mutates the matching JSON record under audit-dir adding fields
#   user_response_followup       (string, raw text)
#   user_response_classification (one of: fp|fn|neutral)
#   user_response_recorded_at    (ISO-8601 UTC)
# Idempotent: re-recording overrides previous value (last-write-wins by ts).
#
# Pattern: shadow-only by default — does NOT mutate auto-memory directly.
# That belongs to calibrate.sh which batches multiple records.

set -uo pipefail

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
AUDIT_DIR="${RECOMMENDATION_TRIBUNAL_AUDIT_DIR:-$ROOT_DIR/output/recommendation-tribunal}"

usage() {
  cat <<EOF
Usage: $0 --hash <draft_hash> --text "<user reply>"
          [--classification (auto|fp|fn|neutral)]
          [--audit-dir <path>]
EOF
  exit 2
}

HASH=""
TEXT=""
CLASSIFICATION="auto"

while [ $# -gt 0 ]; do
  case "$1" in
    --hash)            HASH="${2:-}"; shift 2 ;;
    --text)            TEXT="${2:-}"; shift 2 ;;
    --classification)  CLASSIFICATION="${2:-}"; shift 2 ;;
    --audit-dir)       AUDIT_DIR="${2:-}"; shift 2 ;;
    -h|--help)         usage ;;
    *)                 echo "ERROR: unknown argument: $1" >&2; usage ;;
  esac
done

[ -n "$HASH" ] || { echo "ERROR: --hash is required" >&2; usage; }
[ -n "$TEXT" ] || { echo "ERROR: --text is required" >&2; usage; }
[ -d "$AUDIT_DIR" ] || { echo "ERROR: audit-dir missing: $AUDIT_DIR" >&2; exit 3; }

case "$CLASSIFICATION" in
  auto|fp|fn|neutral) ;;
  *) echo "ERROR: invalid --classification: $CLASSIFICATION" >&2; exit 2 ;;
esac

classify_auto() {
  local txt_lower
  txt_lower=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  local fp_patterns="vetaste de mas|no era para tanto|estaba bien|lo bloqueaste mal|era correcto|false positive|fp:|esta mal vetado|sobreactua"
  local fn_patterns="te equivocaste|no debi hacerte caso|se te paso|estaba mal|false negative|rompio|fallo en produccion|fn:|deberia haber vetado"
  if printf '%s' "$txt_lower" | grep -E -q "$fp_patterns"; then
    echo "fp"
  elif printf '%s' "$txt_lower" | grep -E -q "$fn_patterns"; then
    echo "fn"
  else
    echo "neutral"
  fi
}

if [ "$CLASSIFICATION" = "auto" ]; then
  CLASSIFICATION=$(classify_auto "$TEXT")
fi

target_file=""
while IFS= read -r -d '' jf; do
  if grep -qE "\"draft_hash\"[[:space:]]*:[[:space:]]*\"${HASH}" "$jf" 2>/dev/null; then
    target_file="$jf"
    break
  fi
done < <(find "$AUDIT_DIR" -mindepth 2 -maxdepth 2 -type f -name '*.json' -print0 2>/dev/null)

if [ -z "$target_file" ]; then
  echo "ERROR: no audit record found for hash prefix: $HASH" >&2
  exit 4
fi

ts=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
escaped_text=$(printf '%s' "$TEXT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read())[1:-1])')

python3 - "$target_file" "$escaped_text" "$CLASSIFICATION" "$ts" <<'PY'
import json, sys, pathlib
path = pathlib.Path(sys.argv[1])
text, classif, ts = sys.argv[2], sys.argv[3], sys.argv[4]
data = json.loads(path.read_text(encoding="utf-8"))
data["user_response_followup"] = text
data["user_response_classification"] = classif
data["user_response_recorded_at"] = ts
path.write_text(json.dumps(data, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"recorded: hash={data.get('draft_hash','?')[:12]} class={classif} file={path.name}")
PY
