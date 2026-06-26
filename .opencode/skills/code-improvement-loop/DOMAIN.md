# Code Improvement Loop — Dominio

## Por qué existe esta skill

La deuda técnica se acumula (baja cobertura, alta complejidad, warnings de linter, TODOs pendientes) y rara vez se prioriza en sprints. Esta skill aplica mejoras incrementales y medibles de forma autónoma, generando PRs atómicos con métricas antes/después para que un humano decida si aceptar cada mejora.

## Conceptos de dominio

- **Mejora incremental**: Cambio atómico que mejora una métrica sin degradar otras
- **Métricas baseline**: Snapshot de calidad antes de iniciar (cobertura, complejidad, warnings, TODOs, deps)
- **Patrón keep/discard**: Si la métrica objetivo mejora y ninguna otra degrada, mantener; si no, descartar — inspirado en autoresearch
- **improvement-results.tsv**: Registro con métricas antes/después por cada intento

## Reglas de negocio que implementa

- RN-AUT-01: Ningún agente autónomo tiene autoridad para decisiones irreversibles
- RN-AUT-02: Todo output autónomo es propuesta pendiente de revisión humana
- RN-QA-01: Tests existentes NUNCA se modifican, solo se añaden nuevos

## Relación con otras skills

- **Upstream**: `debt-track` identifica deuda técnica que alimenta las oportunidades
- **Downstream**: PRs en Draft listos para revisión humana
- **Paralela**: `overnight-sprint` (puede invocar code-improvement como subtarea)

## Decisiones clave

- Se eligió un PR por mejora (atómico) en vez de batch, para facilitar revisión individual
- Se prohíbe modificar tests existentes para evitar que el agente "arregle" métricas eliminando tests
- El patrón modificar → medir → mantener/descartar viene de autoresearch
