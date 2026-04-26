---
id: SE-076
title: SE-076 — QueryWeaver pattern adoption — graphiti episodic + schema-graph WIQL + LLM healer
status: APPROVED
origin: FalkorDB/QueryWeaver repo study 2026-04-26
author: Savia
priority: media
effort: M 9h (3 slices independientes)
related: SPEC-027, memory-graph, WIQL skills, NL-query
approved_at: "2026-04-26"
applied_at: null
expires: "2026-06-26"
era: 188
---

# SE-076 — QueryWeaver pattern adoption

## Why

QueryWeaver (FalkorDB/QueryWeaver, 958 stars, AGPL-3.0, 2025-07 origen) es Text2SQL con grafo de propiedad para guiar generación SQL. Análisis 2026-04-26 identifica 3 patrones extractables sin adoptar la infra (FalkorDB + AGPL bloqueantes).

Cost of inaction:
- **SPEC-027 Phase 2 indefinido**: el grafo de memoria está en Phase 1 (entity extraction) sin upgrade a episodes + TTL. Patrón Graphiti resuelve sin nueva dependencia.
- **WIQL hallucinations**: el skill NL→WIQL hoy genera queries inválidas con cierta frecuencia (Area Paths inexistentes, fields tipados mal). Schema-as-graph reduce 30-50% según QueryWeaver benchmarks.
- **Sin retry self-correct**: cuando una query LLM falla, hoy se devuelve error al usuario. Healer pattern añade auto-retry con feedback del error.

## Scope (3 slices independientes)

### Slice 1 (M, 4h) — Graphiti episodic memory model en JSONL

Sin dependencia FalkorDB ni graphiti-core (AGPL bloqueante). Implementar el PATRÓN sobre infra existente:

- Nuevo tipo `episode` en `memory-store.sh save` (ya hay `episodic` sector, falta el modelo episode-as-first-class)
- Episode = `{type: "episode", title, content, valid_from, valid_to, entities: [refs], TTL}`
- Edge `MENTIONED_IN` entre entity y episode (en `memory-graph.py`)
- Search híbrida: vector (existing) + grafo (entity → episodes que mencionan) + RRF rerank (existing `rerank.py`)
- TTL automático en episodes >90 días salvo `--pin`

### Slice 2 (M, 3h) — Schema-as-graph para WIQL

- Script `scripts/build-azdo-schema-graph.sh` lee schema Azure DevOps (Area Paths, Iteration Paths, work item types, fields, allowed values)
- Output: `output/azdo-schema-graph.json` con nodes (Field, AreaPath, WorkItemType) y edges (HAS_FIELD, BELONGS_TO_AREA, ALLOWED_VALUE)
- Skill NL→WIQL existente lee el grafo antes de generar query → reduce alucinaciones (no inventa Area Paths, no usa fields del tipo equivocado)
- Refresh manual o on-demand cuando schema cambie

### Slice 3 (S, 2h) — LLM healer wrapper

- `scripts/lib/llm-healer.sh` — función reusable: ejecutar query, si falla con error parseable, alimentar error al LLM con prompt corrector, reintentar (máx 3 intentos)
- Integrar en NL→WIQL skill como wrapper opcional `--heal`
- Métrica: % queries que se recuperan tras healing (visible en stats)

## Acceptance criteria

### Slice 1
- [ ] AC-01 `memory-save.sh` acepta `--type episode` con `valid_from/valid_to` y `entities` (lista refs)
- [ ] AC-02 `memory-graph.py` añade edge type `MENTIONED_IN`
- [ ] AC-03 `memory-search.sh` modo híbrido (`--mode hybrid`) combina vector + grafo + rerank
- [ ] AC-04 TTL automático verificado en tests
- [ ] AC-05 Tests BATS ≥18 score ≥80
- [ ] AC-06 Doc en `docs/rules/domain/episodic-memory.md`

### Slice 2
- [ ] AC-07 `scripts/build-azdo-schema-graph.sh` produce JSON válido con nodes + edges desde Azure DevOps API
- [ ] AC-08 NL→WIQL skill lee el grafo y rechaza queries con Area Paths/fields no presentes en grafo (con mensaje explicativo)
- [ ] AC-09 Métrica antes/después: % queries WIQL inválidas en 50 ejemplos de prueba
- [ ] AC-10 Tests BATS ≥12

