#!/usr/bin/env bats
# tests/bats/test-sdd-research-lane.bats
# SE-370 — SDD Research lane: investigación auditable como fase del flujo SDD
# Ref: docs/specs/SE-370-sdd-research-lane.spec.md
# Cubre AC-0..AC-6. Tests herméticos via SDD_RESEARCH_SPECS_DIR (no tocan docs/specs).

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
LANE="$REPO_ROOT/scripts/sdd-research-lane.sh"

setup() {
  LANE_TMP="$(mktemp -d)"
  export SDD_RESEARCH_SPECS_DIR="$LANE_TMP"
}

teardown() {
  rm -rf "$LANE_TMP"
}

open_lane() {
  local change="$1" grant="documentation"
  if [[ "${2:-}" == "--grant" ]]; then
    grant="${3:-documentation}"
  elif [[ -n "${2:-}" ]]; then
    grant="$2"
  fi
  bash "$LANE" select "$change" --grant "$grant" > /dev/null
}

# ── AC-0: select requiere grant registrado (no auto) ─────────────────────────
@test "SE-370 AC-0: select sin --grant falla (el grant no es automático)" {
  run bash "$LANE" select SE-900
  [ "$status" -ne 0 ]
  [[ ! -f "$LANE_TMP/SE-900/research.md" ]]
}

@test "SE-370 AC-0: select con grant inválido falla" {
  run bash "$LANE" select SE-900 --grant full-internet
  [ "$status" -ne 0 ]
}

@test "SE-370 AC-0: select con grant registrado (documentation|open-web) abre la lane" {
  run bash "$LANE" select SE-900 --grant documentation
  [ "$status" -eq 0 ]
  grep -q -- '- scope: documentation' "$LANE_TMP/SE-900/research.md"
  grep -q -- '- granted_by: human' "$LANE_TMP/SE-900/research.md"
  run bash "$LANE" select SE-901 --grant open-web
  [ "$status" -eq 0 ]
  grep -q -- '- scope: open-web' "$LANE_TMP/SE-901/research.md"
}

# ── AC-1: log añade claim→source; sin source → PENDIENTE ─────────────────────
@test "SE-370 AC-1: log añade claim con source al artefacto" {
  open_lane SE-900
  run bash "$LANE" log SE-900 --claim "X es la vía estándar" --source "docs/specs/SE-370-sdd-research-lane.spec.md" --fetched "2026-09-01"
  [ "$status" -eq 0 ]
  grep -q -- '- Claim: "X es la vía estándar" → Source: docs/specs/SE-370-sdd-research-lane.spec.md · fetched: 2026-09-01' "$LANE_TMP/SE-900/research.md"
}

@test "SE-370 AC-1: log sin --source marca el claim PENDIENTE" {
  open_lane SE-900
  run bash "$LANE" log SE-900 --claim "afirmación sin verificar"
  [ "$status" -eq 0 ]
  grep -q -- '→ Source: PENDIENTE' "$LANE_TMP/SE-900/research.md"
}

