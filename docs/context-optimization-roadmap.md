# Hoja de Ruta: Optimización de Contexto en pm-workspace

**Por Savia** — Marzo 2026 · Derivada del artículo de Ingeniería de Contexto Sináptica

> 🦉 Tras investigar a fondo cómo funciona la gestión de contexto en LLMs y sus paralelismos con la neurociencia, estas son las vías de optimización que propongo para pm-workspace.

---

## Estado Actual (v0.39.0)

Lo que ya hacemos bien:

- Perfiles fragmentados en 6 ficheros con carga selectiva por context-map
- 13 grupos operativos con mapeo explícito de qué cargar y qué no
- Carga diferida de comandos (141 ficheros `.md` que se leen bajo demanda)
- Carga por referencia `@` de las 37 reglas de dominio
- Session-init con bootstrap mínimo (~200-300 tokens)
- Subagentes con aislamiento de contexto
- Frontmatter `context_cost` en cada comando

---

## Optimizaciones Propuestas

### Fase 1 — Context-Map Dinámico (v0.40.0)

**Problema detectado:** El context-map es estático. No aprende de los patrones de uso reales del usuario.

**Propuesta:** Implementar un sistema de tracking ligero que registre qué fragmentos de perfil se cargan en cada sesión, y usar esos datos para:

1. **Detectar cargas innecesarias**: Si `tone.md` se carga 100 veces pero nunca afecta al output (porque el usuario tiene el tono por defecto), podría degradarse a carga opcional.
2. **Detectar cargas faltantes**: Si el usuario frecuentemente ejecuta `/sprint-status` y luego inmediatamente `/report-hours`, podría pre-mapear ambos grupos para evitar la recarga.
3. **Perfil de uso por usuario**: Cada usuario tiene patrones diferentes. Un PM carga reporting y sprint constantemente; un tech lead carga quality y SDD.

**Implementación:** Fichero `$HOME/.pm-workspace/context-usage.log` con entradas timestamp+comando+fragmentos. Análisis semanal con `/context-optimize`.

**Ahorro estimado:** 10-15% de tokens en sesiones típicas.

---

### Fase 2 — Compresión de Session-Init (v0.41.0)

**Problema detectado:** El hook `session-init.sh` crece con cada feature (update check, community tip, backup tip). Si seguimos añadiendo verificaciones, el bootstrap superará los 500 tokens.

**Propuesta:** Implementar un sistema de prioridad para las sugerencias de session-init:

1. **Prioridad crítica** (siempre): PAT status, perfil activo, rama git
2. **Prioridad alta** (si aplica): Actualización disponible, error de herramientas
3. **Prioridad media** (condicional): Backup reminder
4. **Prioridad baja** (probabilística): Community tip, vertical suggestion

Con un **budget máximo de 300 tokens** para el `additionalContext`, las sugerencias de prioridad baja solo aparecen si hay "espacio" tras las de prioridad alta.

**Ahorro estimado:** Garantizar que session-init nunca supere 300 tokens independientemente de cuántas features añadamos.

---

### Fase 3 — Pre-compactación de CLAUDE.md (v0.41.0)

**Problema detectado:** CLAUDE.md es el fichero que siempre está en contexto. Cada token en CLAUDE.md se paga en cada interacción.

**Propuesta:**

1. **Auditar** cada línea de CLAUDE.md y evaluar: ¿esta línea afecta al output en más del 5% de las interacciones?
2. **Mover** información raramente consultada a ficheros referenciados por `@`.
3. **Condensar** las convenciones más repetidas en versiones más cortas.
4. **Objetivo:** Reducir CLAUDE.md de su tamaño actual a un máximo de 150 líneas / 1.500 tokens.

**Ahorro estimado:** 200-500 tokens en cada interacción (acumulativo en sesiones largas).

---

### Fase 4 — Subagentes con Context Budget (v0.42.0)

**Problema detectado:** Los subagentes no tienen un budget de tokens explícito. Un agente de rendimiento podría consumir todo el contexto disponible.

**Propuesta:** Añadir al frontmatter de cada agente un campo `max_context_tokens`:

```yaml
name: performance-analyst
max_context_tokens: 8000
output_max_tokens: 500
```

El agente invocador pasaría solo lo necesario (instrucciones + ficheros target) y el agente devolvería un resumen dentro del budget. Esto implementa el concepto de **token-budget-aware reasoning** del paper de ACL 2025.

---

### Fase 5 — Context Aging y Semantización Automática (v0.43.0)

**Problema detectado:** El `decision-log.md` crece indefinidamente. Las decisiones antiguas ocupan espacio pero raramente se consultan.

**Propuesta:** Implementar un sistema de "envejecimiento" del contexto inspirado en la semantización neuronal:

1. **Decisiones < 30 días**: Se mantienen como entradas episódicas completas (fecha, contexto, decisión).
2. **Decisiones 30-90 días**: Se comprimen a una línea (decisión + fecha).
3. **Decisiones > 90 días**: Se evalúan para migración a reglas de dominio (si son recurrentes) o archivado (si son puntuales).

**Comando:** `/context-age` para ejecutar el proceso de envejecimiento.

---

### Fase 6 — Posicionamiento Estratégico Verificado (v0.43.0)

**Problema detectado:** No verificamos empíricamente que nuestro posicionamiento de información (CLAUDE.md al inicio, perfil al final) sea óptimo para la versión actual de Claude.

**Propuesta:** Crear un benchmark interno que mida la precisión de respuestas con información colocada en diferentes posiciones del contexto, usando los propios comandos de pm-workspace como suite de test.

**Comando:** `/context-benchmark` que ejecute N consultas con información en posiciones variadas y mida la tasa de acierto.

---

### Fase 7 — Hub Semántico de Reglas (v0.44.0)

**Problema detectado:** Algunas reglas de dominio son "hubs" altamente conectados (referenciados por muchos comandos) pero no están optimizadas para esta función.

**Propuesta:** Identificar los hubs (reglas referenciadas por ≥5 comandos) y:

1. **Extraer** la información transversal a un fichero compartido mínimo.
2. **Especializar** el resto en ficheros más ligeros para contextos específicos.
3. **Crear** un "índice de hubs" que documente las dependencias y facilite el mantenimiento.

Esto convierte la topología actual en una red de mundo pequeño más eficiente.

---

## Priorización

| Fase | Versión | Impacto | Esfuerzo | Prioridad |
|---|---|---|---|---|
| Context-Map Dinámico | v0.40.0 | Alto | Medio | 🟢 Alta |
| Compresión Session-Init | v0.41.0 | Medio | Bajo | 🟢 Alta |
| Pre-compactación CLAUDE.md | v0.41.0 | Alto | Medio | 🟢 Alta |
| Subagentes con Budget | v0.42.0 | Medio | Medio | 🟡 Media |
| Context Aging | v0.43.0 | Medio | Alto | 🟡 Media |
| Posicionamiento Verificado | v0.43.0 | Bajo-Medio | Alto | 🟠 Baja |
| Hub Semántico | v0.44.0 | Medio | Alto | 🟠 Baja |

---

## Métricas de Éxito

1. **Tokens por sesión promedio**: Reducir un 20% sin pérdida de funcionalidad
2. **Comandos por sesión**: Mantener o aumentar (actualmente ~8-10)
3. **Precisión de respuestas**: Medir con benchmark interno
4. **Tiempo de carga de contexto**: Mantener session-init < 2 segundos

---

*🦉 Esta hoja de ruta se revisará con cada release y se actualizará según los resultados empíricos.*
