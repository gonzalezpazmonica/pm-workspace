# Architectural Vocabulary — Module / Interface / Seam / Adapter / Depth / Locality

> **Pattern alignment**: extiende `attention-anchor.md` (SE-080 Genesis B8 ATTENTION ANCHOR). Vocabulario obligatorio para `architect` y `architecture-judge` agents, y para outputs arquitectónicos (specs, code reviews, refactor plans).
>
> **Source**: re-implementación del patrón `mattpocock/skills/improve-codebase-architecture/LANGUAGE.md` (MIT, 26.4k⭐) — clean-room, prosa propia. SE-082.

## Por qué

`architect` y `architecture-judge` emiten suggestions con vocabulario inconsistente: "componente", "service", "API", "boundary", "boundary context" se mezclan según el caller. Resultado: dos sesiones de revisión arquitectónica producen lenguaje distinto para el mismo concepto.

Este documento define **6 términos canónicos** con `_Avoid_:` explícito (rejection set) que previene drift. Cada output arquitectónico debe usar este vocabulario; otros términos quedan prohibidos en el ámbito enforced (architect / architecture-judge / specs nuevos).

## Términos

### Module
**Definición**: cualquier cosa con una interface y una implementation. Deliberadamente agnóstico de escala — aplica igual a una función, una clase, un paquete, o un slice tier-spanning.

_Avoid_: unit, component, service.

### Interface
**Definición**: todo lo que un caller necesita saber para usar el module correctamente. Incluye type signature, pero también invariantes, restricciones de orden, modos de error, configuración requerida y características de rendimiento.

_Avoid_: API, signature (demasiado estrechos — sólo refieren la superficie tipada).

### Implementation
**Definición**: el código dentro de un module. Distinto de **Adapter**: una cosa puede ser un adapter pequeño con implementation grande (un repo Postgres) o un adapter grande con implementation pequeña (un fake en memoria). Usa "adapter" cuando el seam es el tema; "implementation" en otro caso.

### Seam *(de Michael Feathers)*
**Definición**: lugar donde se puede alterar el comportamiento sin editar in-place. La *ubicación* en la que vive la interface de un module. Decidir dónde poner el seam es una decisión de diseño distinta de qué va detrás.

_Avoid_: boundary (overload con DDD bounded context).

### Adapter
**Definición**: cosa concreta que satisface una interface en un seam. Describe *rol* (qué slot ocupa), no sustancia (qué tiene dentro).

### Depth
**Definición**: leverage en la interface — cantidad de behavior que un caller (o test) puede ejercer por unidad de interface que tiene que aprender. Un module es **deep** cuando una gran cantidad de behavior se sienta detrás de una interface pequeña. Un module es **shallow** cuando la interface es casi tan compleja como la implementation.

### Leverage
**Definición**: lo que callers ganan de Depth. Más capacidad por unidad de interface que tienen que aprender. Una implementation paga rendimiento a través de N call sites y M tests.

### Locality
**Definición**: lo que maintainers ganan de Depth. Cambio, bugs, conocimiento y verificación se concentran en un sitio en lugar de extenderse a través de callers. Fix once, fixed everywhere.

## Principios ratchet

### Deletion test
Imagina borrar el module. Si la complejidad desaparece, el module no estaba ocultando nada (era un pass-through). Si la complejidad reaparece a través de N callers, el module se estaba ganando el sueldo.

### Interface = test surface
Callers y tests cruzan el mismo seam. Si quieres testear *más allá* de la interface, el module está probablemente con la forma incorrecta.

### One adapter = hypothetical seam. Two adapters = real seam.
No introduzcas un seam salvo que algo varíe a través de él. Un seam con un único adapter es indirección sin beneficio.

### Depth es propiedad de la interface, no de la implementation
Un module deep puede componerse internamente de partes pequeñas, mockables, swappables — simplemente no son parte de la interface. Un module puede tener **internal seams** (privados a su implementation, usados por sus propios tests) además del **external seam** en su interface.

## Ratio rejected

- **Depth como proporción líneas de implementation / líneas de interface** (Ousterhout original): premia padding de implementation. Aquí usamos depth-as-leverage.
- **"Interface" como la palabra clave `interface` de TypeScript o métodos públicos de una clase**: demasiado estrecho — interface aquí incluye cada hecho que un caller debe saber.
- **"Boundary"**: overload con DDD bounded context. Usa **seam** o **interface**.

## Aplicación enforced

### Hoy (warning-only)
- `scripts/architectural-vocabulary-audit.sh` escanea outputs recientes de `architect` y `architecture-judge` (en `output/architect-*.md`, `output/architecture-*.md` si existen) y reporta usos prohibidos: "boundary", "component", "service", "API" en contextos arquitectónicos.

### Futuro (gate enforced)
- Cuando SE-084 Slice 2 active el G14 gate, los outputs de `architect` y `architecture-judge` modificados en un PR pasarán por este auditor en modo `--gate`. Outputs anteriores no se reescriben — el ratchet se aplica only-going-forward.

## Cross-references

- `docs/rules/domain/attention-anchor.md` (SE-080) — Genesis B8/B9/A7/A9 patterns. Este vocabulario implementa B8 ATTENTION ANCHOR para architect/judge agents.
- `.opencode/agents/architect.md` — usa este vocabulario en system prompt
- `.opencode/agents/architecture-judge.md` — usa este vocabulario en suggestions

## Referencias

- `mattpocock/skills/improve-codebase-architecture/LANGUAGE.md` — vocabulario fuente (MIT, 2026-04 push)
- John Ousterhout, *A Philosophy of Software Design* — Deep modules concept (rechazamos su definición ratio, adoptamos depth-as-leverage)
- Michael Feathers, *Working Effectively with Legacy Code* — Seam original
- Eric Evans, *Domain-Driven Design* — bounded context (usar como contexto, NO como sinónimo de seam)
