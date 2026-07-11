# Spec: Enhancement — Workspace Health Score v2 (CodeFlow-inspired)

**Task ID:**        SE-261
**PBI padre:**      SE-165 — workspace-health
**Sprint:**         2026-07
**Fecha creacion:** 2026-07-11
**Creado por:**     Savia (research: CodeFlow health scoring)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estado:**         Pendiente

**Effort Estimation (Dual Model):**
| Dimension | Value |
|-----------|-------|
| Agent effort | 60 min |
| Human effort | 1.5h |
| Review effort | 20 min |
| Context risk | low |
| Agent-capable | yes |
| Fallback | Modificar script bash existente |

**OpenCode Implementation Plan:**
| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Script | `scripts/workspace-health.sh` (modify) | Mismo script |
| Sub-script | `scripts/blast-radius.sh` (SE-260) | Mismo script |

**Portability classification:** PURE_BASH

---

## 1. Contexto y Objetivo

`scripts/workspace-health.sh` (SE-165) calcula un health score con 6 dimensiones
(skills, commands, maturity, tests, security, docs). CodeFlow anade dimensiones
que miden la calidad del codigo mismo, no solo del workspace: blast radius,
code ownership (bus factor), y dead code. El scoring de CodeFlow es mas util
para desarrolladores porque refleja fragilidad real del codebase.

**Objetivo:** Extender `workspace-health.sh` con 3 nuevas dimensiones inspiradas
en CodeFlow, manteniendo backward compatibility:
1. **Blast Radius** — agrega riesgo maximo del top 3 ficheros mas fragiles
2. **Code Ownership** — mide diversidad de autores (anti-bus-factor)
3. **Dead Code** — estima porcentaje de codigo no referenciado

**Criterios de Aceptacion:**
- [ ] Nuevas dimensiones aparecen en output `--summary` y `--json`
- [ ] Peso ajustado: skills 15%, cmds 10%, maturity 10%, tests 15%, security 15%, docs 10%, blast 10%, ownership 10%, deadcode 5%
- [ ] `--ci` sigue funcionando con threshold 60%
- [ ] Nuevo flag `--v2` activa dimensiones extendidas; sin flag = backward compat
- [ ] Cada dimension nueva tiene grade individual (A-F)

---

## 2. Contrato Tecnico

### 2.1 Nuevas dimensiones

#### Blast Radius Score (10%)
Mide la fragilidad del codebase: el riesgo maximo entre los N ficheros con mayor
numero de dependientes. Usa SE-260 `blast-radius.sh --json` para cada fichero candidato.

```
blast_score = 100 - max(risk_score de top-3 ficheros con mas imports)
```

#### Code Ownership Score (10%)
Mide diversidad de contribuidores. Un fichero mantenido por 1 sola persona es
riesgo bus-factor=1.

```
ownership_score = (% de ficheros con >=2 autores en git log de los ultimos 90 dias)
```

#### Dead Code Score (5%)
Estima codigo no referenciado mediante heuristica: funciones definidas pero
nunca llamadas (segun grep de referencias cruzadas). Aplica solo a scripts bash
del workspace.

```
dead_code_pct = (funciones definidas - funciones referenciadas) / funciones definidas
dead_code_score = 100 - dead_code_pct
```

### 2.2 Formato JSON extendido

```json
{
  "generated": "2026-07-11T12:00:00+00:00",
  "version": 2,
  "overall": { "score": 72, "grade": "C" },
  "dimensions": {
    "skill_completeness": { "score": 95, "grade": "A" },
    "command_completeness": { "score": 80, "grade": "B" },
    "maturity": { "score": 65, "grade": "D" },
    "test_coverage": { "score": 45, "grade": "F" },
    "security": { "score": 100, "grade": "A" },
    "documentation": { "score": 71, "grade": "C" },
    "blast_radius": { "score": 60, "grade": "D", "top_fragile_files": ["main.sh", "utils.sh"] },
    "code_ownership": { "score": 70, "grade": "C", "files_with_single_author": 15, "total_files": 50 },
    "dead_code": { "score": 85, "grade": "B", "dead_functions": 3, "total_functions": 20 }
  }
}
```

---

## 3. Reglas de Negocio

| ID | Regla | Error |
|----|-------|-------|
| BR-01 | `--v2` activa las 3 nuevas dimensiones; sin flag = solo 6 originales | N/A |
| BR-02 | Si `blast-radius.sh` no existe, blast_radius score = 50 (default) | WARN en output |
| BR-03 | Ownership solo mide ficheros en git (excluye vendor/, node_modules/) | N/A |
| BR-04 | Dead code score = 100 si no se detectan funciones (evitar div/0) | N/A |
| BR-05 | `--ci` con --v2 sigue usando threshold 60% | exit 1 si <60 |

---

## 4. Constraints

- Backward compatible: sin `--v2`, output identico a SE-165 original
- Las nuevas dimensiones son best-effort (no bloquean si fallan)
- Timeout de 5s por dimension nueva (no degradar tiempo total >15s)

---

## 5. Test Scenarios

| ID | Escenario | Expected |
|----|-----------|----------|
| T01 | `--summary` sin --v2 | Output identico a version original (6 dims) |
| T02 | `--summary --v2` | Output con 9 dimensiones |
| T03 | `--json --v2` | JSON con "version": 2 y 9 dimensiones |
| T04 | `--ci --v2` | exit 1 si score <60, exit 0 si >=60 |
| T05 | `--v2` sin blast-radius.sh | blast_radius=50, WARN en stderr |
| T06 | `--v2` en repo sin git | ownership_score=0, WARN |

---

## 6. Ficheros a Crear/Modificar

| Accion | Fichero |
|--------|---------|
| MODIFY | `scripts/workspace-health.sh` |
| CREATE | `tests/test-se-261-health-v2.bats` |
| MODIFY | `docs/ROADMAP.md` |

---

## 7. Codigo de Referencia

- `scripts/workspace-health.sh` — version actual (SE-165)
- `scripts/blast-radius.sh` — SE-260 (nuevo)
- `scripts/bus-factor-scan.sh` — SE-252 (existente, para ownership)

---

## 8. Estado de Implementacion

| Iteracion | Fecha | Accion | Resultado |
|-----------|-------|--------|-----------|
| 0 | 2026-07-11 | Spec creada | — |

---

## 9. Checklist Pre-Entrega

- [ ] `--v2` flag funciona
- [ ] Sin `--v2`, output identico a version original
- [ ] Nuevas dimensiones tienen grade individual
- [ ] `--ci` mode sigue funcional
- [ ] BATS tests pasan (>=6 tests)
- [ ] Shellcheck limpio
- [ ] No rompe scripts que dependen del JSON original (version=2 es opt-in)
