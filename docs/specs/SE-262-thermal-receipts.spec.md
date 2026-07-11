# Spec: Feature — PR Thermal Receipts (CodeFlow-inspired)

**Task ID:**        SE-262
**PBI padre:**      SE-165 — workspace-health v2
**Sprint:**         2026-07
**Fecha creacion:** 2026-07-11
**Creado por:**     Savia (research: CodeFlow thermal receipt PR comments)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estado:**         Pendiente

**Effort Estimation (Dual Model):**
| Dimension | Value |
|-----------|-------|
| Agent effort | 40 min |
| Human effort | 1h |
| Review effort | 15 min |
| Context risk | low |
| Agent-capable | yes |
| Fallback | bash puro, genera markdown |

**OpenCode Implementation Plan:**
| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Script | `scripts/pr-thermal-receipt.sh` | Mismo script |
| Hook | `.claude/hooks/pr-thermal-receipt.sh` | Mismo hook (symlink) |
| PR plan | `scripts/pr-plan.sh` | Mismo script |

**Portability classification:** PURE_BASH

---

## 1. Contexto y Objetivo

CodeFlow genera un "thermal receipt" en cada PR mergeado: un comentario sticky
con formato ticket termico que muestra el delta de metricas (LOC, funciones,
dead code, blast radius, health) antes y despues del merge. Es informativo,
ligero, y no bloquea.

Savia ya tiene:
- `pr-natural-language-summary.md` (`.pr-summary.md` obligatorio antes de PR)
- `receipts-protocol.md` (SE-030 — "no proof means no answer")
- `scripts/pr-plan.sh` con gate `g_summary`

Pero no hay un resumen automatico de metricas estilo "thermal receipt" que
muestre el delta numerico que el PR introduce.

**Objetivo:** Crear `scripts/pr-thermal-receipt.sh` que, dado un PR (o el diff
staged actual), calcula metricas delta y emite un bloque markdown con formato
thermal receipt para incluir en el PR body o como comentario.

**Criterios de Aceptacion:**
- [ ] `pr-thermal-receipt.sh` emite bloque markdown con metricas delta
- [ ] `pr-thermal-receipt.sh --staged` analiza git diff --staged
- [ ] `pr-thermal-receipt.sh --branch BASE..HEAD` analiza diff entre ramas
- [ ] Detecta: LOC +/-, files changed, functions +/-, new/deleted scripts
- [ ] Integrable en `pr-plan.sh` como seccion adicional del PR body
- [ ] Formato sticky para actualizacion automatica (`<!-- codeflow-card:receipt -->` marker)

---

## 2. Contrato Tecnico

### 2.1 Interfaz

```bash
# scripts/pr-thermal-receipt.sh
# Usage: bash scripts/pr-thermal-receipt.sh [--staged | --branch REFSPEC]
#
# Options:
#   --staged          Analyze git diff --staged
#   --branch REFSPEC  Analyze diff between branches (e.g. main..feature/x)
#   --project DIR     Project root. Default: current dir
#   --format md|json  Output format. Default: md
#   --health          Include health score delta (requires workspace-health.sh --v2)
#
# Output: thermal receipt markdown block
# Exit:   0 success, 1 error (not a git repo)
```

### 2.2 Formato de salida (Markdown)

```markdown
<!-- codeflow-card:receipt -->
```text
--- THERMAL RECEIPT ---
PR: SE-262 · 2026-07-11
actor: monica
--------------------------
files           12 (+3 new)
LOC           +312 / -47
functions       +4
scripts         +1
dead funcs      -1
health       C+ → B-  ▲
--------------------------
   thank you for your code
```
```

### 2.3 Formato JSON

