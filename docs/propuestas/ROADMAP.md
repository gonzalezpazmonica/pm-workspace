---
id: ROADMAP
title: Savia Roadmap — Canonical single source of truth
status: LIVING
author: Savia (autoselección + consolidación)
origin: Consolidación de SAVIA-SUPERPOWERS-ROADMAP.md + ROADMAP-UNIFIED-20260418.md + savia-enterprise/DEVELOPMENT-PLAN.md + debt specs SE-036..039
supersedes: SAVIA-SUPERPOWERS-ROADMAP.md, ROADMAP-UNIFIED-20260418.md (partial)
last_updated: "2026-04-18"
expires: "2026-06-18"
---

# Savia Roadmap — Canonical

> **Único documento sobre el que Savia itera autónomamente**. Reemplaza 3 roadmaps previos (ver §Supersedes). Se actualiza en cada PR merged.
>
> **Principios inmutables** (heredados de `autonomous-safety.md` + `DEVELOPMENT-PLAN.md`):
> - Soberanía del dato — `.md` es la verdad
> - Independencia del proveedor — adaptadores, no acoplamiento
> - Honestidad radical — tests en rojo se dicen, no se esconden
> - Privacidad absoluta — N4 jamás sale
> - El humano decide — la usuaria revisa cada PR. Cero merge autónomo (Rule #8)
> - Igualdad — Equality Shield
> - Protección de identidad — Savia sigue siendo Savia
>
> **Spec Ops (McRaven)**: Simplicity, Repetition (Feasibility Probe), Speed (Slicing), Purpose (cost-of-inaction), Theory of Relative Superiority (expires)

---

## 0. Estado (snapshot 2026-04-18)

**Repo state**: 130+ specs en `docs/propuestas/` + 37 savia-enterprise SPEC-SE-*
**Activos (PROPOSED/ACCEPTED/Draft/IN_PROGRESS)**: 31
**Legacy sin status field**: 111 (visibilizados via `spec-status-normalize.sh`)
**Research outputs 2026-04-18 consolidados**: coderlm, Bluesky, MindStudio, Spec Ops, Hands-On LLM, Dify, Mutation Testing (Gómez Corio)

**Merged recientes (era 234)**:
- PRs #598–#608: pr-plan G5b+G6b, ast-comprehension RLM, SCM determinism, SCM freshness gate, bounded concurrency doctrine, MCP overhead audit, SE-032/033/034 specs, unified roadmap, SPEC-082 orphan fix, spec-status-normalize, debt specs

---

## 1. Queue autonomy-viable — orden de ejecución

Savia itera top-down. Cada ítem = 1 slice = 1 PR Draft. Criterio de salto: si Feasibility Probe falla, abort spec + documenta razón.

### Tier 1 — Probes de deuda (read-only, high signal)

Todos Slice 1 de sus specs — solo mediciones, no cambian código. Producen ground truth para decidir remediación.

| # | Spec | Acción concreta | Time-box |
|---|---|---|---|
| 1.1 | SE-037 Slice 1 | Hook bench sobre 60 hooks (`hook-bench.sh --all`) | 1h |
| 1.2 | SE-038 Slice 1 | Agent size scan (`agent-size-audit.sh`) sobre 65 agentes | 1h |
| 1.3 | SE-039 Slice 1 | Test-auditor sweep (`audit-all-bats.sh`) sobre 100+ `.bats` | 2h |
| 1.4 | SE-036 Slice 1 | Migración batch Implemented confirmados (30 specs) | 2h |

**Valor**: tras Tier 1 sabemos cuánta deuda real hay. Si una categoría no tiene problema, su spec queda ABORT/CLOSED automáticamente.

### Tier 2 — Champions research (Feasibility Probes blocking)

| # | Spec | Feasibility Probe | Gate decision |
|---|---|---|---|
| 2.1 | SE-032 Slice 1 | Reranker cross-encoder sobre 20 queries reales (2h) | precision@5 ≥ 80% → continue |
| 2.2 | SE-033 Slice 1 | BERTopic sobre 50 retros reales (1.5h) | ≥3 clusters útiles → continue |
| 2.3 | SE-035 Slice 1 | Mutation testing 3 módulos (1.5h) | score baseline >30% → continue |
| 2.4 | SE-028 Slice 1 | oumi data synth para SLM (2h) | 500+ samples válidos → continue |

Si TODOS los probes de Tier 2 aprueban: tenemos 4 capacidades nuevas con evidence empírico de ROI. Si fallan, documentamos y cerramos (valor del probe es evitar specs zombies).

### Tier 3 — Seguridad (requiere luz verde humana antes)

| # | Spec | Motivo del gate humano |
|---|---|---|
| 3.1 | **SPEC-SE-028** prompt injection guard | P0. Cambia arquitectura de seguridad. Savia escribe propuesta, espera luz verde explícita de la usuaria antes de implementar. |

### Tier 4 — PROPOSED maduros (iteración directa)

Orden por dependencia:

| # | Spec | Dependencia | Por qué ahora |
|---|---|---|---|
| 4.1 | SE-029 rate-distortion context compression | Savia Dual Compact v2 | Alto impacto en tokens/sesión |
| 4.2 | SE-030 GraphRAG quality gates | SPEC-027 merged | Converge con SPEC-SE-023 federation |
| 4.3 | SE-034 workflow node typing | Independiente | DAG quality of life |
| 4.4 | SPEC-102 opendataloader-pdf | pdf-digest merged | Determinismo de output |
| 4.5 | SPEC-103 deterministic-first digests | SPEC-102 probe | Consistencia cross-digests |
| 4.6 | SPEC-107 AI cognitive debt mitigation | — | Research-heavy, medium urgency |
| 4.7 | SPEC-108 agent self-improvement + Sentry RCA | parcial merged | Closing loop |
| 4.8 | SPEC-099 gitagent export adapter | — | Portabilidad futura |
| 4.9 | SPEC-100 GAIA benchmark integration | — | Validación externa |

### Tier 5 — Enterprise SE-XXX absorbidos

Del ex-DEVELOPMENT-PLAN.md savia-enterprise, iterable autónomamente sin infra externa:

| # | Spec | Título | Por qué autonomy-viable |
|---|---|---|---|
| 5.1 | SE-011 | Docs restructuring | Solo docs — zero riesgo |
| 5.2 | SE-012 | Signal-noise reduction | Solo docs + hooks |
| 5.3 | SE-001 | Foundations (docs-portion) | Docs + scripts de setup |
| 5.4 | SE-013 | Dual estimation (agent vs human) | Merge con SPEC-078 |
| 5.5 | SPEC-SE-026 | Compliance evidence (ISO/SOC2) | Docs + hooks auto-generables |
| 5.6 | SPEC-SE-029 | Iterative compression | Converge con SE-029 |
| 5.7 | SPEC-SE-030 | Skill self-improvement pipeline | Sobre 77 skills existentes |
| 5.8 | SPEC-SE-031 | Delegation toolset enforcement | Extensión policy-check existente |
| 5.9 | SPEC-SE-032 | Cross-project lessons pipeline | Extiende lesson-extract skill |
| 5.10 | SPEC-SE-033 | Context rotation strategy | Depende de SE-029 |
| 5.11 | SPEC-SE-034 | Daily agent activation plan | Extiende daily-plan skill |
| 5.12 | SPEC-SE-020 | Cross-project deps | Extensión portfolio-deps |
| 5.13 | SPEC-SE-021 | Code Review Court (+pr-agent) | Converge con SPEC-124 |
| 5.14 | SPEC-SE-023 | Knowledge federation | Converge con SE-030 |
| 5.15 | SPEC-SE-025 | Agentic workforce analytics | Docs + script analyzer |
| 5.16 | SPEC-SE-002 | Multi-tenant & RBAC | Workspace isolation via scripts + configs |
| 5.17 | SPEC-SE-003 | MCP server catalog | Catalog tooling sobre `.claude/mcp.json` |
| 5.18 | SPEC-SE-004 | Agent framework interop | Adapters a LangGraph/AutoGen/CrewAI — docs + wrappers |
| 5.19 | SPEC-SE-006 | Governance & compliance pack | Policies + audits automatizables |
| 5.20 | SPEC-SE-009 | Observability stack (agnóstico) | Autosufficient local mode (SE-005 sovereign) |
| 5.21 | SPEC-SE-010 | Migration path & backward compat | Docs + migration scripts |
| 5.22 | SPEC-SE-014 | Release orchestration | Adapters + templates (deploy humano en prod, autónomo en staging) |
| 5.23 | SPEC-SE-022 | Resource & bench management | Benchmarking scripts |
| 5.24 | SPEC-SE-024 | Client health intelligence | Signals aggregation scripts |
| 5.25 | SPEC-SE-027 | SLM training pipeline | Ya merged (base) — extensiones opt-in |

### Tier 6 — Convergencias / consolidaciones

Specs que deberían fusionarse o renombrarse:

- SPEC-081 hook BATS coverage → **absorbido por SE-037**
- SPEC-078 dual estimation ↔ SPEC-SE-013 → **candidato a consolidar**
- SPEC-028 search-reranker ↔ SE-032 → **posible duplicación — auditar**
- SPEC-027 graph ↔ SPEC-123 graphiti → **converge con SE-030**

### Tier 7 — Backlog frío

111 specs sin frontmatter YAML migrarán via SE-036 Slices 2/3. Tras migración, se reclasifican automáticamente por status.

---

## 2. Sección diferida — hardware / humans required

Savia NO escribe código. Puede mantener spec updated + documentar cuando la usuaria ejecuta manualmente.

| Spec | Motivo | Responsable humano |
|---|---|---|
| SPEC-006 ZeroClaw | Hardware físico | la usuaria |
| SPEC-007 ZeroClaw voice | Hardware mic + audio | la usuaria + hardware testing |
| SPEC-008 ZeroClaw meeting digest | Hardware + humanos en reunión | la usuaria |
| SPEC-004 Robotics vertical | Hardware | la usuaria |
| SPEC-005 Physical assembly | Hardware + monta humano | la usuaria |
| SPEC-009 Savia Teams participant | Cuenta Teams + humanos | la usuaria + Teams admin |
| SPEC-021 Readiness (parte hw) | GPU, TPM, USB reales | la usuaria |
| SPEC-064 Computer use integration | Entorno GUI dedicado | la usuaria |
| SPEC-SE-005 Sovereign deployment | Ops humano (k8s, vault, DNS) | DevOps |
| SPEC-SE-007 Enterprise onboarding | Ciclo comercial | Sales |
| SPEC-SE-008 Licensing distribution | Legal + billing humano | Legal + finance |
| SPEC-SE-015/016/017/018/019 | Prospect/valuation/definition/billing | Pre-sales + finance |

---

## 3. Estrategia de iteración

### Cadencia

- 1 slice = 1 rama `agent/{spec-id}-slice{N}-{YYYYMMDD}` = 1 PR Draft
- Reviewer obligatorio: `@gonzalezpazmonica`
- Nunca merge autónomo (Rule #8)

### Gates por slice

1. `commit-guardian` pre-commit
2. `/pr-plan` (13 gates G0-G10 + G5b extended CI + G6b test quality)
3. `confidentiality-sign.sh sign`
4. `git push origin agent/...`
5. `gh pr create --draft --reviewer @gonzalezpazmonica`

### Puntos de escalación (Savia se detiene)

- Context >85% sin `/compact` útil
- 3 fallos consecutivos mismo slice
- `/pr-plan` rojo irrecuperable
- Gate de autonomía falla (Tier 3, arquitectura de seguridad)
- Conflicto con principios inmutables

### Presupuesto por spec

~40-80K tokens efectivos tras compactaciones. Si spec supera 120K sin cerrar slice → romper en sub-slices y crear PR parcial.

### Métricas de salud

- ≥5 slices verdes/semana
- 0 incidentes Rule #8
- Test-auditor score medio ≥85 en tests nuevos
- Latencia hooks críticos ≤20ms p50
- Cero regresiones en tests existentes por slice

---

## 4. DAG de dependencias (crítico)

```
SE-035 (mutation) ────┐
                      ├── SE-039 (test-auditor sweep) ── ci-gate
SE-037 (hook lat) ────┘
                      
SE-036 (frontmatter) ──── unlocks grep-tooling on 111 specs
                      
SE-032 (reranker) ────┬── SE-030 (GraphRAG quality) ── SPEC-SE-023 (federation)
SPEC-027 (graph) ─────┘
                      
SE-029 (rate-distortion) ── SPEC-SE-029 / SPEC-SE-033 (context rotation)
                      
SPEC-SE-028 (prompt injection) ── independient, P0 security
                      
SPEC-102 ── SPEC-103 ── SPEC-104 (pdf determinism chain)
```

Caminos críticos:
- **Seguridad**: SPEC-SE-028 (independient, priorizar)
- **Visibilidad**: SE-036 → habilita herramientas grep/jq confiables
- **Calidad**: SE-037 + SE-039 → SLA sobre 60 hooks + 100+ tests
- **Intelligence**: SE-032 + SE-030 + SPEC-SE-023 → stack RAG completo

---

## 5. Consolidaciones pendientes

| Candidato | Acción propuesta |
|---|---|
| SAVIA-SUPERPOWERS-ROADMAP.md | SUPERSEDED por este roadmap — archivar |
| ROADMAP-UNIFIED-20260418.md | SUPERSEDED parcialmente — archivar o referenciar solo §Iteration strategy |
| savia-enterprise/DEVELOPMENT-PLAN.md | DAG absorbido en §Tier 5. Mantener como doc histórica-only de savia-enterprise |
| SPEC-081 hook bats coverage | Marcar SUPERSEDED BY SE-037 |
| SPEC-028 search-reranker | Auditar duplicación con SE-032 |

Estas consolidaciones se ejecutan en un follow-up PR tras este roadmap aterrizar.

---

## 6. Live status (se actualiza cada PR merged)

### En curso — ninguna spec simultánea
### Próximo slice recomendado — **Tier 1.1 SE-037 Slice 1** (hook bench)
### Último PR merged — #608 debt specs SE-036/037/038/039 + consolidación Wave 4

---

## 7. Roadmaps superseded (histórico)

Estos documentos se mantienen en repo por razones de auditoría pero ya no son fuente de verdad:

- `docs/propuestas/SAVIA-SUPERPOWERS-ROADMAP.md` — 2026-04-17, SPEC-120..124 (todos merged PRs #592–#594). Tachado.
- `docs/propuestas/ROADMAP-UNIFIED-20260418.md` — 2026-04-18 v1, absorbido en este roadmap. Mantener Sección C (iteration strategy) como referencia histórica.
- `docs/propuestas/savia-enterprise/DEVELOPMENT-PLAN.md` — 2026-04-11, onda 0-3 savia-enterprise. DAG consolidado en §Tier 5; mantener doc para detalle histórico de contrato de ejecución.

---

## 8. Referencias

- `docs/rules/domain/autonomous-safety.md` — Rule #8 + gates
- `docs/rules/domain/bounded-concurrency.md` — doctrina anti-fork-bomb
- `docs/rules/domain/mcp-overhead.md` — doctrina MCP
- `docs/rules/domain/query-library-protocol.md` — RLM pattern
- `.claude/skills/` (77 skills)
- `.claude/agents/` (65 agents)
- `tests/` (100+ .bats)
- `output/agent-runs/` — auditoría de sesiones autónomas
