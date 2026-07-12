# Spec: Feature — Blast Radius Command (CodeFlow-inspired)

**Task ID:**        SE-260
**PBI padre:**      SE-165 — workspace-health v2
**Sprint:**         2026-07
**Fecha creacion:** 2026-07-11
**Creado por:**     Savia (research: CodeFlow blast radius analysis)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estado:**         IMPLEMENTED (PR #902, 2026-07-11)

**Effort Estimation (Dual Model):**
| Dimension | Value |
|-----------|-------|
| Agent effort | 45 min |
| Human effort | 1h |
| Review effort | 15 min |
| Context risk | low |
| Agent-capable | yes |
| Fallback | bash puro, sin deps externas |

**OpenCode Implementation Plan:**
| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Script | `scripts/blast-radius.sh` | Mismo script (bash) |
| Skill | `.claude/skills/codebase-map/` | `.opencode/skills/codebase-map/` (symlink) |
| MCP | codebase-memory-mcp trace_path | Mismo MCP |

**Portability classification:** PURE_BASH (usa MCP como fallback opcional)

---

## 1. Contexto y Objetivo

CodeFlow responde "si cambio este fichero, ¿qué se rompe?" con un grafo interactivo.
Savia tiene `codebase-memory-mcp` con `trace_path` que ya computa dependencias,
y `SPEC-IMPACT-ANALYSIS` que define un informe de impacto pre-slice. Pero no existe
un comando simple y directo que responda a la pregunta "¿blast radius de este fichero?"
para uso interactivo por el operador.

**Objetivo:** Crear `scripts/blast-radius.sh` que, dado un fichero o lista de ficheros,
emite un informe tabular de ficheros impactados con riesgo estimado. Usa
`codebase-memory-mcp` como fuente primaria y fallback a grep de imports si el MCP
no esta disponible.

**Criterios de Aceptacion:**
- [ ] `blast-radius.sh <file>` emite tabla de dependientes directos y transitivos
- [ ] `blast-radius.sh --depth N <file>` controla profundidad de trazado
- [ ] `blast-radius.sh --json <file>` emite JSON para consumo por scripts
- [ ] Fallback a grep de imports cuando MCP no responde
- [ ] Output integrable en `workspace-health.sh` v2 (SE-261)
- [ ] Tiempo de ejecucion <3s con MCP, <10s con grep fallback

---

## 2. Contrato Tecnico

### 2.1 Interfaz

```bash
# scripts/blast-radius.sh
# Usage: bash scripts/blast-radius.sh [options] <file> [file2 ...]
#
# Options:
#   --project DIR        Project root. Default: current dir (pwd)
#   --depth N            Max dependency depth. Default: 2
#   --format table|json  Output format. Default: table
#   --mcp                Force MCP trace (codebase-memory-mcp)
#   --grep               Force grep-based fallback
#
# Input:  file paths relative to project root
# Output: blast radius report
# Exit:   0 success, 1 error
```

### 2.2 Formato de salida (--format table)

```
╔══════════════════════════════════════════════════════════════╗
║  Blast Radius: src/services/UserService.ts                  ║
╠══════════════════════════════════════════════════════════════╣
║  Depth  File                           Risk    Relation     ║
╠══════════════════════════════════════════════════════════════╣
║  D=1    src/controllers/UserCtrl.ts     HIGH    imports      ║
║  D=1    src/services/AuthService.ts     HIGH    imports      ║
║  D=2    src/middleware/auth.ts          MEDIUM  transitive    ║
║  D=2    src/routes/index.ts             LOW     registers    ║
╠══════════════════════════════════════════════════════════════╣
║  Summary: 4 files impacted, 2 direct, 2 transitive          ║
║  Risk score: 65/100 (MEDIUM)                                ║
╚══════════════════════════════════════════════════════════════╝
```

### 2.3 Formato JSON

```json
{
  "file": "src/services/UserService.ts",
  "depth": 2,
  "total_impacted": 4,
  "direct": 2,
  "transitive": 2,
  "risk_score": 65,
  "risk_level": "MEDIUM",
  "impacted": [
    {"file": "src/controllers/UserCtrl.ts", "depth": 1, "risk": "HIGH", "relation": "imports"},
    {"file": "src/services/AuthService.ts", "depth": 1, "risk": "HIGH", "relation": "imports"},
    {"file": "src/middleware/auth.ts", "depth": 2, "risk": "MEDIUM", "relation": "transitive"},
    {"file": "src/routes/index.ts", "depth": 2, "risk": "LOW", "relation": "registers"}
  ]
}
```

### 2.4 Algoritmo

1. Intentar `codebase-memory-mcp trace_path` vía MCP query (enrich_graph mode)
2. Si MCP falla o no disponible, usar grep-based heuristic:
   - Buscar imports/requires/use del fichero target en todo el codebase
   - Para cada resultado directo, repetir recursivamente hasta depth=N
   - Clasificar riesgo: direct=HIGH, depth=1=MEDIUM, depth>=2=LOW
3. Agregar y emitir reporte

---

## 3. Reglas de Negocio

| ID | Regla | Error |
|----|-------|-------|
| BR-01 | El fichero target debe existir en el filesystem | `ERROR: file not found` exit 1 |
| BR-02 | depth debe ser >= 1 y <= 5 | `ERROR: depth must be 1-5` exit 1 |
| BR-03 | Si no se encuentran dependientes, emitir "No dependents found" | exit 0 |
| BR-04 | El riesgo se calcula como: direct*10 + transitive*5, normalizado a 0-100 | N/A |
| BR-05 | MCP trace_path tiene prioridad sobre grep heuristic | N/A |

---

## 4. Constraints

- **Performance**: grep fallback <10s para repos <5000 ficheros
- **Security**: no ejecuta codigo del repo analizado, solo grep
- **Compatibilidad**: bash 5+, grep, jq (opcional para MCP)

---

## 5. Test Scenarios

| ID | Escenario | Input | Expected |
|----|-----------|-------|----------|
| T01 | Fichero inexistente | `blast-radius.sh no-existe.ts` | exit 1, stderr "not found" |
| T02 | Fichero sin dependientes | `blast-radius.sh orphan-file.sh` | exit 0, "No dependents found" |
| T03 | Fichero con dependientes | `blast-radius.sh workspace-health.sh` | exit 0, tabla con >=1 fila |
| T04 | JSON output | `blast-radius.sh --json workspace-health.sh` | exit 0, JSON valido |
| T05 | Depth control | `blast-radius.sh --depth 1 workspace-health.sh` | solo depth=1 en output |
| T06 | Multiple files | `blast-radius.sh f1.sh f2.sh` | reporte combinado |
| T07 | Depth fuera de rango | `blast-radius.sh --depth 10 f.sh` | exit 1, error message |

---

## 6. Ficheros a Crear/Modificar

| Accion | Fichero |
|--------|---------|
| CREATE | `scripts/blast-radius.sh` |
| CREATE | `tests/test-se-260-blast-radius.bats` |
| MODIFY | `docs/ROADMAP.md` (añadir SE-260) |
| MODIFY | `scripts/workspace-health.sh` (integrar en SE-261) |

---

## 7. Codigo de Referencia

- `scripts/workspace-health.sh` — helper functions (count_glob, pct, grade)
- `SPEC-IMPACT-ANALYSIS.spec.md` — formato de informe de impacto
- MCP: `codebase-memory-mcp trace_path function_name=X direction=outbound depth=N`

---

## 8. Configuracion de Entorno

- Project dir: raiz del workspace
- Sin dependencias externas (bash puro)
- jq opcional para parseo de MCP JSON

---

## 9. Estado de Implementacion

| Iteracion | Fecha | Accion | Resultado |
|-----------|-------|--------|-----------|
| 0 | 2026-07-11 | Spec creada | — |

---

## 10. Checklist Pre-Entrega

- [ ] Script ejecutable con `chmod +x`
- [ ] `set -uo pipefail` al inicio
- [ ] `--help` muestra usage
- [ ] Modos table y json funcionan
- [ ] Fallback a grep cuando MCP no disponible
- [ ] BATS tests pasan (>=3 tests)
- [ ] No hardcodea paths absolutos
- [ ] Shellcheck limpio

---

## 11. OpenCode Implementation Plan

### Bindings touched
| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Script blast-radius | scripts/blast-radius.sh | Mismo fichero |
| MCP query | codebase-memory-mcp | Mismo MCP server |

### Verification protocol
- [x] Funciona en runtime OpenCode (bash puro, sin deps OpenCode-especificas)
- [ ] Tests cubren ambos paths (MCP + grep fallback)
- [x] No añade hooks (script standalone)

### Portability classification
**PURE_BASH** — funciona identico en Claude Code, OpenCode y terminal sin IA.
