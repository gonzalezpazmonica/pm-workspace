---
id: SE-084
title: SE-084 — Skill catalog quality audit (Use-when triggers + progressive disclosure)
status: APPROVED
origin: mattpocock/skills/write-a-skill (MIT) — meta-disciplina aplicada a 86 skills internos
author: Savia
priority: alta
effort: M 6h
related: SE-081, SE-082, SE-083, SE-085, SE-086, SE-087 (todos los nuevos skills se beneficien)
approved_at: "2026-04-27"
applied_at: null
expires: "2026-06-27"
era: 190
---

# SE-084 — Skill catalog quality audit

## Why

pm-workspace tiene 86 skills hoy. Pocock impone dos disciplinas en `write-a-skill/SKILL.md` que la mayoría de nuestros skills NO cumplen:

1. **`description` debe contener "Use when [triggers específicos]"** — porque el LLM lee SOLO la description al decidir qué skill cargar. Sin triggers explícitos, el agente no distingue entre skills similares.
2. **SKILL.md ≤100 LOC; contenido extra va en ficheros linkados** (REFERENCE.md, EXAMPLES.md, scripts/) — progressive disclosure. Skills monolíticos se cargan completos cada turno → coste de tokens innecesario.

Auditoría rápida (manual, ~10 skills muestreados): ~40 % no tienen "Use when ...", ~25 % superan 200 LOC sin partición. Con 86 skills, esto significa ~34 skills con descripción débil + ~22 monolíticos. Coste real en tokens difícil de estimar pero distinto-de-cero por turno.

Coste de no auditar: la calidad del catálogo deriva con cada skill nuevo (SE-081/083/085/086/087 añaden 7 más). Coste de auditar ahora: 6h, baseline establecido, ratchet aplicable.

## Scope (M 6h, 2 slices)

### Slice 1 (S 2h) — Auditor estático

`scripts/skill-catalog-audit.sh` — escanea `.opencode/skills/*/SKILL.md` y reporta:

- **Use-when missing**: description sin patrón `Use when ...` o equivalente ("Activa cuando...", "Trigger ...")
- **Overlong**: SKILL.md > 100 LOC (warning), > 200 LOC (fail)
- **Missing frontmatter**: sin `name:` o `description:`
- **Description vague**: < 30 chars o sin verbo principal

Output: TSV en `output/skill-catalog-audit-YYYYMMDD.tsv` con columnas `skill | issue | severity | line_count | description_preview`.

Modos: `--report` (default, exit 0), `--gate` (exit 1 si fail-severity ≥ N), `--baseline-write` (genera `.ci-baseline/skill-quality-violations.count`).

### Slice 2 (M 4h) — Baseline + remediation guide

- Baseline `.ci-baseline/skill-quality-violations.count` con counts iniciales (warnings + fails)
- `docs/rules/domain/skill-catalog-discipline.md` (~100 LOC) — la regla canónica que cita Pocock write-a-skill MIT
- pr-plan G14 reservado en SE-078; este spec lo activa: G14 ejecuta el auditor en modo `--gate` sólo sobre los skills modificados en el PR (no full catalog)
- `scripts/baseline-tighten.sh` aplicable sin cambios
- Remediation guide para los ~56 skills problemáticos: NO se rewriteen en este PR — sólo se documenta el plan; se aplican incrementalmente cuando alguien toca el skill

## Acceptance criteria

### Slice 1
- [ ] AC-01 `scripts/skill-catalog-audit.sh` ejecutable, modos report/gate/baseline-write
- [ ] AC-02 Output TSV correcto con 4 issue types
- [ ] AC-03 Tests BATS ≥12 (todos los modos, edge cases: skill sin frontmatter, description vacía, mid-length, etc.)

### Slice 2
- [ ] AC-04 `.ci-baseline/skill-quality-violations.count` generado con counts reales
- [ ] AC-05 `docs/rules/domain/skill-catalog-discipline.md` ≤120 LOC, cita Pocock MIT
- [ ] AC-06 pr-plan G14 activa el gate en modo `--gate` filtrando a skills cambiados en el PR
- [ ] AC-07 No regression: skills modificados no aumentan violations
- [ ] AC-08 Tests BATS ≥6 (G14 integration, baseline integrity)
- [ ] AC-09 CHANGELOG fragment con métricas baseline (X warnings, Y fails iniciales)

## No hace

- NO reescribe los ~56 skills problemáticos automáticamente — sólo documenta + ratchet
- NO añade gate FULL catalog en CI (sería regresión inmediata) — sólo skills cambiados en PR
- NO impone que skills extant violadores sean fixeados antes de mergear cualquier PR — sólo no aumentar violations
- NO implementa `npx skills add` o distribución externa — mantiene el catálogo cerrado a pm-workspace

## Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Baseline inflado bloquea PRs futuros | Media | Medio | Modo `--gate` sólo sobre skills tocados; ratchet baseline-tighten.sh |
| Auditor da false positives en skills legítimamente largos | Media | Bajo | Threshold > 200 LOC = fail (alto); ≤200 LOC = warning |
| Disciplina rota cada Era nueva | Alta | Bajo | G14 enforced post-Slice 2 |

## Dependencias

- ✅ pr-plan G14 reservado en SE-078 (slot vacío)
- ✅ `scripts/baseline-tighten.sh` existe (SE-046)
- ✅ 86 skills bajo `.opencode/skills/` accesibles
- Recomendado pero no bloqueante: SE-081/083/085/086/087 mergeados primero (los nuevos skills compliant by design); si vienen después, ya respetan el gate

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Auditor | `scripts/skill-catalog-audit.sh` | bash puro, idéntico |
| Baseline | `.ci-baseline/skill-quality-violations.count` | mismo path |
| Doc | `docs/rules/domain/skill-catalog-discipline.md` | lazy-load |
| Gate G14 | `scripts/pr-plan-gates.sh` | mismo |

### Verification protocol

- [ ] Smoke: ejecutar auditor desde sesión OpenCode v1.14 — output idéntico
- [ ] G14 detecta skill malformado en PR test
- [ ] Baseline integrity test pasa

### Portability classification

- [x] **PURE_BASH**: bash + markdown puro, cross-frontend trivial.

## Referencias

- `mattpocock/skills/write-a-skill/SKILL.md` — meta-disciplina fuente
- `docs/rules/domain/spec-opencode-implementation-plan.md` — pattern para gates pr-plan
- SE-046 baseline-tighten.sh — pattern para ratchet
- SE-078 pr-plan G14 reserved slot
