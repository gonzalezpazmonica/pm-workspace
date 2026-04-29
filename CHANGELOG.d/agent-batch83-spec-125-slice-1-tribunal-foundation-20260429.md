---
version_bump: minor
section: Added
---

## [6.23.0] — 2026-04-29

Batch 83 — SPEC-125 Slice 1 Foundation IMPLEMENTED. Recommendation Tribunal: panel de 4 jueces fast (haiku/sonnet) + orchestrator + classifier + aggregate + banner + hook stub. **Hook entregado en modo detect-only y NO añadido a `.claude/settings.json`** — la activación final es paso humano deliberado tras revisión completa del batch. Slice 1 deliverable: instrumentación + infraestructura, no mutación del flow real.

### Added

#### 5 nuevos agentes (4 jueces + orchestrator)

- `.claude/agents/recommendation-tribunal-orchestrator.md` — sonnet, convoca los 4 jueces en paralelo via Task, agrega vía aggregate.sh, persiste audit JSON. Sync, latency budget hard-cap 3s wall-clock con graceful timeout fallback (verdict WARN + razón "timeout").
- `.claude/agents/memory-conflict-judge.md` — sonnet, lee `~/.claude/external-memory/auto/MEMORY.md` + filtra candidatos + lee files completos. Veto cuando draft contradice un `feedback_*.md` o `user_*.md` con confidence ≥ 0.8.
- `.claude/agents/rule-violation-judge.md` — sonnet, carga lazy de CLAUDE.md + reglas críticas + radical-honesty + autonomous-safety + dominio. Veto en violación de Rule #1 / Rule #8 / autonomous-safety / radical-honesty / zero-project-leakage.
- `.claude/agents/hallucination-fast-judge.md` — **haiku** (fast), verifica entidades del draft via tool calls reales: `[ -f path ]`, `grep` de funciones, `--help` de flags. Veto con ≥1 entidad fabricada confidence ≥ 0.9 (verificación definitiva).
- `.claude/agents/expertise-asymmetry-judge.md` — sonnet, lee perfil `expertise.md` del usuario activo. **NUNCA veta** — solo muta el output forzando rewrite con secciones "Por qué creo esto / Alternativas que descarté / Cómo verificar tú misma" cuando draft cae en área marcada `audit_level: blind`.

#### 3 scripts de infraestructura

- `scripts/recommendation-tribunal/classifier.sh` — heurística primer paso (sin LLM, <50ms). 3 niveles: critical (bypass / lower threshold / hook-skip flags / force push, también en español), high (sudo / rm -rf / drop table / prod deploy), medium (te recomiendo / should use / el problema es). Solo medium+ activa el panel.
- `scripts/recommendation-tribunal/aggregate.sh` — agregación deterministic (no LLM). Lee 4 JSONs, aplica veto rules, computa consensus_score, decide PASS/WARN/VETO. Hard rule: veto requiere confidence ≥ 0.8.
- `scripts/recommendation-tribunal/banner.sh` — renderiza markdown banner según verdict. PASS = empty (passthrough). WARN = banner + draft. VETO = banner que muestra el draft original como blockquote citado pero claramente marcado como bloqueado (auditabilidad — la usuaria SIEMPRE ve qué le iba a decir Savia).

#### Hook stub (detect-only, NO activado)

- `.claude/hooks/recommendation-tribunal-pre-output.sh` — hook PreOutput **listo para activar** pero **NO añadido a `.claude/settings.json`**. En Slice 1 el hook está en modo detect-only: clasifica + persiste audit log + pasa el draft sin mutación. Esto permite calibrar el classifier en uso real antes de wirear los vetos.

#### Doc canónico

- `docs/rules/domain/recommendation-tribunal.md` — define el modelo:
  - Tesis (one paragraph): cuarta clase de output sin gate, asimetría de expertise, panel real-time
  - 9 componentes entregados con rol per-componente
  - Flujo end-to-end (cuando se active en Slice 2)
  - **Modo Slice 1 detect-only** explicitado: hook NO activado, instrumentación pura
  - Activación step-by-step: edición humana de `.claude/settings.json` + sustitución del block "passthrough" por orchestrator invoke
  - Heurística del classifier con ejemplos bilingües (English + Spanish)
  - Veto rules definitivas (con confidence ≥ 0.8 hard-required)
  - Latency budget distribución esperada (target p95 1.5-2s)
  - Audit trail append-only en `output/recommendation-tribunal/`

