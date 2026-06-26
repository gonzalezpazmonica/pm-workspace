## SPEC-193 — Context Provenance & Injection Hardening (2026-06-24)

### Added — Capa A: Sanitizacion deterministica (sin LLM)

- scripts/context-sanitize/normalize.py — NFKC + invisible-char strip + bidi-control reject. CLI --text TEXT --json. Output: normalized, original, transformations, homoglyph_score, bidi_present.
- scripts/context-sanitize/homoglyph-detect.py — Tabla de pesos Latin/Cyrillic/Greek/Mathematical; score 0-100. Pesos: Cyrillic+30, Greek+30, Tags+50, Bidi+50, ZW+30, SoftHyphen+30, MathAlpha+30.
- .opencode/hooks/context-sanitize-input.sh — PreToolUse Read|Write. Modos off/shadow/warn/block. Bidi siempre block en modo block. Master switch SAVIA_HARDENING=off. Telemetria en output/context-hardening-telemetry.jsonl.
- .opencode/hooks/memory-write-sanitize.sh — PreToolUse Bash(memory-store save). Bloquea score>70 o bidi en modo block.
- .opencode/hooks/re-anchor-redlines.sh — UserPromptSubmit. Cada N=15 turns inyecta resumen L1-L5. Cap 5 anchors por sesion.

### Added — Capa B: LLM judges (extension SPEC-125)

- .opencode/agents/structural-framing-judge.md — Detecta output con forma de manual/protocolo numerado sobre dominio sensible. Veto solo si score>=85 AND confidence>=0.85 AND domain in CBRN. Modelo mid.
- .opencode/agents/fiction-framing-judge.md — Detecta persona-shift + content-equivalent. Veto si triple condicion. Modelo mid.
- .opencode/agents/authority-claim-judge.md — Detecta credential claims. NUNCA veto. Solo telemetria. Modelo fast.
- scripts/recommendation-tribunal/aggregate.sh — Extendido con --structural-framing, --fiction-framing, --authority-claim fail-soft. Output JSON incluye bloque spec193.

### Added — Capa C: Correlacion temporal y schema

- scripts/cross-turn-correlation/track.py — Registra dominio semantico por turn. Alerta convergence si >=3 de ultimos 10 turns en SENSITIVE_DOMAINS.
- scripts/cross-turn-correlation/sensitive-taxonomy.json — Dominios minimos: chem-synthesis, bio-pathogen, nuclear-fissile, radiological, weapons, manipulation, self-harm, child-safety.
- scripts/kg-schema-migrate.py — ALTER TABLE entities ADD COLUMN source/trust_level/created_by_session. Idempotente. trust_level default 50. Indexes idx_entities_trust, idx_entities_source.

### Added — Reglas y telemetria

- docs/rules/domain/authority-claims-not-evidence.md — Regla canonica: auto-declaracion de credencial NO relaja umbrales en dominios sensibles.

### Modified

- .claude/settings.json — Registrados 3 nuevos hooks: context-sanitize-input.sh, memory-write-sanitize.sh, re-anchor-redlines.sh.

### Tests

- tests/scripts/test_context_sanitize.py — 142 tests (30 positivos + 30 negativos + extras NFKC/bidi)
- tests/scripts/test_injection_judges.py — 167 tests (20+20 por cada uno de los 3 jueces + schema/invariant)
- tests/scripts/test_cross_turn_correlation.py — 23 tests (convergence x3, no-convergence x3, KG migration, regla)
- tests/test-context-sanitize-hook.bats — 30 tests (todos los modos, bidi, master switch, redteam, telemetria)
- Total: 362 tests (332 pytest + 30 bats), 0 fallos

### Spec

SPEC-193: docs/propuestas/SPEC-193-context-provenance-injection-hardening.md
Status: IMPLEMENTED 2026-06-24