### Slice 3
- [ ] AC-11 `scripts/lib/llm-healer.sh` función reusable con 3 reintentos máx
- [ ] AC-12 Wrapper `--heal` opt-in en NL→WIQL skill
- [ ] AC-13 Métrica de recovery rate en stats
- [ ] AC-14 Tests BATS ≥10

## No hacen

- NO instala FalkorDB ni Redis-graph
- NO añade dependencia graphiti-core (AGPL-3.0 incompatible con licensing pm-workspace si se publica)
- NO sustituye `memory-graph.py` Phase 1 — lo extiende
- NO toca el skill NL→WIQL más allá del wrapper opt-in (Slice 2/3 son add-ons)
- NO genera Text2SQL para bases de datos arbitrarias (Savia no tiene caso de uso)

## Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| AGPL contagion si se importa código de QueryWeaver | Media | Alto | NO copiar código, solo replicar patrón. Tests BATS verifican implementación independiente |
| Episodes degradan rendimiento de memory-search | Media | Medio | Hybrid mode opt-in; legacy mode default |
| Schema-graph queda desactualizado vs Azure DevOps real | Alta | Medio | Refresh on-demand documentado; staleness check en skill |
| Healer entra en loop con errores no determinísticos | Media | Bajo | Hard cap 3 reintentos; log de intentos visible |
| Slice 2 expone datos privados de Azure DevOps a LLM | Alta | Alto | Schema-graph contiene SOLO metadata (nombres de campos, tipos), nunca valores. Auditoría en compliance-gate hook |

## Dependencias

- Slice 1 puede arrancar inmediatamente (independiente de Slice 2/3 y de SE-074/SE-075)
- Slice 2 requiere SE-072 verified-memory para no contaminar memoria con queries fallidas
- Slice 3 independiente de los anteriores
- Sinergia con SE-075 Slice 1 (`task_queue.py`): healer puede usarlo para reintentos asíncronos

## Comparativa vs status quo

| Capacidad | Hoy | Post Slice 1 | Post Slice 1+2+3 |
|---|---|---|---|
| Memoria episódica con TTL | ❌ | ✅ | ✅ |
| Hybrid search (vector + grafo) | Vector only | ✅ | ✅ |
| WIQL hallucination rate | ~20% (estimado) | ~20% | ~5-10% (target) |
| Auto-recovery de queries fallidas | ❌ | ❌ | ✅ |

## Referencias

- `https://github.com/FalkorDB/QueryWeaver` — repo origen (AGPL-3.0, 958 stars, push 2026-04-21)
- `https://github.com/getzep/graphiti` — graphiti-core, modelo episodic original (también AGPL — patrón se replica, no se importa)
- SPEC-027 Phase 1 — `scripts/memory-graph.py` ya existente
- SE-072 Verified Memory — pre-requisito ético (Slice 2)
- SE-074 — task_queue.py podrá ser usado por Slice 3 healer
- SE-075 Slice 1 — sinergia con healer async retries

## OpenCode Implementation Plan

**Portability classification**: PURE_BASH

Los 3 slices son backend puro:

- **Slice 1 (Graphiti episodic JSONL)**: extiende `scripts/memory-graph.py` y `scripts/memory-store.sh`. Sin acoplamiento a frontend.
- **Slice 2 (Schema-graph WIQL)**: skill en `.claude/skills/wiql-schema-graph/` invocable desde AGENTS.md (SE-078). Sin hooks específicos de Claude Code.
- **Slice 3 (LLM healer)**: wrapper Bash + Python alrededor de cualquier LLM CLI (Claude, Codex, modelos locales vía Ollama). El frontend que invoca al healer es indiferente.

**OpenCode binding**: ninguno necesario. El healer puede invocarse desde OpenCode v1.14 igual que desde Claude Code mediante AGENTS.md (slash command o skill autoload).

**Validación post-replatform (SE-077)**: tras switch, ejecutar:
- `bash tests/structure/test-memory-graph.bats` (Slice 1)
- `bash scripts/wiql-schema-audit.sh --selftest` (Slice 2)
- `bash scripts/llm-healer-smoke.sh` (Slice 3)

para confirmar paridad funcional sin Claude Code.

**Riesgo OpenCode-específico**: Slice 2 (schema-graph WIQL) depende de variable `$AZURE_DEVOPS_PAT` accesible en runtime. OpenCode hereda env vars como Claude Code, sin diferencia operativa.
