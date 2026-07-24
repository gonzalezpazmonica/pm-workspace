#!/usr/bin/env bash
# llms-txt-generate.sh — Genera docs/llms.txt y docs/llms-full.txt (SE-269 S5)
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LLMS_TXT="${LLMS_TXT:-$ROOT/docs/llms.txt}"
LLMS_FULL="${LLMS_FULL:-$ROOT/docs/llms-full.txt}"

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

generate_full() {
  python3 -c '
import os, sys
from datetime import datetime, timezone

root = os.environ.get("ROOT", ".")
llms_full = os.environ.get("LLMS_FULL", os.path.join(root, "docs/llms-full.txt"))
sensitive_cfg = os.environ.get("SENSITIVE_CFG", os.path.join(root, "config/sensitive-paths.yaml"))

blocked = []
if os.path.exists(sensitive_cfg):
    with open(sensitive_cfg) as f:
        for line in f:
            line = line.strip()
            if line:
                blocked.append(line)

core_docs = [
    "docs/critical-facts.md",
    "CRITERIO.md",
    ".claude/CONSTITUCION.md",
    "CLAUDE.md",
    ".claude/profiles/savia.md",
    "docs/rules/domain/agents-catalog.md",
    "docs/rules/domain/autonomous-safety.md",
    "docs/memory-system.md",
    "docs/agent-teams-sdd.md",
]

lines = []
lines.append("# Savia — Contexto Consolidado")
ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
lines.append("# Generado: " + ts)
lines.append("")

for doc_path in core_docs:
    full_path = os.path.join(root, doc_path)
    if not os.path.isfile(full_path):
        continue

    is_blocked = any(doc_path.startswith(bp) for bp in blocked)
    if is_blocked:
        continue

    lines.append("## " + doc_path)
    lines.append("")
    with open(full_path) as f:
        content = f.read(15000)
    lines.append(content.rstrip())
    lines.append("")

specs_dir = os.path.join(root, "docs/specs")
lines.append("## docs/specs/ (indice)")
lines.append("")
if os.path.isdir(specs_dir):
    for fname in sorted(os.listdir(specs_dir)):
        if fname.startswith("SE-") and fname.endswith(".spec.md"):
            fpath = os.path.join(specs_dir, fname)
            title = ""
            with open(fpath) as f:
                title = f.readline().strip().lstrip("# ")
            lines.append("- " + fname + ": " + title)

full_text = "\n".join(lines)

for bp in blocked:
    if bp:
        full_text = full_text.replace(bp, "[REDACTED]")

with open(llms_full, "w") as f:
    f.write(full_text)
print("docs/llms-full.txt generado (" + str(len(full_text)) + " bytes)")
'
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
