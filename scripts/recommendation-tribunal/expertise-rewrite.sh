#!/usr/bin/env bash
# expertise-rewrite.sh — SPEC-125 Slice 2: Asymmetric-expertise rewrite.
#
# When the expertise-asymmetry-judge classifies a draft as falling into a
# `blind` audit area (the active user explicitly cannot evaluate the recommendation
# on technical merits), this script rewrites the draft to add three obligatory
# sections that preserve the user's epistemic sovereignty:
#
#   1. **Por qué creo esto** — explicit reasoning chain
#   2. **Alternativas que descarté** — counterfactual options
#   3. **Cómo verificar tú misma** — concrete verification commands/queries
#
# This is the §5 rewrite phase from SPEC-125. It does NOT decide audit_level
# (that is the expertise-asymmetry-judge's job); it only applies the rewrite
# when the verdict declares mode=blind.
#
# Usage:
#   echo "$DRAFT" | expertise-rewrite.sh \
#       --audit-level blind \
#       --reasoning "$REASONING" \
#       --alternatives "$ALTERNATIVES_JSON" \
#       --verification "$VERIFICATION_STEPS" \
#       --domain postgres-tuning
#
# Or invoked from aggregate.sh output:
#   echo "$DRAFT" | expertise-rewrite.sh --judge-json /path/to/expertise-verdict.json
#
# Exit codes:
#   0  ok — rewritten draft on stdout (or original if audit_level != blind)
#   2  usage / args invalid
#   3  judge JSON file missing/unreadable
#   4  malformed judge JSON
#
# Reference: SPEC-125 § 5 (Asymmetric-expertise mode).

set -uo pipefail

AUDIT_LEVEL=""
REASONING=""
ALTERNATIVES=""
VERIFICATION=""
DOMAIN=""
JUDGE_JSON=""

usage() {
  sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
  exit 2
}

# ── Argument parsing ────────────────────────────────────────────────────────

if [[ $# -lt 1 ]]; then
  usage
fi

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    -h|--help) usage ;;
    --audit-level) AUDIT_LEVEL="${2:-}"; shift 2 ;;
    --reasoning) REASONING="${2:-}"; shift 2 ;;
    --alternatives) ALTERNATIVES="${2:-}"; shift 2 ;;
    --verification) VERIFICATION="${2:-}"; shift 2 ;;
    --domain) DOMAIN="${2:-}"; shift 2 ;;
    --judge-json) JUDGE_JSON="${2:-}"; shift 2 ;;
    *) echo "ERROR: unknown argument '$1'" >&2; usage ;;
  esac
done

# ── Resolve from judge JSON when provided ───────────────────────────────────

if [[ -n "$JUDGE_JSON" ]]; then
  if [[ ! -r "$JUDGE_JSON" ]]; then
    echo "ERROR: judge JSON not readable: $JUDGE_JSON" >&2
    exit 3
  fi
  parsed=$(python3 -c "
import json,sys
try:
  with open('$JUDGE_JSON') as f: d = json.load(f)
  print(d.get('audit_level','medium'))
  print(d.get('reasoning',''))
  print(d.get('domain',''))
  alts = d.get('alternatives_considered',[])
  if isinstance(alts, list):
    print('|'.join(json.dumps(a) for a in alts))
  else:
    print('')
  vrf = d.get('verification_steps',[])
  if isinstance(vrf, list):
    print('|'.join(vrf))
  else:
    print(str(vrf))
except Exception as e:
  print(f'PARSE_ERROR:{e}', file=sys.stderr); sys.exit(4)
" 2>&1)
  ec=$?
  if [[ $ec -ne 0 ]]; then
    echo "ERROR: malformed judge JSON: $parsed" >&2
    exit 4
  fi
  AUDIT_LEVEL=$(printf '%s\n' "$parsed" | sed -n '1p')
  REASONING=$(printf '%s\n' "$parsed" | sed -n '2p')
  DOMAIN=$(printf '%s\n' "$parsed" | sed -n '3p')
  ALTERNATIVES=$(printf '%s\n' "$parsed" | sed -n '4p')
  VERIFICATION=$(printf '%s\n' "$parsed" | sed -n '5p')
fi

# ── Read draft from stdin ───────────────────────────────────────────────────

DRAFT=$(cat)

# Empty draft is a no-op (preserves Slice 1 hook contract).
if [[ -z "$DRAFT" ]]; then
  printf '%s' "$DRAFT"
  exit 0
fi

# ── Skip rewrite when not blind ─────────────────────────────────────────────
#
# Only `blind` triggers the rewrite. low/medium/high/missing all pass through.
# Spec § 5: "Cuando una recomendación cae en un área `blind`, el
# expertise-asymmetry-judge re-escribe el output".
if [[ "$AUDIT_LEVEL" != "blind" ]]; then
  printf '%s' "$DRAFT"
  exit 0
fi

# ── Build rewrite ───────────────────────────────────────────────────────────

calibration_banner="[CALIBRATION: blind-area${DOMAIN:+ — $DOMAIN}] Esta recomendación cae en un área que has marcado como no-auditable. Las secciones siguientes son obligatorias para que puedas decidir sin depender de mi criterio."

# Section 1 — Por qué creo esto (always present, even if reasoning empty)
section_why="**Por qué creo esto**:"$'\n'
if [[ -n "$REASONING" ]]; then
  section_why+="$REASONING"
else
  section_why+="(razonamiento no proporcionado por el juez — pedir explicación explícita antes de actuar)"
fi

# Section 2 — Alternativas que descarté
section_alts="**Alternativas que descarté**:"$'\n'
if [[ -n "$ALTERNATIVES" ]]; then
  # ALTERNATIVES is pipe-separated JSON objects or plain lines
  IFS='|' read -ra alt_arr <<< "$ALTERNATIVES"
  for a in "${alt_arr[@]}"; do
    [[ -z "$a" ]] && continue
    # Try JSON decode; fall back to literal
    decoded=$(python3 -c "
import json,sys
try:
  d = json.loads('''$a''')
  if isinstance(d, dict):
    opt = d.get('option', d.get('label', ''))
    rej = d.get('rejected_because', d.get('reason', ''))
    print(f'- {opt}: {rej}' if opt else f'- {d}')
  else:
    print(f'- {d}')
except Exception:
  print('- $a')
" 2>/dev/null) || decoded="- $a"
    section_alts+="$decoded"$'\n'
  done
else
  section_alts+="(ninguna alternativa registrada — pedir comparativa antes de actuar)"$'\n'
fi

# Section 3 — Cómo verificar tú misma
section_verify="**Cómo verificar tú misma**:"$'\n'
if [[ -n "$VERIFICATION" ]]; then
  IFS='|' read -ra vrf_arr <<< "$VERIFICATION"
  for v in "${vrf_arr[@]}"; do
    [[ -z "$v" ]] && continue
    section_verify+="- $v"$'\n'
  done
else
  section_verify+="(no se han propuesto pasos de verificación — el juez debió incluirlos; pedirlos antes de actuar)"$'\n'
fi

# ── Emit mutated draft ──────────────────────────────────────────────────────

printf '%s\n\n---\n%s\n\n%s\n%s\n%s\n' \
  "$DRAFT" \
  "$calibration_banner" \
  "$section_why" \
  "$section_alts" \
  "$section_verify"

exit 0
