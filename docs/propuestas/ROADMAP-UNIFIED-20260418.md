---
id: ROADMAP-UNIFIED-20260418
title: Roadmap Unificado — Savia autonomous iteration 2026-04-18
status: LIVING
author: Savia (autoselección + consolidación)
origin: Consolidación post-research 2026-04-18 (coderlm + Bluesky + MindStudio + Spec Ops + Hands-On LLM + Dify + mutation testing) + auditoría specs pendientes + savia-enterprise gaps
expires: "2026-06-18"   # 2 sprints — re-review si no se ejecuta
related: SAVIA-SUPERPOWERS-ROADMAP.md, savia-enterprise/DEVELOPMENT-PLAN.md
---

# Roadmap Unificado — Savia Autonomous Iteration

> **Propósito**: un único documento sobre el que Savia itera autónomamente hasta el final de la capacidad actual. Clasifica TODO lo pendiente (PROPOSED, research-derived, savia-enterprise gaps) por **autonomy-viable** vs **requires-hardware-or-humans**. Lo segundo se difiere al final — no bloquea iteración.
>
> **Principios aplicados**:
> - Spec Ops (McRaven): Simplicity, Repetition, Speed, Purpose, Theory of Relative Superiority
> - Robar patrón, no plataforma
> - Rule #8 autonomous-safety: PRs Draft, reviewer @gonzalezpazmonica, jamás merge autónomo

## Tabla 0 — Estado de partida (2026-04-18)

