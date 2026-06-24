# commit-guardian-runbook — Domain

Auxiliar del agente `commit-guardian`. Contiene los 10 checks con
sus criterios exactos, la tabla de delegacion completa y el formato
del informe pre-commit.

## Uso

Cargar cuando `commit-guardian` necesita el detalle de algun check
especifico (BUILD, TESTS, FORMATO, README, atomicidad, etc.) o
la logica completa de delegacion.

## Relacion con el agente

- Agente: `.opencode/agents/commit-guardian.md`
- Este skill: detalle de 10 checks, tabla delegacion, formato informe
- Referencia de checks: `docs/rules/domain/commit-checks-reference.md`
