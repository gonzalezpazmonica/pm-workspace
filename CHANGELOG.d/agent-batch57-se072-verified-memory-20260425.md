## [6.8.0] — 2026-04-25

Batch 57 — SE-072 Verified Memory axiom **IMPLEMENTED** (Slice 1 MVP). **Era 188 inaugural** post Era 187 closure.

### Added
- `scripts/memory-save.sh` — `cmd_save` extendido con `--source <origin>` flag obligatorio. Valida format (4 sources OK: `tool:*`, `file:*:*`, `verified:*`, `user:explicit`), rechaza blacklist (`speculation`, `plan`, `intent`, `draft`, `hypothesis`). Source embeded en JSONL output. Escape hatch: `SAVIA_VERIFIED_MEMORY_DISABLED=true`.
- `.claude/hooks/memory-verified-gate.sh` — PreToolUse Write hook bloquea auto-memory writes sin citation pattern. 5 patrones aceptados: file reference, markdown link, Source/Ref keyword, URL, frontmatter type. Skipped: MEMORY.md, session-journal.md, session-hot.md, session-summary.md.
- `tests/test-memory-verified-gate.bats` — 33 tests certified score 94. Cubre block/pass/skip, escape hatch, edge cases (empty content, large content, malformed JSON), isolation.
- `docs/rules/domain/verified-memory-axiom.md` — política completa con rationale, ejemplos correcto/rechazado, escape hatch, política de evolución.

### Changed
- `.claude/settings.json` — registra `memory-verified-gate.sh` en PreToolUse Edit|Write con timeout 5s.
- `tests/test-memory-store.bats` — 9 tests SE-072 nuevos (rechaza sin source, blacklist, format inválido, source válido tool/file/user, JSONL embed, escape hatch). 3 tests existentes actualizados con `--source tool:Bats`. Score 90.
- `docs/propuestas/SE-072-verified-memory-axiom.md` — APPROVED → IMPLEMENTED. Resolution con 5/5 ACs.
- `CLAUDE.md` — hooks 59→60 (64 regs).

### Context
Primera spec del backlog APPROVED post Era 187. Establecido el axioma "No Execution, No Memory" de GenericAgent: memoria persistente debe reflejar hechos verificados. Memoria existente NO migrada (grandfathering). User puede forzar bypass con `--source user:explicit` o env var.

Hook coverage 59/59 → 60/60 (100% mantenido).

Próximo: SE-073 Memory Index Cap Tiered (siguiente APPROVED).

Version bump 6.7.0 → 6.8.0.
