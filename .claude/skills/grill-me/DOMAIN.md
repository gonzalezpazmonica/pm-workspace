# Grill me — Dominio

## Por qué existe esta skill

Mónica propone planes y decisiones constantemente. Su reflejo (y el de Savia) es validar el plan tal cual viene — confirmar el feliz path, no escarbar en las ramas no resueltas. Resultado: planes con huecos que se descubren a mitad de la implementación. Grill-me invierte el reflejo: una vez la usuaria invoca el modo, Savia interroga relentlessly hasta cerrar cada rama del decision tree.

## Conceptos de dominio

- **Decision tree**: árbol de decisiones implícitas dentro de un plan. Cada nodo es una bifurcación (¿usar A o B? ¿cuándo X? ¿qué pasa si Y?). Las hojas son acciones concretas.
- **Rama no resuelta**: bifurcación donde el plan no explicita por qué se elige una rama frente a las otras.
- **Recomendación con razonamiento**: Savia ofrece su propuesta de respuesta + por qué — Mónica acepta, rechaza, o redirige.
- **Hedging anti-pattern**: preguntas como "¿estás segura?" que NO revelan rama nueva — las skill lo rechaza.

## Reglas de negocio que implementa

- Una pregunta a la vez (NO batch). Cada pregunta espera respuesta antes de la siguiente.
- Si la pregunta tiene respuesta en el código/repo/memoria, la skill explora en lugar de preguntar — preserva tiempo de Mónica.
- Cada pregunta debe revelar una rama no resuelta del decision tree, no buscar confirmación de lo ya decidido.
- Implementa Rule #24 radical-honesty (challenge assumptions / expose blind spots) en formato interactivo.

## Relación con otras skills

- **Upstream**: ninguna — trigger humano puro.
- **Adyacente**: `business-analyst` agent descompone PBIs en specs; grill-me interroga al humano sobre planes/decisiones — ámbitos distintos.
- **Adyacente**: `spec-driven-development` skill produce specs APPROVED; grill-me se invoca antes de cerrar un spec como última pasada.
- **Pattern alignment**: Genesis B9 GOAL STEWARD (defender el alcance del request) — ver `docs/rules/domain/attention-anchor.md` (SE-080).

## Decisiones clave

- NO sustituye `business-analyst`: este descompone tareas; grill-me interroga al humano. Roles diferenciados.
- NO genera issues automáticamente: grill-me ayuda a refinar; los outputs (action items) los formaliza Mónica luego con `pbi-decompose` o `flow-spec-create`.
- Atribución MIT a `mattpocock/skills/grill-me` en SKILL.md, prosa propia.

## Limitaciones conocidas

- Bajo Auto Mode, no hay humano para responder cada pregunta — el modo no aplica (Savia delegaría al business-analyst).
- En sesiones cortas, el coste de N preguntas secuenciales puede no compensar — Mónica decide cuándo invocar.
- No detecta ramas que el agente no anticipa (limitación universal de la introspección LLM); funciona mejor en planes con vocabulario familiar al modelo.
