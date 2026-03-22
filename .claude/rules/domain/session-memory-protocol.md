# Session Memory Protocol [SPEC-013 + SPEC-016]

> Savia extrae y persiste conocimiento valioso ANTES de perderlo.
> Dos triggers: pre-compact (SPEC-016) y fin de sesion (SPEC-013).

## Trigger 1: Pre-compact (automatico)

Antes de cada /compact, aplicar el protocolo de context-health.md seccion 3b.
Scan → Quality Gate → Persist → Compact summary.

## Trigger 2: Fin de sesion (cuando el usuario se va)

Cuando el usuario indica fin de sesion ("me voy", "hasta luego", /clear,
cierre de terminal, o inactividad prolongada), Savia:

1. **Scan rapido** del contexto actual (ultimos ~20 turnos)
2. **Extraer** correcciones, decisiones y descubrimientos no persistidos
3. **Persistir** en auto-memory con tipo correcto
4. **Confirmar**: "He guardado N decisiones en memoria para la proxima sesion."

## Que extraer (priorizado)

| Prioridad | Tipo | Ejemplo | Destino |
|-----------|------|---------|---------|
| 1 | Correccion | "no uses X, usa Y" | feedback memory |
| 2 | Decision tecnica | "elegimos GraphQL" | project memory |
| 3 | Descubrimiento | "el bug era por Z" | project memory |
| 4 | Patron de trabajo | "siempre hago X antes de Y" | user memory |
| 5 | Referencia externa | "los docs estan en URL" | reference memory |

## Quality gate

Descartar:
- < 50 caracteres
- Confirmaciones simples (ok, si, vale, hecho)
- Ya existe en auto-memory (buscar por topic_key similar)
- Datos efimeros (numeros de linea, rutas temporales, estados de debug)
- PII (nombres reales, emails — aplicar pii-sanitization.md)

## Limites

- Max 5 items por extraccion (priorizar por tabla arriba)
- Max 100 tokens por item (resumir si es mas largo)
- Nunca bloquear la salida del usuario — si hay prisa, saltar
- Si no hay nada valioso, no forzar extraccion

## Integracion con auto-memory

Usar los tipos de memoria de Claude Code:
- `feedback`: correcciones del usuario sobre como trabajar
- `project`: decisiones y descubrimientos del proyecto/workspace
- `user`: patrones y preferencias del usuario
- `reference`: punteros a recursos externos

Cada item guardado debe tener `description` suficiente para decidir
relevancia en futuras sesiones sin leer el contenido completo.
