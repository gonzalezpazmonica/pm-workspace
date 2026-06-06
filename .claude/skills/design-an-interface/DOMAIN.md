# DOMAIN — design-an-interface

## Por que existe esta skill

Disenar una interfaz sin explorar alternativas lleva a compromisos prematuros.
Esta skill fuerza la comparacion de 3 filosofias de diseno en paralelo antes
de comprometerse, reduciendo el coste de cambio posterior.

## Conceptos de dominio

- **Interface** (vocab arquitectonico): todo lo que un caller necesita saber para usar el module correctamente.
  Incluye type signature, invariantes, restricciones de orden, modos de error y caracteristicas de rendimiento.
- **Module**: cualquier cosa con una interface y una implementation — agnóstico de escala.
- **Seam**: lugar donde se puede alterar el comportamiento sin editar in-place.
- **Depth**: leverage en la interface — behavior que un caller puede ejercer por unidad de interface que aprende.
- **Locality**: cambio, bugs y conocimiento concentrados en un sitio, no extendidos a callers.
- **Filosofia A (simplicidad)**: minimo de metodos, sin estado, maxima facilidad de uso.
- **Filosofia B (flexibilidad)**: extensible, plugin-friendly, alta testabilidad.
- **Filosofia C (pragmatica)**: equilibrio entre A y B, coherente con el codigo existente del proyecto.

## Limites y no-objetivos

- No implementa la interfaz — solo la disena.
- No evalua performance en runtime — solo diseno estatico.
- No reemplaza la revision arquitectonica humana antes del merge.

## Confidencialidad

- Nivel: N1 (publico, versionado en el repositorio) salvo que el contexto incluya datos de negocio sensibles.
- Si el modulo maneja PII o logica de negocio confidencial: output a `projects/<nombre>/docs/` (N4).

## Referencias

- Spec origen: SE-087.
- Vocabulario arquitectonico: `docs/rules/domain/architectural-vocabulary.md`.
- Agent relacionado: `.opencode/agents/architect.md`.