Hoy (tras PR #604):
- 129 specs en `docs/propuestas/` (36 savia-enterprise SPEC-SE + 93 SPEC/SE)
- 27 PROPOSED/Proposed/ACCEPTED/Draft/IN_PROGRESS activos
- 76 sin campo `status:` (legacy — se tratan como "backlog frío")
- 3 research reports locales (coderlm, Bluesky, mutation testing) + 4 ya consolidados (MindStudio, Spec Ops, Hands-On LLM, Dify)

## Sección A — Autonomy-viable (iteración inmediata)

Orden por **Relative Superiority × Cost-of-inaction**. Savia ejecuta top-down; si un slice se trunca, registra razón y pasa al siguiente.

### Wave 1 — Research-derived champions (prioridad máxima)

Champions extraídos de los 7 research outputs recientes. Ya tienen spec o se convierten trivialmente.

| # | Spec | Origen | Valor | Probe blocking | Estado |
|---|---|---|---|---|---|
| A1 | SE-032 reranker layer | Hands-On LLM cap.8 + Dify rag | Alto (1.5M tokens/mes de ruido) | Sí (2h) | PROPOSED — merged PR #604 |
| A2 | SE-033 topic-cluster (BERTopic) | Hands-On LLM cap.5 | Medio-Alto | Sí (1.5h) | PROPOSED |
| A3 | SE-034 workflow node typing | Dify workflow | Medio | No | PROPOSED |
| A4 | **Mutation testing skill** | Substack Gómez Corio 2026-04-18 | Medio | No — ensure, no probe | **Crear spec SE-035** |
| A5 | **CoderLM-style query cache** | coderlm research + RLM pattern | Medio | No — ya parcial en SE-031 | Consolidar en SE-031 |

**A4 nuevo**: crear `SE-035-mutation-testing-skill.md` — skill `mutation-audit` invocable por `test-engineer`, aplicable a code cambiado en PR. NO en CI por defecto (coste CPU). Sí bajo `/mutation-audit {path}` comando manual + sprint-end scheduled.

### Wave 2 — Specs PROPOSED listos para slice

Ordenados por dependencia y cost-of-inaction.

| # | Spec | Título corto | Dependencia | Prioridad |
|---|---|---|---|---|
| B1 | SE-028 | oumi integration (SLM data synth + eval) | SE-027 SLM merged | Alto |
| B2 | SE-029 | Rate-distortion context compression | Savia Dual Compact v2 | Alto |
| B3 | SE-030 | GraphRAG quality gates | SPEC-027 graph merged | Medio-Alto |
| B4 | SPEC-081 | Hook BATS coverage (10 críticos) | — | Medio-Alto (deuda CI) |
| B5 | SPEC-082 | Orphan skill fix | — | Medio (limpieza) |
| B6 | SPEC-102 | opendataloader-pdf-digest | pdf-digest merged | Medio |
| B7 | SPEC-103 | Deterministic-first digests | SPEC-102 probe | Medio |
| B8 | SPEC-104 | Tagged PDF compliance output | SPEC-103 | Bajo (nicho legal) |
| B9 | SPEC-107 | AI cognitive debt mitigation | — | Medio — research-heavy |
| B10 | SPEC-108 | Agent self-improvement + Sentry RCA | SPEC-108 merged parcial | Medio |
| B11 | SPEC-099 | gitagent export adapter (portabilidad) | — | Medio-Bajo (futuro) |
| B12 | SPEC-100 | GAIA benchmark integration | — | Medio (validación externa) |
| B13 | SPEC-085 | savia-web Phase 1 data model | web repo | Medio (condicionado) |

### Wave 3 — Savia Enterprise gaps (SPEC-SE-*)

Los drafts de savia-enterprise con status Draft o NONE son candidatos. Criterio: seleccionar los P0/P1 que NO requieren infra externa.

| # | Spec | Título | Prioridad | Autonomy-viable |
|---|---|---|---|---|
| C1 | SPEC-SE-028 | Prompt injection guard (context file scanning) | **P0 seguridad** | Sí |
| C2 | SPEC-SE-029 | Iterative compression | P1 | Sí |
| C3 | SPEC-SE-030 | Skill self-improvement pipeline | P2 | Sí |
| C4 | SPEC-SE-031 | Delegation toolset enforcement | P1 | Sí |
| C5 | SPEC-SE-032 | Cross-project lessons pipeline | P2 | Sí |
| C6 | SPEC-SE-033 | Context rotation strategy | P2 | Sí (depende SE-029) |
| C7 | SPEC-SE-034 | Daily agent activation plan | P3 | Sí |
| C8 | SPEC-SE-012 | Signal-noise reduction (docs) | — | Sí |
| C9 | SPEC-SE-013 | Dual estimation (agent vs human) | — | Sí (merge con SPEC-078) |
| C10 | SPEC-SE-020 | Cross-project deps | — | Sí |
| C11 | SPEC-SE-021 | Code Review Court (+pr-agent) | — | Sí (converge con SPEC-124) |
| C12 | SPEC-SE-023 | Knowledge federation | — | Sí (converge con SE-030 GraphRAG) |
| C13 | SPEC-SE-025 | Agentic workforce analytics | — | Sí |
| C14 | SPEC-SE-026 | Compliance evidence (ISO/SOC2) | — | Sí — docs + hooks |

**Acción: SPEC-SE-028 promover a P0 sprint actual** (prompt injection guard). Riesgo de seguridad concreto: cualquier fichero CLAUDE.md, AGENTS.md, o spec puede contener inyecciones. Feasibility probe: scanner determinista + test suite sobre 50 ficheros sintéticos adversariales.

### Wave 4 — Limpieza técnica (deuda formalizada como specs)

Cada item de deuda ahora tiene su spec dedicado para no perder contexto:

| # | Item | Spec | Estado | Prioridad |
|---|---|---|---|---|
| D1 | Specs sin frontmatter YAML (111) | **SE-036** | PROPOSED | Alto — habilita tooling |
| D2 | Test-auditor score <80 barrido | **SE-039** | PROPOSED | Medio — calidad test suite |
| D3 | Agent catalog >4KB Rule #22 | **SE-038** | PROPOSED | Medio-bajo — probe primero |
| D4 | Hook latency SLA 20ms | **SE-037** | PROPOSED | Medio-alto — UX hot path |
| D5 | Skills sin tests BATS | absorbido por SE-037 | — | — |

Tool ya creado en Wave 4: `scripts/spec-status-normalize.sh` (PR #607). Ejecutar `--audit` y `--suggest` para producir inputs de SE-036 Slice 2.

---

## Sección B — Requires-hardware-or-humans (diferido)

**No** iterar autónomamente. Esperan a Mónica / hardware / humanos operativos.

| # | Spec | Motivo de diferimiento |
|---|---|---|
| Z1 | SPEC-006 ZeroClaw | Hardware físico (brazo robótico) |
| Z2 | SPEC-007 ZeroClaw voice pipeline | Hardware (mic, audio) + hardware testing |
| Z3 | SPEC-008 ZeroClaw meeting digest | Hardware + humanos en reunión |
| Z4 | SPEC-004 Robotics vertical | Hardware físico |
| Z5 | SPEC-005 Physical assembly guide | Hardware + humano que monta |
| Z6 | SPEC-009 Savia Teams participant | Cuenta Teams + dinámica humana |
| Z7 | SPEC-021 Readiness hardware checks (parte física) | Hardware real (GPU, TPM, USB) — parte software ya hecha |
| Z8 | SPEC-064 Computer use integration | Requiere entorno GUI dedicado + humano para validar acciones |
| Z9 | SPEC-SE-005 Sovereign deployment | Ops humano (Kubernetes, vault, DNS) |
| Z10 | SPEC-SE-007 Enterprise onboarding | Ciclo comercial humano |
| Z11 | SPEC-SE-008 Licensing distribution | Legal humano + stripe/billing humano |
| Z12 | SPEC-SE-017/018/019 Billing/valuation | Finance humano |

Savia NO escribe código en estos. Sí puede:
- Mantener spec actualizado si llega nuevo contexto
- Documentar lecciones cuando Mónica ejecuta manualmente
- Escribir scaffolding (dirs, configs vacíos) si Mónica lo pide explícitamente

---

## Sección C — Estrategia de iteración

### Cadencia

- Savia trabaja un slice por ciclo (no una spec completa en un shot)
- Cada slice: rama `agent/{spec-id}-slice{N}-{YYYYMMDD}` → commits → `/pr-plan` → push → PR Draft
- Reviewer obligatorio: `@gonzalezpazmonica`
- Feasibility Probes (donde aplique): 1.5-2h máx, blocking, sin probe verde no avanza

### Gate de autonomía

Savia ejecuta **sin pedir permiso** cuando:
- ✓ La spec está PROPOSED y aplica principios Spec Ops
- ✓ No toca hardware, infra externa, billing, legal
- ✓ No rompe Rule #8 (jamás merge autónomo)
- ✓ Tests + /pr-plan verdes

Savia **pide luz verde** cuando:
- ✗ La spec cambia arquitectura de seguridad (ej. SPEC-SE-028 prompt injection)
- ✗ Añade nueva dependencia >50MB (ej. torch CPU)
- ✗ Modifica CLAUDE.md o reglas de dominio críticas
- ✗ Toca `.claude/settings.json` hooks chain

### Orden sugerido de ejecución (iteración-friendly)

Serie 1 — quick wins (1 slice c/u):
1. A4 → crear SE-035 spec + skill `mutation-audit` (1.5h)
2. A5 → consolidar SE-031 query-cache section
3. B4 → SPEC-081 hook bats coverage (extender)
4. B5 → SPEC-082 orphan skill fix
5. D1 → spec-status-normalize.sh + bulk label

Serie 2 — value champions (Feasibility Probes blocking):
6. A1 Slice 1 → SE-032 probe reranker (2h) — gate
7. A2 Slice 1 → SE-033 probe BERTopic (1.5h) — gate
8. B1 Slice 1 → SE-028 oumi probe

Serie 3 — seguridad + compliance (lock):
9. C1 SPEC-SE-028 prompt injection guard (pedir luz verde explícita antes)
10. C4 SPEC-SE-031 delegation toolset enforcement
11. C14 SPEC-SE-026 compliance evidence docs + hooks

Serie 4 — GraphRAG + enterprise federation:
12. B3 SE-030 GraphRAG quality gates
13. C12 SPEC-SE-023 knowledge federation (converge con B3)

Serie 5 — UX + self-improvement:
14. C3 SPEC-SE-030 skill self-improvement pipeline
15. C5 SPEC-SE-032 cross-project lessons
16. C7 SPEC-SE-034 daily agent activation plan

Serie 6 — deuda técnica:
17. D2, D3, D4, D5

### Criterios de parada

Savia se detiene (NO crasha, NO continúa ciega) cuando:
- Contexto >80% — ejecuta `/compact` y reevalúa
- 3 fallos consecutivos en un mismo slice — escala a Mónica
- Gate autonomía falla — escribe propuesta + espera luz verde
- `/pr-plan` rojo irrecuperable — documenta en output/ y pasa al siguiente

### Métricas de éxito del roadmap

- Al menos 5 slices verdes por semana (sin merge autónomo)
- 0 incidentes rule #8 (merge autónomo)
- Test-auditor score medio ≥85 en nuevos bats
- Latencia hooks ≤20ms arranque
- Savia registra cada slice en `output/agent-runs/{YYYY-MM-DD}-audit.log`

---

## Sección D — Memoria viva

Este documento se actualiza:
- Cada merge completo de wave (mover a DONE)
- Cada research nuevo que genere champion (añadir a Wave 1)
- Cada vez que Mónica pide pivot (registrar razón)

Campo `expires: 2026-06-18` — si para entonces no se ha iterado ≥50% de Wave 1+2, re-review obligatorio. No zombie specs.

## Referencias

- Specs individuales: `docs/propuestas/SPEC-*.md`, `docs/propuestas/SE-*.md`, `docs/propuestas/savia-enterprise/SPEC-SE-*.md`
- Roadmap previo (superseded en parte): `docs/propuestas/SAVIA-SUPERPOWERS-ROADMAP.md`
- Development plan enterprise: `docs/propuestas/savia-enterprise/DEVELOPMENT-PLAN.md`
- Research outputs locales: `output/research-*.md`
- Safety gate: `docs/rules/domain/autonomous-safety.md`
- Spec Ops principles: aplicados en SE-032/033/034 frontmatter
