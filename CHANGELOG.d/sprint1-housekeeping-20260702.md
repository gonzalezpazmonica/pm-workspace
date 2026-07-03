## Sprint 1 Housekeeping — 2026-07-02

### Spec status drift correction (21 flips → IMPLEMENTED)

Post-merge PRs #876-893: 21 specs con status PROPOSED/APPROVED desincronizadas
del código ya en producción. Flip masivo a IMPLEMENTED:

- SE-228 S1-S5 (PRs #876-880): Loop Engineering patterns
- SE-233 (PR #887): Professional Domain Skills
- SE-235-238 (PR #889): Proto-inspired arch improvements
- SE-239-247 (PR #890): Security Hardening Suite (9 specs)
- SE-248 (PR #891): KG Topology Analysis
- SE-252 (PR #893): Bus Factor Shield
- SE-223, SE-249, SE-251: verificado código existente, flipado

SE-250 conservado PROPOSED (rotation logic no completamente implementada).

### fix(rules-index): --check gate ignora línea de fecha del header

`scripts/rules-index-generate.sh --check` fallaba en CI cualquier día
posterior al de la última generación porque el header incluye fecha.
La comparación ahora excluye la línea 1 (header de fecha). Test SE-097
pasa en cualquier fecha sin necesidad de regenerar diariamente.

Resolves: fallo CI recurrente detectado en PR #893.

### docs(ROADMAP): Active Stack actualizado a 2026-07-02

- Añadida sección `Active Stack — 2026-07-02` con resumen de merges recientes
- Distribución de status actualizada: ~243 IMPLEMENTED (77%)
- Sprints 2 y 3 planificados: SPEC-182/183 (anti-drift) + SPEC-108/164/167 (loops)
