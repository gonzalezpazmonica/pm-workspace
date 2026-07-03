---
spec_id: SE-235
title: "Formalización Dual Pool — Proposal State vs Result State"
status: IMPLEMENTED
created: 2026-06-28
resolved_at: "2026-07-02"
implementation_pr: "#889"
author: savia
context_tier: L2
token_budget: 600
inspired_by: "Proto (Arc Institute, 2026) — proposal_sequences vs result_sequences"
---

# SE-235: Formalización Dual Pool — Proposal State vs Result State

## Motivación

Proto (Arc Institute, 2026) distingue explícitamente dos espacios de estado durante la optimización de proteínas:

- **proposal_sequences**: workspace efímero generado en cada paso del sampler. Una propuesta existe, se evalúa y se descarta o acepta. Nunca se trata como resultado permanente mientras no haya pasado por el evaluador.
- **result_sequences**: las mejores secuencias encontradas hasta el momento, persistentes y promovidas solo tras superar los constraints del optimizer.

En Savia este mismo principio existe implícitamente: las ramas `agent/*` son propuestas; `main` es el pool de resultados. El problema es que **no está formalizado**, lo que permite que artefactos en estado proposal sean referenciados como fuente de verdad por otros artefactos antes de haber pasado por el Code Review Court.

## Definiciones

### Estado Proposal

Un artefacto está en **estado proposal** cuando:

1. Reside en una rama con prefijo `agent/*` (cualquier variante: `agent/overnight-*`, `agent/improve-*`, `agent/research-*`, `agent/nido-*`)
2. Está en un nido (`.savia/nidos/*/`) y no ha sido mergeado a main
3. Es el output de un agente autónomo pendiente de revisión humana
4. Tiene un PR en estado Draft no aprobado

**Implicación**: un artefacto en estado proposal es **efímero y mutable**. Puede ser descartado. No tiene garantía de permanencia.

### Estado Result

Un artefacto está en **estado result** cuando:

1. Está en la rama `main` (o `develop` según el flujo del proyecto)
2. Ha pasado por el Code Review Court con veredicto `pass` o `conditional` aceptado
3. Tiene un PR mergeado con aprobación humana explícita (E1)

**Implicación**: un artefacto en estado result es **estable y referenciable**. Puede ser usado como fuente de verdad.

## Regla Central

> **Ningún artefacto en estado proposal puede ser referenciado como fuente de verdad por otro artefacto.**

### Concretamente prohibido

- Un spec en `docs/propuestas/` que importe (`@import`) un fichero en una rama `agent/*`
- Un hook que lea configuración de un path en un nido no mergeado
- Un agente cuya instrucción apunte a un fichero pendiente de revisión

### Permitido

- Leer un artefacto proposal para inspeccionarlo, compararlo o evaluarlo (lectura)
- Referenciar un artefacto proposal con anotación explícita `[PROPOSAL - no usar como fuente de verdad]`
- Citar el spec_id de una propuesta en estado PROPOSED (la referencia es al id, no al contenido mutable)

## Implementación

### Sección en autonomous-safety.md

Ver `docs/rules/domain/autonomous-safety.md` — sección añadida: `## Dual Pool — Proposal vs Result`.

### Plugin TypeScript

`plugins/guards/block-proposal-as-source.ts` — guard que detecta cuando una herramienta `Write` intenta escribir un fichero que importa (`@import`, `source:`, `from:`) un path ubicado en una rama `agent/*` (detectado vía `git branch --show-current` y `git status`).

**Lógica del guard**:
1. Intercepta la herramienta `Write`
2. Escanea el contenido a escribir en busca de patrones `@import`, `source:`, `read:`, `from:` seguidos de paths
3. Para cada path referenciado, ejecuta `git log --oneline -1 -- <path>` para detectar si el path solo existe en una rama `agent/*`
4. Si detecta una referencia a proposal, bloquea con mensaje explicativo

## Tests

Ver `tests/test-se235-dual-pool.bats` — 10 tests de integración.

## Criterio de éxito

- El fichero `autonomous-safety.md` menciona explícitamente "proposal state" y "result state"
- El plugin `block-proposal-as-source.ts` existe y tiene tests asociados
- Los 10 tests del fichero BATS pasan en verde
