---
id: SE-035
title: Mutation testing skill — mutation-audit invocable on-demand
status: PROPOSED
origin: Research 2026-04-18 (javiergomezcorio substack — 57% → 74% score automated)
author: Savia
related: test-engineer agent, test-auditor SPEC-055, SPEC-081 hook bats coverage
approved_at: null
applied_at: null
expires: "2026-05-16"
---

# SE-035 — Mutation testing skill

## Purpose

Si NO hacemos esto: nuestros tests BATS+Jest+pytest siguen midiéndose por cobertura. Cobertura alta + agentes generando tests masivamente = tests zombies: pasan pero no detectan cambios lógicos reales. Research 2026-04-18 documenta caso donde mutation score pasó de 57% → 74% con 3 prompts sin intervención humana — prueba que la brecha cobertura-vs-calidad es medible y cerrable.

Cost of inaction: cuando lleguemos a 500+ tests AI-generated (proyección Q3 2026), un 25% de ellos probablemente serán zombies. Ese 25% es el que nos dará una falsa sensación de seguridad antes de un incidente.

## Objective

**Único y medible**: introducir skill `mutation-audit` que, aplicado on-demand sobre un módulo (`scripts/X.sh`, `src/Y.ts`), reporta mutation score + mutantes supervivientes con línea+diff. Criterio de éxito: detectar ≥80% de 10 mutantes artificiales sembrados en 3 módulos de referencia (bash + TS + python).

NO es: forzar mutation testing en cada PR (demasiado costoso). SÍ es: skill invocable + programable en sprint-end.

## Design

### Herramientas por lenguaje

| Lenguaje | Tool | Justificación |
|---|---|---|
| Bash | **mutmut-bash** (custom wrapper sobre `sed` + `bats`) | No existe tool estándar; escribir wrapper mínimo |
| TypeScript/JS | **StrykerJS** | Estándar de facto |
| Python | **mutmut** | Estándar, simple CLI |
| Go | **go-mutesting** | Opcional — priorizar bash+TS+python primero |

### Arquitectura

```
Humano/agente ejecuta:
  /mutation-audit scripts/query-lib-resolve.sh
  ↓
skill invoca:
  scripts/mutation-audit.sh scripts/query-lib-resolve.sh
  ↓
Output: output/mutation-audit-{date}-{module}.md con:
  - Score (killed / total)
  - Mutantes supervivientes (diff + línea)
  - Recomendación: qué test añadir
```

### Dependencias

- StrykerJS: npm package (instalar on-demand en repos JS)
- mutmut: `pip install mutmut`
- bash wrapper: zero-dep (sed + bats)

Todos se instalan on-demand — no en arranque de workspace.

## Slicing

### Slice 1 — Feasibility Probe (1.5h, blocking)

**Entregable**: `output/se-035-probe-{date}.md`
- Aplicar mutation a 1 script bash (scripts/query-lib-resolve.sh) y 1 TS (si hay)
- Medir: mutation score baseline, falsos negativos, latencia total
- Decisión: continue si score baseline >30% (hay señal) — abort si <10% (tests actuales no sirven ni de base)

### Slice 2 — Skill `mutation-audit` + CLI

- `scripts/mutation-audit.sh {path}`
- `.claude/skills/mutation-audit/SKILL.md`
- Tests BATS ≥20 (SPEC-055 ≥80 score)
- Comando `/mutation-audit {path}`

### Slice 3 — Integración con agent `test-engineer`

- `test-engineer` agent aprende a invocar `mutation-audit` cuando genera tests nuevos
- Reporte se incluye en agent-runs/ audit log
- Opcional: sprint-end cron que audita módulos top-5 más modificados del sprint

## Acceptance Criteria

- [ ] AC-01 Probe score baseline medido sobre 3 módulos de referencia
- [ ] AC-02 `scripts/mutation-audit.sh` con soporte bash+TS+python
- [ ] AC-03 20+ BATS tests (SPEC-055 score ≥80)
- [ ] AC-04 Skill `mutation-audit` documentado + comando `/mutation-audit`
- [ ] AC-05 `test-engineer` agent lo invoca en su ciclo
- [ ] AC-06 Doc `docs/rules/domain/mutation-testing-protocol.md` documenta cuándo usar, cuándo NO
- [ ] AC-07 Sprint-end cron opcional (NO default) documentado

## Agent Assignment

- Slice 1: test-engineer + bash-developer (probe)
- Slice 2: typescript-developer (stryker) + python-developer (mutmut) + bash-developer (wrapper)
- Slice 3: test-engineer

## Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| StrykerJS lento en repos grandes (>10min) | Media | Medio | Limitar scope a módulos individuales; nunca full-repo en CI |
| mutmut rompe en Python con imports custom | Media | Bajo | Documentar limitaciones; fallback a suite manual |
| Ruido del research (parte marketing) | Baja | Bajo | Usar la técnica (sustantiva) sin comprar la herramienta específica del post |

## Aplicación Spec Ops

- **Simplicity**: un objetivo — detectar ≥80% de mutantes sembrados
- **Purpose separado**: cost-of-inaction cuantificado (25% tests zombies proyectado)
- **Repetition/Probe**: 1.5h blocking — sin señal real, abort
- **Speed**: 3 slices, cada uno ≤1 sprint
- **Theory of Relative Superiority**: expires 2026-05-16 — si no aterriza, re-review

## Referencias

- Research Gómez Corio 2026-04-18: https://javiergomezcorio.substack.com/p/si-estas-desarrollando-software-con
- StrykerJS: https://stryker-mutator.io/
- mutmut: https://mutmut.readthedocs.io/
- SPEC-055 test-auditor (ortogonal a esto): docs/propuestas/SPEC-055-test-auditor.md
- Roadmap unificado: docs/propuestas/ROADMAP-UNIFIED-20260418.md §A4

## Dependencia

Independiente. Priorizado en Wave 1 del roadmap unificado (champion del último research).
