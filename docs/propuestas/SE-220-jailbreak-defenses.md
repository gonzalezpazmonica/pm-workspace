---
spec_id: SE-220
title: "Jailbreak defenses + context distribution optimization"
status: APPROVED
priority: P2
effort: M
era: 206
origin: docs research — informe jailbreak agentes IA 2025-2026
inspiration: |
  Constitutional Classifiers (Sharma 2025, arXiv:2501.18837)
  CaMeL — Defeating Prompt Injections by Design (Debenedetti 2025, arXiv:2503.18813)
  Design Patterns for Securing LLM Agents (Beurer-Kellner 2025, arXiv:2506.08837)
  AgentPoison (Chen 2024, arXiv:2407.12784)
  Spotlighting (Hines 2024, arXiv:2403.14720)
deps:
  - scripts/memory-store.sh (implemented)
  - scripts/memory-hygiene.sh (implemented)
  - .claude/hooks/prompt-injection-guard.sh (implemented)
  - .claude/hooks/project-isolation-gate.sh (implemented)
  - scripts/agents-catalog-sync.sh (implemented)
  - scripts/generate-capability-map.py (implemented)
  - .claude/hooks/session-init.sh (implemented)
  - AGENTS.md, docs/rules/domain/agents-catalog.md (auto-generated)
created: 2026-06-11
---

# SE-220 — Jailbreak defenses + context distribution optimization

## Contexto

Las defensas modernas contra jailbreak en agentes (Constitutional Classifiers,
Spotlighting, CaMeL, Plan-Then-Execute, Map-Reduce LLM, Context Minimization)
son politicas de gestion de informacion bajo desconfianza. La gestion optima
de contexto distribuido tambien lo es. Son el mismo problema: decidir que
informacion viaja a donde, con que tags, y bajo que politicas.

El informe output/20260611-research-jailbreak-agentes-ia-2025-2026.md y su
sintesis output/20260611-jailbreak-defenses-context-management-pmworkspace.md
documentan el estado del arte y los paralelos. Tres gaps criticos detectados
en pm-workspace son simultaneamente vulnerabilidades de seguridad y costes
de tokens:

1. MEMORY.md roto: 737 lineas vs cap 200, 109 duplicados de
   decision/use-postgresql. Vector ideal para AgentPoison (Chen 2024,
   ASR mayor 80% con poison rate menor 0.1%).
2. Catalogos de agents divergentes: AGENTS.md=70, agents-catalog.md=70 vs
   .opencode/agents/=72. Vector skill confusion / typosquatting.
3. project-isolation-gate.sh solo WARN: cross-project refs no se bloquean.
   Trust zone sin enforcement.

## Objetivo

Aplicar 5 patrones del informe jailbreak como mejoras simultaneas de
seguridad y eficiencia de contexto en pm-workspace.

## Acceptance Criteria

- [x] AC-01 scripts/memory-store.sh _update_memory_index deduplica por
  topic_key (replace-in-place) y enforza soft cap MEMORY_INDEX_SOFT_CAP
  (default 200).
- [x] AC-02 scripts/memory-hygiene.sh apunta al path canonico
  ~/.savia-memory/auto/ (eliminado el legacy
  $HOME/.claude/projects/-home-monica-claude/memory) y deduplica por
  [topic_key] real (no Markdown links obsoletos).
- [x] AC-03 scripts/memory-canary-check.sh (nuevo) verifica invariantes:
  cap lineas, cap tamano 25KB, 0 duplicados, formato canonico, ENTRIES
  markers, canary token. Modos --json, --rotate.
- [x] AC-04 tests/scripts/test-memory-hygiene.bats actualizado al formato
  real (- {type}: {title} [{topic_key}]) y cubre dedup, idempotencia,
  dry-run.
- [x] AC-05 tests/scripts/test-memory-store-index-dedup.bats (nuevo)
  regresion del bug original (109 duplicados de decision/use-postgresql)
  + soft cap + idempotencia (10 tests).
