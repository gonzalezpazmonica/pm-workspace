---
name: audit-trail-schema
description: "JSONL audit trail format, storage policy, rotation, query patterns for compliance"
auto_load: false
paths: [".opencode/commands/governance-enterprise*", ".opencode/skills/governance-enterprise/*"]
---

# Regla: Esquema Audit Trail

> Basado en: NIST SP 800-53 (AU-2 Audit Events), EU AI Act (Annex II)
> Complementa: @docs/rules/domain/governance-enterprise.md

**Principio fundamental**: Toda acción tomada por un agente o usuario debe quedar registrada de forma inmutable para auditoría.

## Formato JSONL

Cada línea es un JSON con estos campos obligatorios:

```json
{
  "timestamp": "2026-03-05T14:30:00Z",
  "user": "@monica-gonzalez",
  "action": "create|update|delete|execute|approve|deny",
  "target": "pbi#12345|team:backend|rule:security-check",
  "result": "success|failure|pending",
  "metadata": {
    "command": "sprint-plan",
    "duration_ms": 2450,
    "tokens_used": 1250,
    "model": "sonnet",
    "error": null
  }
}
```

### Campos obligatorios

| Campo | Tipo | Ejemplo | Notas |
|---|---|---|---|
| timestamp | ISO 8601 | 2026-03-05T14:30:00Z | UTC, precision segundos |
| user | String | @monica-gonzalez | Handle o system identifier |
| action | Enum | create, update, delete, execute, approve | Tipo de acción |
| target | String | pbi#12345, team:backend | Resource identifier |
| result | Enum | success, failure, pending | Outcome |
| metadata | Object | {command, duration_ms, error} | Contexto adicional |

## Almacenamiento

**Ubicación**: `.audit-trail/actions.jsonl`

- Formato append-only (nunca se modifica, solo se agrega)
- Tamaño máximo activo: 100 MB (~50k registros)
- Rotación mensual automática a `.audit-trail/archive/YYYY-MM.jsonl`
- Retención: 12 meses activos + 36 meses archivados = 4 años total

## Rotación y retención

**Rotación**: Proceso automático mensual (1er día del mes a 00:00 UTC):

1. Cerrar `.audit-trail/actions.jsonl` (última línea: timestamp de cierre)
2. Mover a `.audit-trail/archive/{YYYY-MM}.jsonl`
3. Comprimir con gzip: `{YYYY-MM}.jsonl.gz` (reducción ~90%)
4. Crear nuevo `.audit-trail/actions.jsonl` vacío
5. Registrar evento de rotación

**Comando**: `/governance-enterprise audit-trail --rotate` ejecutado automáticamente.

## Query patterns (leer audit trail)

### Por usuario
```bash
grep '"user": "@monica' .audit-trail/actions.jsonl | jq '.result'
```
Listar todas las acciones de un usuario con su resultado.

### Por rango de fechas
```bash
jq --arg start "2026-03-01" --arg end "2026-03-31" \
  'select(.timestamp >= $start and .timestamp <= $end)' \
  .audit-trail/actions.jsonl
```

### Por tipo de acción
```bash
grep '"action": "delete"' .audit-trail/actions.jsonl
```

### Por target (recurso)
```bash
grep '"target": "pbi' .audit-trail/actions.jsonl
```

### Por resultado fallido
```bash
grep '"result": "failure"' .audit-trail/actions.jsonl
```

## Casos de uso

| Caso | Query | Tiempo |
|---|---|---|
| "¿Quién modificó este PBI en la última semana?" | user + target + rango fechas | < 1s |
| "¿Cuántos deletes ejecutó tal usuario?" | user + action:delete | < 1s |
| "¿Qué falló en el último commit?" | rango fechas + action:execute + result:failure | < 5s |
| "GDPR Data Subject Right request" | user + rango 1 año | < 10s |

## Seguridad

- NUNCA exponer audit trail públicamente
- NUNCA permitir borrado (append-only)
- NUNCA logear contraseñas o tokens en metadata
- SIEMPRE usar user handles, no nombres reales
- `.audit-trail/` debe estar en `.gitignore` (es local, no se versionea)
- Respeto GDPR Art. 17: después de 4 años, anonimizar user field