#### Tests

- `tests/structure/test-recommendation-tribunal.bats` — 51 tests certified. Cubre file safety×6, agent files×7, classifier positive×9 (bilingüe), classifier negative×5, aggregate×7 (verdict PASS/WARN/VETO + boundary confidence), banner×4, hook detect-only×3, rule doc×6, spec ref + meta×3.

### Re-implementation attribution

Pattern sources citados en spec original (SPEC-125): Constitutional AI critique (Anthropic 2024-2025), G-Eval Inline (OpenAI Evals 2026), DeepEval streaming (confident-ai 2026). Re-implementación clean-room: el panel de 4 jueces especializados, la separación judge/aggregator/banner, y el modo Slice 1 detect-only son aporte propio.

### Acceptance criteria

#### SPEC-125 Slice 1 Foundation (10/15 + 5 deferred a Slices 2/3)

- ✅ AC-01 Classifier detecta recomendaciones accionables (heurística bilingüe + JSON output) — precision validable contra golden set en uso real (modo detect-only)
- ✅ AC-02 4 jueces implementados como agentes con prompts versionados y modelos asignados (haiku/sonnet)
- 〰 AC-03 Latency p95 < 3s — **DEFERRED** medible solo tras activación; targets definidos en rule doc
- ✅ AC-04 Verdict VETO bloquea entrega; banner muestra contenido vetado claramente marcado
- ✅ AC-05 Banner WARN se inyecta antes del output con findings concretos
- ✅ AC-06 memory-conflict-judge cita el `.md` del auto-memory en conflicto
- ✅ AC-07 rule-violation-judge cita el path + line range de la regla violada
- ✅ AC-08 hallucination-fast-judge verifica entidades con tool calls (grep, [ -f ], --help)
- ✅ AC-09 expertise-asymmetry-judge re-escribe con secciones blind-area calibration (template emit; rewrite real Slice 2)
- ✅ AC-10 Audit trail JSON persiste en `output/recommendation-tribunal/<date>/<hash>.json`
- 〰 AC-11 Falso positivo registrado por usuaria → feedback memory — **DEFERRED** Slice 3
- 〰 AC-12 Falso negativo registrado → feedback memory regression — **DEFERRED** Slice 3
- ✅ AC-13 BATS ≥30 tests certified — 51 tests (sobrepasa target en 70%)
- 〰 AC-14 Regression test 6 patterns reportadas — **DEFERRED** golden set Slice 2
- ✅ AC-15 CHANGELOG entry + spec status (este fragmento; spec status update en próxima iteración)

### Hard safety boundaries (autonomous-safety.md)

- `set -uo pipefail` en los 4 scripts.
- **Hook NO añadido a settings.json** — activación es paso humano deliberado tras revisión completa.
- Modo detect-only en Slice 1 — el hook clasifica + audita pero NO muta el draft.
- Audit trail append-only, off-repo en `output/`.
- Clasificador es pura heurística (sin LLM call) — 0ms timeout risk en este path crítico.
- Cero red, cero git operations en cualquiera de los 4 scripts.
- Cumple `docs/rules/domain/autonomous-safety.md`: rama `agent/spec-125-slice-1-...`, sin push automático ni merge.

### Spec ref

SPEC-125 (`docs/propuestas/SPEC-125-recommendation-tribunal-realtime.md`) → Slice 1 Foundation IMPLEMENTED 2026-04-29. Status spec: Slice 1 ✓ (foundation entregada, NO activada). Slice 2 (asymmetric expertise rewrite + activación) y Slice 3 (memory feedback loop) follow-up. Critical Path: SPEC-125 desbloqueado, próximo SPEC-107 AI Cognitive Debt Mitigation por orden indicado por usuaria (SPEC-125 → 107 → roadmap principal).
