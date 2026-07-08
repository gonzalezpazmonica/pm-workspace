# Memory Architecture — SE-257 Slice 2

> Modelo canonico de memoria de Savia. Decision explicita por paradigma.
> Fecha: 2026-07-07. Version: v1.

## Paradigmas y su clasificacion

| Paradigma | Clasificacion | Script/Archivo | Consumidor | Decision |
|---|---|---|---|---|
| Memoria externa (auto) | canonico | memory-store.sh | AGENTS.md, session-init | Cableado |
| Memoria externa (manual) | canonico | memory-recall.sh | agent prompts | Cableado |
| Bitemporal | canonico | memory-bitemporal.py | ledger SE-255 S3 | Cableado al ledger |
| Higiene de memoria | canonico | memory-hygiene.sh | cron SE-220 | Cableado |
| Canary check | canonico | memory-canary-check.sh | CI | Cableado |
| Conflict check | canonico | memory-conflict-check.sh | CI | Cableado |
| Status check | canonico | memory-status-check.sh | hooks | Cableado |
| Conflict detection (relacion) | canonico | relacion-detect-conflicts.sh | SE-256 S2 | Cableado |
| Capture (relacion) | canonico | relacion-capture.sh | SE-255 S3 | Cableado |
| Report (relacion) | canonico | relacion-report.sh | SE-255 S3 | Cableado |
| Liveness check | canonico | memory-liveness-check.sh | CI SE-257 | Cableado |
| obsidian-export (ext) | satelite | external/engram | TUI | Externo, no mantener |

## Decisiones

1. **memory-bitemporal.py cableado al ledger**: cada entrada del ledger
   recibe intervalo de validez (valid_from, valid_until) via bitemporal.
   SE-255 S3 ya declaraba esta dependencia.

2. **Cero huerfanos**: 12 scripts identificados en auditoria; todos
   cableados a consumidores o archivados con tombstone.

3. **Requirements podados**: requirements-vector.txt y
   scripts/requirements-memory.txt contienen solo imports vivos.

4. **Guard permanente**: memory-liveness-check.sh en CI (SE-257 S4).
