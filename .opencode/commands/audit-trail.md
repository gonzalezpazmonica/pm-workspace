---
name: audit-trail
description: Log inmutable de todas las acciones de Savia — comandos, recomendaciones, decisiones, archivos modificados. Cumplimiento EU AI Act.
developer_type: all
agent: task
context_cost: medium
---

# Audit Trail — Registro Completo e Inmutable

## Propósito

Mantener un registro **append-only e inmutable** de todas las acciones ejecutadas por Savia: comandos ejecutados, recomendaciones generadas, decisiones tomadas, archivos modificados. Cada entrada incluye timestamp, usuario, comando, contexto, resultado y nivel de confianza.

**Cumplimiento**: EU AI Act (artículos 13-15), ISO 42001, NIST AI RMF

## Sintaxis

```bash
/audit-trail [--show] [--period today|week|month] [--filter action|user|project] [--lang es|en]
```

## Parámetros

| Parámetro | Tipo | Descripción |
|---|---|---|
| `--show` | flag | Mostrar últimas entradas (por defecto sin flag también muestra) |
| `--period` | string | Filtro temporal: `today`, `week`, `month` |
| `--filter` | string | Tipo filtro: `action` (qué comando), `user` (quién), `project` (en qué proyecto) |
| `--lang` | string | `es` (español, por defecto), `en` (inglés) |

## Funcionamiento

### 1. Almacenamiento Append-Only

- Ubicación: `$HOME/.pm-workspace/audit-trail.jsonl` (una entrada JSON por línea)
- **NUNCA se pueden borrar** entradas anteriores
- Nuevo contenido se añade al final
- Rotación anual: `audit-trail-YYYY.jsonl` si el fichero supera 100MB

### 2. Estructura de Entrada

```json
{
  "timestamp": "2026-03-02T10:15:30Z",
  "user": "monica-gonzalez",
  "command": "sprint-status",
  "context": "Proyecto: sala-reservas, Sprint: 2026-04",
  "action_type": "query",
  "result": "success",
  "result_summary": "12 items completados, 5 bloqueados",
  "confidence": 0.95,
  "files_affected": [],
  "modifications": 0
}
```

### 3. Tipos de Acción

- `query`: lectura/consulta sin modificación
- `modify`: crear/actualizar/eliminar datos
- `recommend`: sugerencia del agente
- `decision`: decisión registrada (aprobación, rechazo)
- `generate`: generación de contenido (spec, informe)

### 4. Visualización

**Entrada típica en pantalla:**
```
─ 2026-03-02 10:15:30 │ monica │ /sprint-status
   Proyecto: sala-reservas | Sprint: 2026-04
   → 12 items completados, 5 bloqueados
   Confianza: 95% | Éxito ✓
```

### 5. Filtrado

**Por período:**
```
/audit-trail --period today          # Últimas 24h
/audit-trail --period week           # Últimos 7 días
/audit-trail --period month          # Últimos 30 días
```

**Por tipo:**
```
/audit-trail --filter action sprint-status   # Solo /sprint-status
/audit-trail --filter user monica            # Solo acciones de monica
/audit-trail --filter project sala-reservas  # Solo este proyecto
```

### 6. Entradas Especiales

**Recomendaciones del agente:**
```json
{
  "action_type": "recommend",
  "recommendation": "Priorizar PBI#123 por riesgo de dependencia",
  "confidence": 0.87,
  "accepted": true
}
```

**Decisiones registradas:**
```json
{
  "action_type": "decision",
  "decision": "Aplazar feature X a Sprint 5",
  "rationale": "Riesgo técnico, requiere investigación",
  "confidence": 0.92
}
```

## Cumplimiento Normativo

### EU AI Act (Artículos 13-15)

- ✅ Transparencia: todas las acciones registradas
- ✅ Responsabilidad: quién, qué, cuándo
- ✅ Trazabilidad: cada acción linkeable
- ✅ Inmutabilidad: no se pueden alterar registros

### ISO 42001 (AI Management)

- ✅ 4.4.2: Documentación de decisiones IA
- ✅ 5.3: Control de riesgos — trazabilidad

### NIST AI RMF

- ✅ GOVERN (GV-3.1): Documentación de gobernanza
- ✅ MEASURE (ME-3.1): Métricas de desempeño

## Comandos Relacionados

- `/audit-export` — Exportar trail en JSON/CSV/PDF para auditorías externas
- `/audit-search` — Búsqueda contextual con queries naturales y regex
- `/audit-alert` — Configurar alertas automáticas por patrones anómalos

## Notas

- El trail NO puede ser editado por el usuario — **append-only obligatorio**
- Las entradas antiguas (>1 año) se archivan automáticamente
- Los backups incluyen el trail completo (cifrado)
- Consultar trail NO genera nuevas entradas en el trail (recursión evitada)
