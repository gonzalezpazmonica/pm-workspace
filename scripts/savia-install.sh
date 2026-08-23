#!/usr/bin/env bash
# savia-install.sh — SPEC-CONSOLIDACION R4: bootstrap central idempotente.
#
# Orquesta todos los instaladores de Savia de forma idempotente y registra
# cada paso en el log de instalación (R3) para que el siguiente arranque
# pueda auto-corregir lo que haya fallado.
#
# Pasos:
#   1. memory-deps            (apt/pip deps opcionales — salto silencioso si no)
#   2. automations init-defaults + orquestador diario (loops "saltan solos")
#   3. opencode-install --link-only  (plugin savia-gates)
#   4. setup-merge-drivers     (reglas merge para .confidentiality-signature)
#   5. savia-memory-bootstrap  (store canónico ../.savia-memory)
#
# CRIT-001: nunca contacta proveedores cloud; si algo requiere red (deps,
# opencode download) y falla, se registra y se continua (la funcionalidad
# local crítica no depende de ello).
#
# Usage:
#   savia-install.sh [--skip-ollama] [--dry-run] [--log] [--quiet]
# Exit: 0 ok (idempotente) · 2 usage · 3 fallo crítico con log
set -uo pipefail

ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT" || exit 2
LOG="$ROOT/scripts/savia-bootstrap-log.sh"
DRY_RUN=0
QUIET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-ollama) SKIP_OLLAMA=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --quiet) QUIET=1 ;;
    --log) : ;;
    *) echo "usage: $0 [--skip-ollama] [--dry-run] [--quiet]" >&2; exit 2 ;;
  esac
  shift
done

say() { [[ "$QUIET" -eq 1 ]] || echo "$*"; }
log() {
  local step="$1" code="$2" msg="${3:-}"
  [[ -x "$LOG" ]] && bash "$LOG" write "$step" "$code" "$msg" >/dev/null 2>&1 || true
}
run_step() {
  # run_step STEP DESC cmd...
  local step="$1" desc="$2"; shift 2
  say "── $step: $desc"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    say "   DRY-RUN: $*"
    log "$step" 0 "dry-run"
    return 0
  fi
  if "$@" >/dev/null 2>&1; then
    say "   ✓"
    log "$step" 0 "$desc"
  else
    say "   ⚠ fail (registrado, no bloquea)"
    log "$step" 1 "$desc"
  fi
}

log "savia-install" 0 "start"
say "Savia install — bootstrap central (idempotente)"

# 1. memory deps opcionales
if [[ -x "$ROOT/scripts/install-memory-deps.sh" ]]; then
  run_step "memory-deps" "deps de memoria (vector)" bash "$ROOT/scripts/install-memory-deps.sh"
else
  log "memory-deps" 2 "script ausente"
fi

# 2. automations defaults + orquestador diario ("saltan solos")
if [[ -x "$ROOT/scripts/savia-automations.sh" ]]; then
  run_step "automations-defaults" "tareas por defecto" bash "$ROOT/scripts/savia-automations.sh" init-defaults
  # orquestador diario (P8): cron humano "daily 08:30" ya normalizado por R1
  have_orch=$("$ROOT/scripts/savia-automations.sh" list 2>/dev/null | grep -c "sagi-orquestador-diario" || true)
  if [[ "$have_orch" -eq 0 ]]; then
    run_step "orchestrator-daily" "orquestador SAGI diario (LLM local)" \
      bash -c "SAVIA_AUTOMATIONS_DIR='$ROOT/.savia/automations' $ROOT/scripts/savia-automations.sh create --name sagi-orquestador-diario --schedule 'daily 08:30' --instructions 'Ejecutar el orquestador SAGI con LLM local (bash scripts/savia-orchestrator.sh --task \"consolidar aprendizaje\" --decide llm --iterations 1). CRIT-001: solo Ollama 127.0.0.1:11434, NUNCA cloud.' || true"
  else
    log "orchestrator-daily" 0 "ya existe"
  fi
  # materializar next_run
  run_step "automations-compute" "recalcular next_run (R1)" bash "$ROOT/scripts/savia-automations.sh" compute
else
  log "automations" 2 "script ausente"
fi

# 3. plugin opencode savia-gates
if [[ -x "$ROOT/scripts/opencode-install.sh" ]]; then
  run_step "opencode-link" "plugin savia-gates" bash "$ROOT/scripts/opencode-install.sh" --link-only
else
  log "opencode" 2 "script ausente"
fi

# 4. merge drivers
if [[ -x "$ROOT/scripts/setup-merge-drivers.sh" ]]; then
  run_step "merge-drivers" "driver .confidentiality-signature" bash "$ROOT/scripts/setup-merge-drivers.sh"
else
  log "merge-drivers" 2 "script ausente"
fi

# 5. memory bootstrap (store canónico)
if [[ -x "$ROOT/scripts/savia-memory-bootstrap.sh" ]]; then
  run_step "memory-bootstrap" "store canónico ../.savia-memory" bash "$ROOT/scripts/savia-memory-bootstrap.sh"
else
  log "memory-bootstrap" 2 "script ausente"
fi

log "savia-install" 0 "done"
say ""
say "Savia install completado. Ver: output/install-logs/ o ~/.savia/install.log"
exit 0