#!/usr/bin/env bash
# llms-txt-generate.sh — Genera docs/llms.txt y docs/llms-full.txt (SE-269 S5)
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LLMS_TXT="${LLMS_TXT:-$ROOT/docs/llms.txt}"
LLMS_FULL="${LLMS_FULL:-$ROOT/docs/llms-full.txt}"
SENSITIVE_PATHS="${SENSITIVE_PATHS:-$ROOT/config/sensitive-paths.yaml}"

generate_index() {
  cat > "$LLMS_TXT" <<'INDEXEOF'
# Savia — pm-workspace AI Context

## Que es Savia
Savia es un sistema agentico soberano de gestion de proyectos asistido por IA.
Opera bajo una constitucion operativa con enforcement, niveles de confidencialidad
(N1-N4b), federacion entre instancias y memoria persistente.

## Mapa de areas

### Nucleo operativo
- docs/critical-facts.md — Hechos invariantes del workspace
- CRITERIO.md — 33 criterios de decision (19 linea_roja)
- CONSTITUCION.md — Texto fundacional (articulos T1-T5)
- CLAUDE.md — Comandos y flujo de trabajo

### Arquitectura
- docs/rules/domain/agents-catalog.md — 81 agentes
- docs/rules/domain/pm-workflow.md — Cadencia scrum, comandos
- docs/rules/domain/language-packs.md — 16 lenguajes

### Sistema de memoria
- docs/memory-system.md — Memoria persistente (L0-L3, engrams)

### Seguridad
- docs/rules/domain/autonomous-safety.md — Modos autonomos
- docs/rules/domain/radical-honesty.md — Honestidad radical (Rule #24)

### Desarrollo
- docs/agent-teams-sdd.md — Orquestacion multi-agente

### Proyectos activos
- projects/ — Proyectos en desarrollo
INDEXEOF
  echo "docs/llms.txt generado ($(wc -c < "$LLMS_TXT") bytes)"
}

load_sensitive() {
  local blocked=(".savia/" "output/.memory" "config/pm-config.local" ".claude/profiles/active-user.md")
  if [[ -f "$SENSITIVE_PATHS" ]]; then
    while IFS= read -r line; do
      if [[ "$line" == *"path:"* ]]; then
        local p
        p=$(echo "$line" | sed 's/.*path: *//' | tr -d '"'"'" | xargs)
        [[ -n "$p" ]] && blocked+=("$p")
      fi
    done < "$SENSITIVE_PATHS"
  fi
  printf '%s\n' "${blocked[@]}"
}

generate_full() {
  local blocked_paths
  blocked_paths=$(load_sensitive)
  
  {
    echo "# Savia — Contexto Consolidado"
    echo "# Generado: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo ""

    local core_docs=("docs/critical-facts.md" "CRITERIO.md" "CONSTITUCION.md")
    
    for doc in "${core_docs[@]}"; do
      [[ ! -f "$ROOT/$doc" ]] && continue
      
      local is_blocked=false
      while IFS= read -r bp; do
        [[ "$doc" == "$bp"* ]] && is_blocked=true && break
      done <<< "$blocked_paths"
      $is_blocked && continue

      echo "## $doc"
      echo ""
      head -c 5000 "$ROOT/$doc" 2>/dev/null
      echo ""
    done

    # Specs index
    echo "## docs/specs/ (indice)"
    echo ""
    for spec in "$ROOT"/docs/specs/SE-*.spec.md; do
      [[ ! -f "$spec" ]] && continue
      local title
      title=$(head -1 "$spec" 2>/dev/null | sed 's/^# *//')
      echo "- $(basename "$spec"): $title"
    done
  } > "$LLMS_FULL"

  local final_size
  final_size=$(wc -c < "$LLMS_FULL")
  echo "docs/llms-full.txt generado ($final_size bytes)"
}

check_determinism() {
  generate_full > /dev/null 2>&1
  local hash1
  hash1=$(grep -v "Generado:" "$LLMS_FULL" 2>/dev/null | sha256sum | cut -d' ' -f1)
  generate_full > /dev/null 2>&1
  local hash2
  hash2=$(grep -v "Generado:" "$LLMS_FULL" 2>/dev/null | sha256sum | cut -d' ' -f1)
  if [[ "$hash1" == "$hash2" ]]; then
    echo "DETERMINISTA (hash sin timestamp)"
  else
    echo "NO_DETERMINISTA: $hash1 vs $hash2"
    return 1
  fi
}

case "${1:-generate}" in
  generate) generate_index && generate_full ;;
  index) generate_index ;;
  full) generate_full ;;
  check) check_determinism ;;
  *) echo "Uso: llms-txt-generate.sh [generate|index|full|check]"; exit 1 ;;
esac
