# Zoom out — Dominio

## Por qué existe esta skill

Cuando Mónica entra en un área del repo que no ha tocado antes, el reflejo del agente es zoom-in inmediato (leer un archivo concreto, hacer grep para una función). Eso produce respuestas precisas pero descontextualizadas — Mónica acaba sabiendo qué hace una línea sin saber dónde encaja en el sistema. Zoom-out invierte el reflejo: pide mapa antes que detalle.

## Conceptos de dominio

- **Capa de abstracción**: nivel al que se describe el sistema (línea de código → función → módulo → subsistema → arquitectura). Zoom-out sube una capa desde donde está la atención actual.
- **Mapa de módulos**: enumeración de las unidades funcionales en un área + sus interfaces (qué exportan, qué consumen) + quién las llama desde fuera.
- **Detalle de implementación**: lo que zoom-out NO devuelve. Si Mónica quiere bajar al detalle, sale del modo manualmente.

## Reglas de negocio que implementa

- Trigger humano puro: `disable-model-invocation: true` previene que el agente lo auto-invoque por intuición ruidosa.
- Output máximo: ~30 líneas (mapa breve, no inventario exhaustivo). Si el área tiene 50+ módulos, prioriza los hot-paths (los más llamados).
- NO descender a implementación: si la respuesta requiere leer el body de una función, eso es zoom-in y se gestiona aparte.

## Relación con otras skills

- **Adyacente**: `architect` agent (heavyweight, propone diseños). Zoom-out es ligero (1 turn de mapa).
- **Adyacente**: `codebase-map` skill (genera grafo persistente de dependencias). Zoom-out es zero-state — sólo lee in-place.
- **Upstream**: ninguna — trigger humano puro.

## Decisiones clave

- Trigger explícito vía `disable-model-invocation`: la intuición del agente sobre "creo que necesitas un mapa" es ruidosa y consumiría tokens innecesariamente.
- No persistir output: cada invocación regenera el mapa. La memoria del workspace tiene `codebase-map` para output estable.
- Atribución MIT a `mattpocock/skills/zoom-out` en SKILL.md, prosa propia.

## Limitaciones conocidas

- No funciona bien para repos sin estructura clara (monolitos sin módulos visibles) — output queda vago.
- No detecta dependencias dinámicas (carga lazy, plugins) — sólo las visibles estáticamente en imports.
