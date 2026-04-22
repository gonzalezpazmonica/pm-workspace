#!/bin/bash
set -uo pipefail
# validate-spec.sh — SPEC-071: Declarative spec validation without LLM
# Validates frontmatter fields, structure, and completeness of .spec.md files.
# Inspired by pCompiler schema validation.
# Usage: validate-spec.sh <spec-file> [--strict]

SPEC_FILE="${1:-}"
STRICT="${2:-}"
ERRORS=0
WARNINGS=0

if [[ -z "$SPEC_FILE" ]] || [[ ! -f "$SPEC_FILE" ]]; then
  echo "Usage: validate-spec.sh <spec-file> [--strict]" >&2
  exit 2
fi

err() { echo "  ERROR: $1"; ERRORS=$((ERRORS + 1)); }
warn() { echo "  WARN:  $1"; WARNINGS=$((WARNINGS + 1)); }
ok() { echo "  OK:    $1"; }

echo "Validating: $(basename "$SPEC_FILE")"
echo "---"

# ── 1. File basics ──
LINES=$(wc -l < "$SPEC_FILE")
if [[ "$LINES" -gt 150 ]]; then
  err "File exceeds 150 lines ($LINES lines)"
elif [[ "$LINES" -gt 120 ]]; then
  warn "File approaching limit ($LINES/150 lines)"
else
  ok "Line count: $LINES"
fi

if [[ "$LINES" -lt 10 ]]; then
  err "File too short ($LINES lines) — likely incomplete"
fi

# ── 2. Frontmatter / Header ──
# Accept YAML frontmatter (SE-054 canonical) OR legacy inline **Status**/**Date**.
if grep -qE '^# SPEC-[0-9]+' "$SPEC_FILE"; then
  ok "SPEC header present"
else
  err "Missing SPEC header (expected: # SPEC-NNN: Title)"
fi

# Status: YAML `status:` takes precedence over inline `**Status**:`.
if grep -qE '^status:\s*\S+' "$SPEC_FILE"; then
  STATUS=$(grep -oP '^status:\s*\K\S+' "$SPEC_FILE" | head -1)
  ok "Status (yaml): $STATUS"
elif grep -qiE '\*\*Status\*\*:' "$SPEC_FILE"; then
  STATUS=$(grep -oiP '\*\*Status\*\*:\s*\K\w+' "$SPEC_FILE" | head -1)
  ok "Status (inline): $STATUS"
else
  err "Missing status field (yaml 'status:' or inline '**Status**:')"
fi

# Date: YAML `date:` OR inline `**Date**:`.
if grep -qE '^date:\s*\S+' "$SPEC_FILE"; then
  ok "Date field (yaml) present"
elif grep -qiE '\*\*Date\*\*:' "$SPEC_FILE"; then
  ok "Date field (inline) present"
else
  warn "Missing date field (yaml 'date:' or inline '**Date**:')"
fi

# ── 3. Required sections ──
if grep -qiE '^## (Problem|Problema)' "$SPEC_FILE"; then
  ok "Problem section present"
else
  err "Missing ## Problem section"
fi

if grep -qiE '^## (Solution|Proposal|Propuesta|Solucion)' "$SPEC_FILE"; then
  ok "Solution section present"
else
  err "Missing ## Solution/Proposal section"
fi

if grep -qiE '^## (Files|Ficheros|Changes|Cambios)' "$SPEC_FILE"; then
  ok "Files/Changes section present"
else
  warn "Missing ## Files section (recommended)"
fi

if grep -qiE '^## (Acceptance|Criterios|Verificat)' "$SPEC_FILE"; then
  ok "Acceptance criteria present"
else
  if [[ "$STRICT" == "--strict" ]]; then
    err "Missing acceptance criteria (required in --strict mode)"
  else
    warn "Missing acceptance criteria section"
  fi
fi

# ── 4. Quality checks ──
if grep -qiE '(risk|riesgo)' "$SPEC_FILE"; then
  ok "Risk assessment mentioned"
else
  warn "No risk assessment found"
fi

# Check for ambiguous language
AMBIGUOUS=$(grep -ciE '(maybe|perhaps|somehow|quizas|tal vez|podria ser)' "$SPEC_FILE" 2>/dev/null || true)
AMBIGUOUS=$(echo "$AMBIGUOUS" | tr -d '[:space:]')
AMBIGUOUS="${AMBIGUOUS:-0}"
if [[ "$AMBIGUOUS" -gt 2 ]]; then
  warn "Ambiguous language detected ($AMBIGUOUS instances) — specs should be precise"
fi

# ── 5. Summary ──
echo "---"
if [[ "$ERRORS" -gt 0 ]]; then
  echo "RESULT: FAIL ($ERRORS errors, $WARNINGS warnings)"
  exit 1
elif [[ "$WARNINGS" -gt 0 ]]; then
  echo "RESULT: PASS with warnings ($WARNINGS warnings)"
  exit 0
else
  echo "RESULT: PASS"
  exit 0
fi