- [x] AC-06 tests/scripts/test-memory-canary-check.bats (nuevo) cubre
  PASS/FAIL invariantes + JSON output + --rotate (15 tests).
- [x] AC-07 .claude/hooks/prompt-injection-guard.sh extendido para escanear
  .md/.txt/.html fuera del workspace (zero-trust spotlighting).
  /tmp/opencode/* excluido como sandbox.
- [x] AC-08 .claude/hooks/project-isolation-gate.sh promovido de WARN a
  BLOCK con override SAVIA_ALLOW_CROSS_PROJECT=1 + audit log en
  output/cross-project-audit.jsonl. set -uo pipefail en linea 2.
- [x] AC-09 tests/test-project-isolation-gate.bats (nuevo) cubre BLOCK,
  override, audit log, savia-web exception, SAVIA_ACTIVE_PROJECT
  precedence (11 tests).
- [x] AC-10 scripts/agents-catalog-sync.sh AGENTS_DIR por defecto =
  .opencode/agents/ (consistente con agents-md-generate.sh).
- [x] AC-11 scripts/generate-capability-map.py lee .opencode/agents/
  (no .claude/agents/); SCM regenerado refleja 72 agents.
- [x] AC-12 AGENTS.md y docs/rules/domain/agents-catalog.md regenerados
  con 72 agents (incluyen code-twin-agent y reconciler previamente
  faltantes).
- [x] AC-13 tests/test-agents-catalogs-sync.bats (nuevo) invariante 3-way:
  count y name set match entre .opencode/agents/, AGENTS.md y catalog
  (9 tests).
- [x] AC-14 .claude/hooks/session-init.sh invoca memory-hygiene.sh y
  memory-canary-check.sh desde el path canonico del workspace (cadena de
  fallback robusta).
- [x] AC-15 tests/test-recommendation-tribunal-hook.bats (nuevo) regresion
  del hook SPEC-125 en shadow mode (passthrough byte-perfect, audit log)
  (10 tests).
- [x] AC-16 CHANGELOG.d fragment con 5 entries Security.
- [x] AC-17 MEMORY.md saneado: 737 a 43 lineas, 36KB a 4KB, 0 duplicados,
  canary .canary en ~/.savia-memory/auto/ con chmod 600.

## Out of scope

- Activacion real (wire) del Recommendation Tribunal Slice 2: Claude Code
  2026-06 no expone aun un evento PreOutput. El hook permanece en shadow
  mode con regression tests; activacion queda para SE futura cuando el
  frontend lo soporte.
- Implementacion de CaMeL (Code-Then-Execute con capabilities): requiere
  DSL custom y interprete, fuera del alcance de un PR de hardening
  incremental.
- Constitutional Classifiers entrenados: requiere infra de fine-tuning +
  eval pipeline.

## Metricas de validacion

- Reduccion tokens MEMORY.md: 36KB a 4KB (89% reduccion).
- Eliminacion drift catalogos: 72 = 72 = 72 (.opencode/agents/ =
  AGENTS.md = agents-catalog.md).
- Cobertura de tests: 79 tests bats nuevos/modificados, todos verdes.
- Defense layers anadidos: 5 (dedup memoria, canary, spotlighting external,
  trust zone enforce, catalog unification).

## Refs

- output/20260611-research-jailbreak-agentes-ia-2025-2026.md — estado del arte.
- output/20260611-jailbreak-defenses-context-management-pmworkspace.md — sintesis.
- AgentPoison (Chen et al. 2024, arXiv:2407.12784).
- Constitutional Classifiers (Sharma et al. 2025, arXiv:2501.18837).
- CaMeL (Debenedetti et al. 2025, arXiv:2503.18813).
- Design Patterns for Securing LLM Agents (Beurer-Kellner et al. 2025,
  arXiv:2506.08837).
- Spotlighting (Hines et al. 2024, arXiv:2403.14720).
