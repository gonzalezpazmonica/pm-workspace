---
name: audit-export
description: Exportar audit trail en JSON/CSV/PDF para auditorías externas. ISO 42001 & NIST AI RMF compliant.
developer_type: all
agent: task
context_cost: medium
---

# Audit Export — Exportación para Auditorías Externas

## Propósito

Exportar el audit trail en formatos estándar para que auditores externos, reguladores y compliance officers puedan analizar la gobernanza IA de la organización.

**Cumplimiento**: ISO 42001, NIST AI RMF, SOC 2 Type II

## Sintaxis

```bash
/audit-export [--format json|csv|pdf] [--period] [--filter] [--destination path] [--lang es|en]
```

## Parámetros

| Parámetro | Tipo | Descripción |
|---|---|---|
| `--format` | string | `json` (por defecto), `csv`, `pdf` |
| `--period` | string | `today`, `week`, `month`, `year`, o rango `2026-01-01:2026-03-02` |
| `--filter` | string | Mismo que `/audit-trail` |
| `--destination` | path | Ruta de destino (por defecto `output/exports/`) |
| `--lang` | string | `es` (español), `en` (inglés) |

## Formatos Soportados

### 1. JSON (Integración SIEM)

```json
{
  "export_metadata": {
    "generated_at": "2026-03-02T10:30:00Z",
    "generated_by": "audit-export",
    "period": "2026-01-02 — 2026-03-02",
    "total_entries": 1247,
    "hash_verification": "sha256:abc123..."
  },
  "entries": [
    {
      "timestamp": "2026-03-02T10:15:30Z",
      "user": "monica-gonzalez",
      "command": "sprint-status",
      "action_type": "query",
      "result": "success",
      "confidence": 0.95
    }
  ]
}
```

### 2. CSV (Análisis de datos)

```csv
timestamp,user,command,action_type,result,confidence,project
2026-03-02T10:15:30Z,monica-gonzalez,sprint-status,query,success,0.95,sala-reservas
2026-03-02T10:20:15Z,monica-gonzalez,pbi-create,modify,success,0.92,sala-reservas
```

### 3. PDF (Compliance officers)

- Portada con período y resumen ejecutivo
- Gráficos: comandos por tipo, éxito rate, confianza promedio
- Tabla detallada de entradas (últimas 100)
- Certificado de integridad (hash SHA-256)

## Verificación de Integridad

**Cálculo de hash:**
```bash
sha256sum audit-trail.json
```

**Fichero de certificado:** `{nombre_export}.hash`

Ejemplo:
```
sha256:abc123def456... audit-export-2026-03-02.json
```

Los auditores pueden verificar que el fichero no ha sido alterado:
```bash
sha256sum -c audit-export-2026-03-02.hash
```

## Estructura de Nombres

Ficheros generados en `output/exports/`:

```
audit-export-2026-03-02-full.json        # JSON completo
audit-export-2026-03-02-full.hash        # SHA-256 verification
audit-export-2026-03-02-full.csv         # CSV para análisis
audit-export-2026-03-02-full.pdf         # PDF para ejecutivos
```

## Casos de Uso

### ISO 42001 Auditoría Anual
```bash
/audit-export --format pdf --period year --destination /auditorías/iso-42001-2026
```

### NIST AI RMF — Documentación GOVERN
```bash
/audit-export --format json --period month --destination /compliance/nist-govern
```

### Integración SIEM (Elasticsearch, Splunk)
```bash
/audit-export --format json --period today --destination /siem-import
```

## Seguridad

- Ficheros generados con **permisos 0600** (solo lectura dueño)
- Hash SHA-256 incluido en metadatos
- Exportación requiere confirmación si incluye >1000 entradas
- Logs de exportación registrados en audit trail

## Notas

- **Sin información sensible**: no incluye valores de variables de entorno ni secrets
- **Granularidad**: exportación a nivel acción, no a nivel detalle de datos procesados
- **Historial**: exportaciones antiguas archivadas en `.audit-archives/`
