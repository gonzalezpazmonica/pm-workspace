# Regla: Auto-aprendizaje de la heurística de búsqueda

> **Pattern alignment**: implementa el ciclo OODA (Observe-Orient-Decide-Act) sobre los índices T1. Cada miss es una señal de drift entre realidad y mapa.

## Principio

**Cada búsqueda manual (T4 grep dirigido o T5 código fuente) que produce un resultado útil es una oportunidad de aprendizaje.** El agente NUNCA debe responder con datos obtenidos por T4/T5 sin proponer actualizar el índice T1 correspondiente. Si no se actualiza, la próxima sesión repetirá el coste.

## Trigger

El agente baja a T4 o T5 → encuentra dato útil → registra con `scripts/search-miss-log.sh` → **DEBE proponer al humano** la actualización del índice antes de cerrar el turno.

## Tabla de promoción T4/T5 → T1

| Categoría buscada | Si T4/T5 reveló… | Promoción T1 obligatoria |
|---|---|---|
| PERSONA | Ficha de equipo interno faltante | Crear `projects/{slug}-pm/members/{handle}.md` desde plantilla |
| PERSONA | Stakeholder cliente faltante | Añadir bloque `### [Org] Nombre` en `projects/{slug}/business-rules/STAKEHOLDERS.md` |
| CONCEPTO | Término no definido | Añadir línea a `projects/{slug}/GLOSSARY.md` (formato canónico + variantes prohibidas) |
| REGLA | Regla negocio no mapeada | Añadir a `projects/{slug}/business-rules/STAKEHOLDERS.md` (con ownership) |
| CÓDIGO | Componente no en mapa | Refrescar `.agent-maps/{repo}.acm` (si commit nuevo) o INDEX.acm (si repo nuevo) |
| EVENTO | Decisión no consolidada | Añadir entrada a `agent-memory/{tipo}/MEMORY.md` |
| FICHERO externo | Path no indexado | Añadir a `.agent-maps/files/INDEX.afm` |
| RELACIÓN | Wikilink huérfano | Añadir backlink en INDEX padre o ficha relevante (script `auto_link.py`) |

## Flujo obligatorio post-T4/T5

```
1. Responder al usuario con [Tier: T4|T5] visible
2. Ejecutar: scripts/search-miss-log.sh <tier> <cat> "<query>" "<motivo>"
3. PROPONER al humano la promoción T1 con diff concreto:
   - Path del fichero a editar
   - Bloque exacto a añadir
   - Beneficio cuantificado (ej: "próxima consulta similar: 2s → 100ms")
4. Si aprueba → aplicar edición
5. Si rechaza → registrar el rechazo en search-misses.jsonl con campo `promoted=false`
```

## Excepción legítima

No promover si:
- El dato es **efímero** (ej: estado de un sprint en curso, log de hoy)
- El dato pertenece a un **vault de mayor confidencialidad** que el índice (ej: dato N4b-PM no puede ir a un índice N4-SHARED)
- El humano explícitamente lo marca como "one-shot, no indexar"

En estos casos, registrar con `promoted=skipped` y motivo.

## Métrica de salud

- **Índice de hit T1**: `search-misses.jsonl` debe decrecer mes a mes
- **Tiempo medio de respuesta PERSONA/CONCEPTO**: tendencia descendente
- **Drift de mapas**: `.acm`/`.hcm` con `last-walk` > 30 días → flag al inicio de sesión

## Anti-patrón

NUNCA:
- Responder T4/T5 sin proponer promoción
- Promover sin verificar confidencialidad de origen vs destino
- Crear ficha `members/` para stakeholder cliente (es `STAKEHOLDERS.md`)
- Crear entry en `STAKEHOLDERS.md` para empleado interno (es `members/`)

## Auto-revisión de la heurística

Si en una semana se acumulan 3+ misses de la misma categoría con el mismo patrón → la heurística tier-based tiene un bug, no los índices. Revisar `~/.savia/search-heuristic.md` y `projects/{slug}/CLAUDE.md` sección "Heurística".
