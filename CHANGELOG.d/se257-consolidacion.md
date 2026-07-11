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

### Slice 3 — Operacion RY attributiva

Staged en docs/criterio-scenarios.md. Espera sesion humana de la operadora
(mismo bloque de 90 min que S1). Ver scripts/relacion-capture.sh,
scripts/relacion-detect-conflicts.sh.

### Slice 5 — Skill tiering

ABANDONED (decision SE-258 S4). El tiering de skills (campo maturity en SKILL.md)
se especifico pero no se implemento en #898. Motivo: los 120 SKILL.md cumplen su
funcion sin campo tier. Se delega a spec futura si la operadora decide que el
indice por maturity es necesario.
