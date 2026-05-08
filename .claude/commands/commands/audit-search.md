---
name: audit-search
description: Búsqueda contextual en audit trail — fecha, acción, usuario, proyecto, confianza. NL search y regex.
developer_type: all
agent: task
context_cost: medium
---

# Audit Search — Búsqueda Contextual en Audit Trail

## Propósito

Búsqueda flexible y poderosa en el audit trail usando lenguaje natural, filtros específicos, regex y saved searches. Útil para investigaciones, compliance checks y análisis históricos.

## Sintaxis

```bash
/audit-search {query} [--from date] [--to date] [--user nombre] [--action tipo] [--lang es|en]
```

## Parámetros

| Parámetro | Tipo | Descripción |
|---|---|---|
| `{query}` | string | Consulta: natural language, regex (`/pattern/`), o palabra clave |
| `--from` | date | Fecha inicio (YYYY-MM-DD) |
| `--to` | date | Fecha fin (YYYY-MM-DD) |
| `--user` | string | Filtrar por usuario (p.e. `monica` busca entradas de monica) |
| `--action` | string | Filtrar por tipo: `query`, `modify`, `recommend`, `decision`, `generate` |
| `--lang` | string | `es` (español), `en` (inglés) |

## Ejemplos de Uso

### Natural Language Search

```bash
/audit-search "cambios en el sprint 4"
# Busca entradas que mencionen sprint y cambios

/audit-search "quién creó el PBI de login"
# Busca acciones de creación de PBI con palabra "login"

/audit-search "recomendaciones rechazadas"
# Busca recomendaciones con resultado negativo
```

### Regex Patterns

```bash
/audit-search "/sprint-[0-9]{4}-0[1-4]/"
# Busca cualquier sprint del 01 al 04

/audit-search "/pbi.*create.*success/"
# Busca creaciones exitosas de PBIs

/audit-search "/confidence:0\.[5-9][0-9]/"
# Busca entradas con confianza entre 50% y 99%
```

### Filtros Específicos

```bash
/audit-search "error" --action modify --from 2026-03-01 --to 2026-03-02
# Busca errores en modificaciones entre esas fechas

/audit-search "sala-reservas" --user monica --action decision
# Decisiones tomadas por monica en sala-reservas

/audit-search "deprecated" --user * --action recommend
# Todas las recomendaciones que mencionan "deprecated"
```

## Visualización de Resultados

**Formato estándar (10-20 líneas):**

```
🔍 Búsqueda: "cambios en sprint 4"
   Período: sin filtro | Usuario: todos | Acción: todas
   Resultados: 47 entradas encontradas

─ 2026-02-28 14:30 │ carlos │ /pbi-plan-sprint
   Sprint: 2026-04 | Acción: 3 items priorización
   Confianza: 92% | ✓ Éxito

─ 2026-02-27 09:15 │ monica │ /sprint-replan
   Sprint: 2026-04 | Acción: redistribución capacidad
   Confianza: 88% | ✓ Éxito

[Mostrando 2 de 47 — `/audit-search "cambios en sprint 4" --show-all` para ver todos]
```

**Con `--show-all` (o en JSON):**
```bash
/audit-search "cambios en sprint 4" --format json
# Genera fichero JSON con todas las 47 entradas
```

## Saved Searches

Guardar consultas frecuentes:

```bash
/audit-search --save "cambios sala-reservas" --query "sala-reservas --action modify"
```

Listar y ejecutar saved searches:

```bash
/audit-search --list-saved
/audit-search --run "cambios sala-reservas"
```

## Timeline Visualization

Mostrar distribución temporal:

```bash
/audit-search "recommend" --timeline
```

Output:
```
2026-02 ████████ 45 recomendaciones
2026-03 ██████░░ 23 recomendaciones (parcial)
```

## Integración con Audit Trail

Cada búsqueda se registra en audit trail como:

```json
{
  "timestamp": "2026-03-02T10:45:00Z",
  "action_type": "query",
  "command": "audit-search",
  "query_text": "cambios en sprint 4",
  "results_found": 47
}
```

## Notas

- Búsquedas son **case-insensitive** por defecto
- Regex soporta POSIX Extended Regex (ERE)
- Límite de resultados: 10000 entradas por búsqueda (paginación automática)
- Saved searches se almacenan en `$HOME/.pm-workspace/audit-searches.yml`