# ── AC-2: contradict registra la contradicción ───────────────────────────────
@test "SE-370 AC-2: contradict registra la contradicción en el artefacto" {
  open_lane SE-900
  run bash "$LANE" contradict SE-900 --a "docs/A.md" --b "docs/B.md"
  [ "$status" -eq 0 ]
  grep -q 'docs/A.md' "$LANE_TMP/SE-900/research.md"
  grep -q 'docs/B.md' "$LANE_TMP/SE-900/research.md"
  grep -q '→ abierta' "$LANE_TMP/SE-900/research.md"
  # la contradicción cae en su sección, no en Claims
  run awk '/^## Contradicciones/{f=1;next} /^## /{f=0} f && /docs\/A.md/' "$LANE_TMP/SE-900/research.md"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

# ── AC-3: close falla con claims sin fuente y sin marcar ─────────────────────
@test "SE-370 AC-3: close pasa con claims con fuente" {
  open_lane SE-900
  bash "$LANE" log SE-900 --claim "con fuente" --source "README.md" > /dev/null
  run bash "$LANE" close SE-900
  [ "$status" -eq 0 ]
  grep -q -- '- cerrado:' "$LANE_TMP/SE-900/research.md"
}

@test "SE-370 AC-3: close pasa con claim PENDIENTE (incertidumbre explícita, no oculta)" {
  open_lane SE-900
  bash "$LANE" log SE-900 --claim "sin verificar" > /dev/null
  run bash "$LANE" close SE-900
  [ "$status" -eq 0 ]
}

@test "SE-370 AC-3: close falla si hay claim sin fuente y sin marcar" {
  open_lane SE-900
  bash "$LANE" log SE-900 --claim "con fuente" --source "README.md" > /dev/null
  # simula edición manual: claim sin source y sin marca PENDIENTE
  sed -i 's|_Sin incertidumbre registrada_|_Sin incertidumbre registrada_\n- Claim: "editado a mano sin fuente"|' "$LANE_TMP/SE-900/research.md"
  run bash "$LANE" close SE-900
  [ "$status" -ne 0 ]
  [[ ! -f "$LANE_TMP/SE-900/research.md" ]] || ! grep -q -- '- cerrado:' "$LANE_TMP/SE-900/research.md"
}

@test "SE-370: log tras close falla (el gate bloquea la implementación sin re-apertura)" {
  open_lane SE-900
  bash "$LANE" close SE-900 > /dev/null
  run bash "$LANE" log SE-900 --claim "tarde" --source "README.md"
  [ "$status" -ne 0 ]
}

# ── AC-4: freshness presente en cada claim ────────────────────────────────────
@test "SE-370 AC-4: log sin --fetched estampa freshness (hoy UTC)" {
  open_lane SE-900
  run bash "$LANE" log SE-900 --claim "claim fresco" --source "README.md"
  [ "$status" -eq 0 ]
  local today
  today="$(date -u +%F)"
  grep -q "fetched: $today" "$LANE_TMP/SE-900/research.md"
}

@test "SE-370 AC-4: validate falla si un claim no tiene fetched" {
  open_lane SE-900
  bash "$LANE" log SE-900 --claim "ok" --source "README.md" > /dev/null
  sed -i 's/ · fetched: [0-9-]*//' "$LANE_TMP/SE-900/research.md"
  run bash "$LANE" validate SE-900
  [ "$status" -ne 0 ]
}

# ── AC-5: artefacto persistido bajo docs/specs/<change>/research.md ──────────
@test "SE-370 AC-5: el artefacto persiste en <specs>/<change>/research.md" {
  open_lane SE-900 --grant open-web
  [ -f "$LANE_TMP/SE-900/research.md" ]
  # el layout por defecto es docs/specs/<change>/research.md
  grep -q 'docs/specs' "$LANE"
  grep -q '^# Research — SE-900' "$LANE_TMP/SE-900/research.md"
}

@test "SE-370 AC-5: el artefacto sigue el formato de la spec (secciones)" {
  open_lane SE-900
  local art="$LANE_TMP/SE-900/research.md"
  grep -q '^## Preguntas' "$art"
  grep -q '^## Grant' "$art"
  grep -q '^## Claims → Sources' "$art"
  grep -q '^## Contradicciones' "$art"
  grep -q '^## Incertidumbre' "$art"
  grep -q '^## Freshness' "$art"
}

# ── AC-6: CRIT-001 — filtro por nivel, N3+ jamás se registra ─────────────────
@test "SE-370 AC-6: log con nivel N3 es rechazado (CRIT-001)" {
  open_lane SE-900
  run bash "$LANE" log SE-900 --claim "dato personal del usuario" --source "local.md" --level N3
  [ "$status" -ne 0 ]
  [[ ! -f "$LANE_TMP/SE-900/research.md" ]] || ! grep -q 'dato personal del usuario' "$LANE_TMP/SE-900/research.md"
}

@test "SE-370 AC-6: log con niveles N4 y N4b es rechazado" {
  open_lane SE-900
  run bash "$LANE" log SE-900 --claim "dato de cliente" --source "local.md" --level N4
  [ "$status" -ne 0 ]
  run bash "$LANE" log SE-900 --claim "dato de equipo" --source "local.md" --level N4b
  [ "$status" -ne 0 ]
  [[ ! -f "$LANE_TMP/SE-900/research.md" ]] || ! grep -qE 'dato de cliente|dato de equipo' "$LANE_TMP/SE-900/research.md"
}

@test "SE-370 AC-6: niveles N1 y N2 sí se registran" {
  open_lane SE-900
  run bash "$LANE" log SE-900 --claim "dato público" --source "README.md" --level N1
  [ "$status" -eq 0 ]
  run bash "$LANE" log SE-900 --claim "dato de org" --source "interno.md" --level N2
  [ "$status" -eq 0 ]
  grep -q '· level: N1' "$LANE_TMP/SE-900/research.md"
  grep -q '· level: N2' "$LANE_TMP/SE-900/research.md"
}

# ── validate: coherencia (grant, refs locales, freshness) ────────────────────
@test "SE-370: validate pasa en artefacto coherente y falla con ref local inexistente (grant documentation)" {
  open_lane SE-900
  bash "$LANE" log SE-900 --claim "c1" --source "README.md" > /dev/null
  run bash "$LANE" validate SE-900
  [ "$status" -eq 0 ]
  bash "$LANE" log SE-900 --claim "c2" --source "no/existe/ref.md" > /dev/null
  run bash "$LANE" validate SE-900
  [ "$status" -ne 0 ]
}

@test "SE-370: validate no exige existencia de refs URL (grant open-web)" {
  open_lane SE-900 --grant open-web
  bash "$LANE" log SE-900 --claim "web" --source "https://example.com/doc" > /dev/null
  run bash "$LANE" validate SE-900
  [ "$status" -eq 0 ]
}

@test "SE-370: --validate es alias de validate" {
  open_lane SE-900
  run bash "$LANE" --validate SE-900
  [ "$status" -eq 0 ]
}