```json
{
  "timestamp": "2026-07-11T12:00:00Z",
  "actor": "monica",
  "delta": {
    "files_changed": 12,
    "files_added": 3,
    "files_deleted": 0,
    "loc_added": 312,
    "loc_removed": 47,
    "functions_added": 4,
    "functions_removed": 1,
    "scripts_added": 1,
    "scripts_removed": 0
  },
  "health_before": {"score": 72, "grade": "C+"},
  "health_after": {"score": 78, "grade": "B-"},
  "health_delta": 6
}
```

### 2.4 Algoritmo

1. Detectar modo (--staged vs --branch)
2. Ejecutar `git diff --stat` para conteo de ficheros y LOC
3. Ejecutar `git diff` parseado para detectar funciones nuevas (heuristico: lineas que empiezan con `function `, `def `, `func `, etc.)
4. Si `--health`: ejecutar `workspace-health.sh --json --v2` antes y despues del cambio (via git stash o git worktree)
5. Formatear bloque markdown con formato "thermal receipt"
6. Emitir a stdout

---

## 3. Reglas de Negocio

| ID | Regla | Error |
|----|-------|-------|
| BR-01 | Debe ejecutarse dentro de un git repo | `ERROR: not a git repository` exit 1 |
| BR-02 | `--staged` requiere cambios staged | `WARN: no staged changes` exit 0 con receipt vacio |
| BR-03 | `--branch` requiere que ambos refs existan | `ERROR: ref not found` exit 1 |
| BR-04 | El bloque markdown incluye marker `<!-- codeflow-card:receipt -->` para updates sticky | N/A |
| BR-05 | Si `--health` y no hay health previo, mostrar solo health actual sin delta | N/A |
| BR-06 | Deteccion de funciones es best-effort (regex heuristico) | N/A |

---

## 4. Constraints

- Tiempo <5s sin --health, <15s con --health
- No modifica el repo (read-only)
- Compatible con git 2.30+

---

## 5. Test Scenarios

| ID | Escenario | Expected |
|----|-----------|----------|
| T01 | Fuera de git repo | exit 1, "not a git repository" |
| T02 | --staged sin cambios | exit 0, receipt con "no changes" |
| T03 | --staged con cambios | exit 0, receipt con metricas delta |
| T04 | --branch con refs validas | exit 0, receipt con metricas delta |
| T05 | --branch con ref inexistente | exit 1 |
| T06 | --format json | JSON valido, campos requeridos presentes |
| T07 | --health sin workspace-health.sh | WARN, health fields omitidos |
| T08 | Marker presente en output md | contiene `<!-- codeflow-card:receipt -->` |

---

## 6. Ficheros a Crear/Modificar

| Accion | Fichero |
|--------|---------|
| CREATE | `scripts/pr-thermal-receipt.sh` |
| CREATE | `tests/test-se-262-thermal-receipt.bats` |
| MODIFY | `docs/ROADMAP.md` |
| MODIFY | `scripts/pr-plan.sh` (opcional: integrar receipt en PR body) |

---

## 7. Codigo de Referencia

- `scripts/pr-plan.sh` — PR plan existente con gate g_summary
- `scripts/workspace-health.sh` — health score (SE-165/SE-261)
- `docs/rules/domain/pr-natural-language-summary.md` — regla de PR summary
- `docs/rules/domain/receipts-protocol.md` — SE-030 receipts protocol
- CodeFlow `card/index.js` — thermal receipt rendering (inspiracion)

---

## 8. Estado de Implementacion

| Iteracion | Fecha | Accion | Resultado |
|-----------|-------|--------|-----------|
| 0 | 2026-07-11 | Spec creada | — |

---

## 9. Checklist Pre-Entrega

- [ ] Script ejecutable
- [ ] `set -uo pipefail`
- [ ] `--help` muestra usage
- [ ] Formatos md y json funcionan
- [ ] Marker `<!-- codeflow-card:receipt -->` presente en md
- [ ] No hardcodea paths
- [ ] BATS tests pasan (>=5 tests)
- [ ] Shellcheck limpio
- [ ] Integracion con pr-plan.sh documentada pero no bloqueante
