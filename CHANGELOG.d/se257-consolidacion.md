---
spec: SE-257
---

## SE-257 — Consolidacion post-programa

### Slice 1 — CRITERIO.md con 33 entradas propuestas (Anexo A)

33 entradas INFERRED iteradas contra 4 fuentes de alineamiento: valores de la
operadora, CONSTITUCION T1-T5, conocimiento del workspace, guardrails en disco.
Iteracion 2 con correcciones directas. scripts/criterio-validate.sh. 10 BATS.

### Slice 2 — Memoria: modelo canonico, liveness-check

docs/memory-architecture.md con decision por paradigma. scripts/memory-liveness-check.sh
en CI. Cero huerfanos tras excluir .pyc y test-*.

### Slice 4 — CI: timeouts, concurrency

timeout-minutes en todos los jobs (15/60/15/10/5). cancel-in-progress en PR.
memory-liveness-check en el validate job.
