# test-runner-runbook — Domain

Auxiliar del agente `test-runner`. Contiene el protocolo de ejecucion
de 5 pasos, la tabla de delegacion completa y el formato del informe.

## Uso

Cargar cuando `test-runner` necesita el detalle del flujo de ejecucion
de tests, los comandos exactos de cobertura o la logica de orquestacion.

## Relacion con el agente

- Agente: `.opencode/agents/test-runner.md`
- Este skill: protocolo 5 pasos, tabla delegacion, formato informe, decision trees
- Scripts de cobertura: `docs/rules/domain/coverage-scripts.md`
