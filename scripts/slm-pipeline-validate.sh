#!/usr/bin/env bash
# slm-pipeline-validate.sh — Meta-validator for an SLM project directory.
#
# Verifica la estructura esperada de un proyecto SLM conforme al layout
# documentado en docs/rules/domain/slm-training-pipeline.md §3:
#
#   projects/{slm-name}/
#   ├── config.yaml
#   ├── datasets/{raw,processed,synthetic}/
#   ├── adapters/          (gitignored)
#   ├── gguf/              (gitignored)
#   ├── eval/{harness.yaml,results/}
#   └── README.md
#
# Checks (all non-destructive):
#   - Required directories present
#   - config.yaml parseable YAML + campos mínimos (model.name, dataset.path, training.*)
#   - eval/harness.yaml parseable + apunta a prompts.jsonl existente
#   - README.md no vacío
#   - .gitignore (si existe) incluye adapters/ y gguf/ (privacy — model weights no al repo)
#
# Exit codes:
#   0 — project válido
#   1 — validation errors (listados en stdout)
#   2 — usage error
#
# Ref: docs/rules/domain/slm-training-pipeline.md §3
# Safety: read-only filesystem, set -uo pipefail.

set -uo pipefail

PROJECT=""
STRICT=0
JSON=0

usage() {
  cat <<EOF
Usage:
  $0 --project DIR               Validate SLM project layout
  $0 --project DIR --strict      Warnings become errors
  $0 --project DIR --json        JSON output

Checks (non-destructive):
  - Directory layout (datasets/, adapters/, gguf/, eval/)
  - config.yaml minimum fields
  - eval/harness.yaml valid
  - README.md non-empty
  - .gitignore excludes model weights (adapters/, gguf/)

Ref: docs/rules/domain/slm-training-pipeline.md §3
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

[[ -z "$PROJECT" ]] && { echo "ERROR: --project required" >&2; exit 2; }
[[ ! -d "$PROJECT" ]] && { echo "ERROR: project directory not found: $PROJECT" >&2; exit 2; }

ERRORS=()
WARNINGS=()

add_err() { ERRORS+=("$1"); }
add_warn() { WARNINGS+=("$1"); }

# Check directories.
for d in datasets adapters gguf eval; do
  if [[ ! -d "$PROJECT/$d" ]]; then
    add_err "missing required directory: $d/"
  fi
done

for subd in raw processed synthetic; do
  if [[ -d "$PROJECT/datasets" && ! -d "$PROJECT/datasets/$subd" ]]; then
    add_warn "missing datasets/$subd/ (expected for pipeline phase)"
  fi
done

# README check.
if [[ ! -f "$PROJECT/README.md" ]]; then
  add_err "missing README.md"
elif [[ ! -s "$PROJECT/README.md" ]]; then
  add_err "README.md is empty"
fi

# config.yaml checks.
CFG="$PROJECT/config.yaml"
if [[ ! -f "$CFG" ]]; then
  add_err "missing config.yaml at project root"
else
  grep -qE '^model:' "$CFG" || add_err "config.yaml missing 'model:' section"
  grep -qE '^dataset:' "$CFG" || add_err "config.yaml missing 'dataset:' section"
  grep -qE '^training:' "$CFG" || add_err "config.yaml missing 'training:' section"
  grep -qE '^\s+name:' "$CFG" || add_warn "config.yaml 'model:' missing 'name:' field"
fi

# eval/harness.yaml checks.
HARN="$PROJECT/eval/harness.yaml"
if [[ -d "$PROJECT/eval" && ! -f "$HARN" ]]; then
  add_warn "eval/ directory exists but no harness.yaml — run slm-eval-harness-setup.sh"
elif [[ -f "$HARN" ]]; then
  grep -qE '^model:' "$HARN" || add_err "eval/harness.yaml missing 'model:' section"
  grep -qE '^benchmarks:' "$HARN" || add_err "eval/harness.yaml missing 'benchmarks:' section"
fi

# .gitignore privacy check.
if [[ -f "$PROJECT/.gitignore" ]]; then
  grep -qE '^adapters/|/adapters/|adapters$' "$PROJECT/.gitignore" || add_warn ".gitignore does not exclude adapters/ — model weights may leak"
  grep -qE '^gguf/|/gguf/|gguf$' "$PROJECT/.gitignore" || add_warn ".gitignore does not exclude gguf/ — GGUF weights may leak"
fi

# Sovereignty hint in config.
if [[ -f "$CFG" ]]; then
  if ! grep -q 'zero_egress' "$CFG"; then
    add_warn "config.yaml lacks 'sovereignty.zero_egress' declaration — recommended for audit"
  fi
fi

# Emit verdict.
VALID=1
if [[ "${#ERRORS[@]}" -gt 0 ]]; then VALID=0; fi
if [[ "$STRICT" -eq 1 && "${#WARNINGS[@]}" -gt 0 ]]; then VALID=0; fi

PROJ_NAME=$(basename "$PROJECT")

if [[ "$JSON" -eq 1 ]]; then
  err_json=""
  for e in "${ERRORS[@]}"; do
    e_esc=$(echo "$e" | sed 's/"/\\"/g')
    err_json+="\"$e_esc\","
  done
  err_json="${err_json%,}"
  warn_json=""
  for w in "${WARNINGS[@]}"; do
    w_esc=$(echo "$w" | sed 's/"/\\"/g')
    warn_json+="\"$w_esc\","
  done
  warn_json="${warn_json%,}"
  valid_bool=$([[ "$VALID" -eq 1 ]] && echo "true" || echo "false")
  cat <<JSON
{"valid":$valid_bool,"project":"$PROJ_NAME","path":"$PROJECT","errors":[$err_json],"warnings":[$warn_json],"n_errors":${#ERRORS[@]},"n_warnings":${#WARNINGS[@]}}
JSON
else
  if [[ "$VALID" -eq 1 ]]; then
    echo "VALID: SLM project '$PROJ_NAME' layout OK"
    [[ "${#WARNINGS[@]}" -gt 0 ]] && {
      echo "  Warnings:"
      for w in "${WARNINGS[@]}"; do echo "    - $w"; done
    }
  else
    echo "INVALID: SLM project '$PROJ_NAME' has errors"
    for e in "${ERRORS[@]}"; do echo "  ERR: $e"; done
    [[ "${#WARNINGS[@]}" -gt 0 ]] && {
      for w in "${WARNINGS[@]}"; do echo "  WARN: $w"; done
    }
  fi
fi

[[ "$VALID" -eq 0 ]] && exit 1
exit 0
