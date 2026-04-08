# Session Memory Protocol [SPEC-013 + SPEC-016 + SPEC-041]

> Savia extrae y persiste conocimiento valioso ANTES de perderlo.
> Dos triggers: pre-compact (SPEC-016) y fin de sesion (SPEC-013).

## Trigger 1: Pre-compact (automatico)

Pipeline pre-compact: Clasificar → Comprimir Tier B → Persistir → Compact estándar → Reinyectar.

### Clasificacion por Tiers (SPEC-041 P1)

Antes de compactar, clasificar CADA turno de conversacion en:

**TIER A — Verbatim (preservar 100%)**
- Ultimo turno activo + 2 turnos previos
- Decisiones explicitas del usuario ("vamos con X", "usaremos Y")
- Estado de tarea en curso (slice actual, ficheros abiertos)
- Correcciones activas ("no, asi no", "cambia X por Y")
- Preferencias neurodivergentes activas (SPEC-061: active_modes, sensory_budget)

**TIER B — Resumen estructurado (comprimir, ~95-99% semantica)**
- Conversacion ultimos 60 min con nombres, decisiones, referencias
- Output de agentes con decisiones o errores relevantes
- Contexto tecnico establecido (stack, convenciones confirmadas)
→ Guardar en session-hot.md (auto-memory project, TTL 24h)

**TIER C — Descarte controlado**
- Confirmaciones simples (si, ok, vale, hecho)
- Banners UX y mensajes de progreso
- Output de herramientas sin decisiones (ls, git status, git log)

### Pipeline completo

1. Clasificar turnos en A/B/C
2. **Verificar integridad de pares tool [SPEC-088]**: si un tool_use esta en Tier C pero su tool_result en Tier A (o viceversa), promover AMBOS al Tier del miembro preservado
3. Tier B → extraer bullets → guardar en `~/.claude/projects/.../memory/session-hot.md`
4. Ejecutar /compact estandar (context-health.md seccion 3b)
5. Post-compact: reinyectar Tier A + resumen de session-hot.md como contexto inicial

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
