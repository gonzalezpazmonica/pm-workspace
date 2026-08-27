# SE-338 — Generador determinista de rule-manifest (cierra SE-057)

**Status:** IMPLEMENTED (2026-08-27, PR Batch 1 L14 — generador + gate readiness-check)
**Fecha:** 2026-08-23
**Area:** Integridad / Reglas / Higiene
**Origen:** SaviaLabs L14 · deuda técnica 1.1 (rule-manifest FAIL)
**Developer Type:** agent-single
**Context risk:** low
**Estimación:** agente ~2-3h / revisión humana 20min

---

## 1. Problema y objetivo

`rule-manifest.json` (docs/rules/domain/rule-manifest.json) está **stale desde
2026-04-16**: contiene 151 reglas, pero hoy hay 296 ficheros `*.md` en
`docs/rules/domain/` sin listar. Además 25 entradas del manifest apuntan a
ficheros que ya no existen (paths `.claude/` que migraron a `.opencode/` y
skills reubicados). No existe un generador canónico; solo consumidores.

Consecuencia: `scripts/rule-manifest-integrity.sh` (SE-057) falla en CI, el
ÍNDICE supera el límite de 150 líneas (165) y no se puede confiar en el
manifest como inventario de reglas.

El objetivo: **un generador determinista y read-only del resto del repo** que
reconstruya `rule-manifest.json` desde el filesystem con el schema actual
`{tier, consumers}`, y que su `--check` se integre en `readiness-check.sh`.

## 2. Contratos

### 2.1 `scripts/rule-manifest-generate.sh`

```text
rule-manifest-generate.sh [--check] [--output FILE] [--domain-dir DIR]
  --check        exit 1 si el manifest está stale (diff de inventario)
  --output FILE  default: docs/rules/domain/rule-manifest.json
  --domain-dir   default: docs/rules/domain
Exit: 0 ok · 1 stale/FAIL · 2 usage
```

Comportamiento determinista:
- Escanea `docs/rules/domain/*.md` (excluye `INDEX.md`, `rule-manifest.json`,
  `archive/`).
- Para cada regla extrae `context_tier` del frontmatter → clasifica tier:
  - `L1` → `tier: "critical"` (o el mapeo del schema actual)
  - `L2`/`L3` → `tier: "standard"`
  - sin tier → `tier: "dormant"`
- `consumers`: cadena vacía por defecto (mismo que hoy).
- Reconstruye `rules` como dict `{basename: {tier, consumers}}`, conserva
  `generated` (timestamp UTC), `total`, `tier*_count`, `dormant_count`.
- Nunca toca `CRITERIO.md`, CONSTITUCION ni ninguna regla en sí — solo el
  manifest.

### 2.2 Integración con `readiness-check.sh`

Añadir el paso:
```bash
bash scripts/rule-manifest-generate.sh --check  # bloquea si FAIL
```
como gate de integridad (mismo nivel que `claude-md-drift-check.sh`).

## 3. Reglas de negocio

| ID | Regla | Incumplimiento |
|---|---|---|
| RN-01 | El generador solo escribe `rule-manifest.json` (o stdout); nunca modifica reglas, CRITERIO o CONSTITUCION | Test de no-mutación (hash invariante) |
| RN-02 | `--check` detecta cualquier regla no listada o entrada fantasma | Test con fichero añadido/eliminado |
| RN-03 | Determinista: mismo estado de filesystem → mismo manifest (sin timestamps volátiles salvo `generated`) | Test de idempotencia (generar 2× → mismo inventario) |
| RN-04 | PURE_BASH + python3 stdlib; sin LLM, sin red (CRIT-001) | bash -n + grep de vendor names |

## 4. Criterios de aceptación

| AC | Criterio (falsificable) |
|---|---|
| AC-1 | `rule-manifest-generate.sh` genera un manifest JSON válido con `total` == nº de reglas en `docs/rules/domain/*.md` |
| AC-2 | Tras regenerar, `rule-manifest-integrity.sh` reporta `missing_entries` == 0 |
| AC-3 | `--check` con manifest stale → exit 1; tras regenerar → exit 0 |
| AC-4 | El manifest no referencia ficheros inexistentes (`missing_files` == 0) |
| AC-5 | 3 BATS: determinismo, no-mutación, detección de stale |

## 5. Fuera de alcance

- Reducir `INDEX.md` a ≤150 líneas (splitting por categoría) — spec aparte.
- Calibrar cada skill (eso es SE-340).
- Migrar el manifest a otro formato.

## 6. Dependencias

- `docs/rules/domain/*.md` (fuente de verdad de reglas).
- `scripts/rule-manifest-integrity.sh` (validador existente, sin cambios).
- `readiness-check.sh` (integración del gate).

---

## Anclaje

- Deuda: `docs/technical-debt-2026-08-23.md` §1.1.
- Labs: L14 (hypothesis `l14-circuit-closing`).
- Regla: SE-057 Slice 1 (rule-manifest integrity).