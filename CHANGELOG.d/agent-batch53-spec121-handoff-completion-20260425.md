## [6.4.0] — 2026-04-25

Batch 53 — SPEC-121 handoff-as-function convention **IMPLEMENTED** (3 ACs faltantes completados).

### Changed
- `.claude/agents/sdd-spec-writer.md` — sección "Handoff Format (SPEC-121)" añadida: E1→E2 handoff a dotnet-developer tras spec approval.
- `.claude/agents/dotnet-developer.md` — sección "Handoff Format (SPEC-121)" añadida: E2→E3 handoff a code-reviewer tras implementation + tests green.
- `.claude/agents/code-reviewer.md` — sección "Handoff Format (SPEC-121)" añadida: E3→E4 a test-engineer (PASS) o developer (REJECT con termination_reason=unrecoverable_error).
- `.claude/agents/test-engineer.md` — sección "Handoff Format (SPEC-121)" añadida: E4 completion a court-orchestrator.
- `.claude/agents/court-orchestrator.md` — sección "Handoff Format (SPEC-121)" añadida: REJECT routing back a dotnet-developer.
- `docs/agent-notes-protocol.md` — sección "Cuándo usar agent-notes vs handoff-as-function" añadida con tabla de decisión y regla práctica ("si cabe en 7 campos, usa handoff-as-function").
- `docs/propuestas/SPEC-121-handoff-convention.md` — status PROPOSED → IMPLEMENTED. Resolution section con 6/6 ACs cumplidos.

### Context
SPEC-121 AC-01/03/04 ya estaban implementados desde batches previos (validator extendido, bats certified 81, protocol doc). Este PR completó los 3 AC faltantes: actualizaciones de los 5 agentes piloto (AC-02), cross-doc en agent-notes-protocol (AC-05), y CHANGELOG (AC-06).

Diseño aditivo: los cambios son secciones opcionales que guían el output del agente. Sin ruptura de comportamiento existente. El protocolo longform agent-notes se mantiene para casos que requieren párrafos.

Version bump 6.3.0 → 6.4.0.
