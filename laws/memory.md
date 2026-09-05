# Memory Laws

## LAW-MEMORY-001 — Canonical state
Rejecting a proposed memory mutation MUST NOT alter the current canonical memory state.
- Verificación: memory-write-gate + trust-gated memory (origin check antes de consolidar).

## LAW-MEMORY-002 — Reconstructible
Every derived memory MUST be reconstructible from raw + provenance; deleting raw MUST invalidate derivados.
- Verificación: pipeline SE-384 (task-018 savia-history, provenance obligatoria).
