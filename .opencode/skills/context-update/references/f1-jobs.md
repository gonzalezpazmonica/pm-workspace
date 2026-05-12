# F1 Jobs — Schema de findings

Todos los jobs F1 emiten findings con este schema base:

```json
{
  "job":            "string — job id (snake_case)",
  "severity":       "ERROR | WARNING | INFO",
  "confidence":     "HIGH | MEDIUM | LOW",
  "file":           "string — path relativo al workspace root",
  "message":        "string — descripción del issue",
  "auto_applicable": false,
  "line":           0    // opcional, cuando aplica
}
```

## Jobs y sus findings específicos

### inventory
- `severity: INFO` — estadísticas del workspace (no findings individuales per-se)

### frontmatter_lint
- `severity: WARNING` — frontmatter ausente, campo requerido faltante, tipo incorrecto
- Campo extra: `"field": "nombre del campo problemático"`

### wikilink_check
- `severity: WARNING` — wikilink roto (target no existe)
- `severity: INFO` — documento no referenciado (orphaned)
- Campo extra: `"target": "path del target esperado"`

### tag_consistency
- `severity: INFO` — tag con variante ortográfica detectada
- Campo extra: `"canonical": "tag canónico sugerido"`

### confidentiality_leak
- `severity: ERROR` — dato confidencial (N4/N4b) detectado en fichero público (N1)
- `severity: WARNING` — posible leak, requiere revisión

### secret_scan
- `severity: ERROR` — patrón de credencial detectado (connection string, API key, private key, IP RFC-1918 privada)
- Campo extra: `"pattern_type": "connection_string | api_key | private_key | ip_private | ..."`

### staleness
- `severity: WARNING` — fichero no modificado en > 365 días
- `severity: INFO` — fichero no modificado en 180–365 días
- Campo extra: `"age_days": 420`

### duplicate_detection
- `severity: WARNING` — par de ficheros con Jaccard ≥ 0.70 (MinHash)
- Campo extra: `"duplicate_of": "path del fichero similar"`, `"jaccard": 0.82`
