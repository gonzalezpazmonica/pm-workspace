---
layer: peripheral
name: workspace-integrity
description: "Usar cuando se audita la integridad del workspace (drift, reglas, agentes, baseline)."
allowed-tools: [Bash, Read, Glob]
metadata:
  # --- metadata.savia.* (SE-333) ---
  savia.agent: architect
  savia.maturity: stable
  savia.category: quality
  savia.context: fork
  savia.disable-model-invocation: false
  savia.priority: medium
  savia.summary: "Aggregator skill listando 6 scripts de auditoria de integridad del workspace. Detectan drift entre docs y realidad, orphan rules, agents oversized, baseline stale."
  savia.tags: "integrity, audit, drift, workspace, hygiene"
  savia.user-invocable: True
---

# Skill: Workspace Integrity

> Auditores de integridad documento-realidad.
> Ref: SE-043/046/047/048/052/057.

## Cuando usar

- Pre-push (manual check de drift antes de `git push`)
- Al cierre de cada Era (ejecutados en batches 13, 22, 23)
- Mensualmente sobre workspace sano
- Tras refactor que toca muchos ficheros

## Inventario

| Script | Spec | Detecta |
|---|---|---|
| `claude-md-drift-check.sh` | SE-043 | Counters en CLAUDE.md vs filesystem (agents/commands/skills/hooks) |
| `baseline-tighten.sh` | SE-046 | Baseline metrics stale tras cambios estructurales |
| `agents-catalog-sync.sh` | SE-047 | Drift entre `docs/rules/domain/agents-catalog.md` y `.opencode/agents/` |
| `rule-orphan-detector.sh` | SE-048 | Reglas en `docs/rules/domain/` sin referencias cruzadas |
| `rule-manifest-integrity.sh` | SE-057 | `docs/rules/INDEX.md` vs ficheros reales |
| `agent-size-audit.sh` + `agent-size-remediation-plan.sh` | SE-052 | Agents > umbral lineas; plan de split |
| `rule-usage-analyzer.sh` | — | Estadisticas de uso de reglas domain |

## Invocacion

Cada línea de este bloque se ejecuta tal cual en `tests/test-workspace-integrity.bats`.

```bash
bash scripts/claude-md-drift-check.sh                 # texto; exit 0 PASS, 2 drift
bash scripts/rule-manifest-integrity.sh --json        # exit 0 PASS, 1 finding
bash scripts/agents-catalog-sync.sh --check --json    # exit 0 en sync, 1 drift
bash scripts/rule-orphan-detector.sh --json           # exit 0 PASS, 1 orphans
bash scripts/agent-size-audit.sh --quiet              # exit 0 PASS, 1 agentes > 4096 bytes
```

## Exit codes reales

| Script | PASS | Drift / finding | Uso incorrecto |
|---|---|---|---|
| `claude-md-drift-check.sh` | 0 | **2** | — |
| `rule-manifest-integrity.sh`, `rule-orphan-detector.sh` | 0 | 1 | 2 |
| `agents-catalog-sync.sh --check` | 0 | 1 | 2 (sin `--check/--generate/--apply`) |
| `agent-size-audit.sh` | 0 | 1 (`--ratchet`: solo si supera el baseline) | 2 |
| `baseline-tighten.sh` | 0 | 1 (regresión: actual > baseline; no la enmascara) | 2 |

JSON: `rule-manifest-integrity`, `rule-orphan-detector`, `agents-catalog-sync --check --json`, `agent-size-remediation-plan` y `rule-usage-analyzer`. `claude-md-drift-check` y `agent-size-audit` solo emiten texto.

## Integracion con CI

- `claude-md-drift-check.sh` ya bloquea vía `readiness-check.sh`.
- `rule-orphan-detector` notifica (no bloquea) si encuentra orphans.
- `agent-size-audit --ratchet` compara con `.ci-baseline/agent-size-violations.count`.

## Qué escriben

- Los auditores (`claude-md-drift-check`, `rule-manifest-integrity`, `rule-orphan-detector`, `agents-catalog-sync --check`) no modifican ficheros.
- `agent-size-audit` escribe su informe en `output/`.
- `agents-catalog-sync --apply` **reescribe** `docs/rules/domain/agents-catalog.md`.
- `baseline-tighten` **reescribe** el baseline indicado; solo baja, nunca sube, y `--dry-run` no escribe.
- Ninguno corre tests (eso es `readiness-check.sh`) ni hace push o merge.

## Decision tree

```
¿CI falla por counter drift?
  → SE-062.1 counter sync (usar claude-md-drift-check.sh)
¿Spec ID duplicado?
  → Revisar docs/propuestas, resolve per SE-044
¿Rule orphan?
  → Remover rule o anadir referencia
¿Agent oversized?
  → agent-size-remediation-plan.sh genera split plan
```

## Referencias

- SE-043 drift check: `scripts/claude-md-drift-check.sh`
- SE-046 baseline: `scripts/baseline-tighten.sh`
- SE-047 catalog sync: `scripts/agents-catalog-sync.sh`
- SE-048 orphan: `scripts/rule-orphan-detector.sh`
- SE-052 agent size: `scripts/agent-size-audit.sh`
- SE-057 manifest: `scripts/rule-manifest-integrity.sh`
- Era 182 audit closure: batch 13 (PR #654)
- Era 184 Consolidation: `docs/propuestas/SE-062-era184-consolidation-hygiene.md`
