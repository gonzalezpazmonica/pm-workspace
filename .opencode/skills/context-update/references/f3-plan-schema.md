# F3 Plan — Schema canónico de F3_plan.json

## Estructura raíz

```json
{
  "run_id":    "string",
  "generated": "ISO 8601 timestamp",
  "metrics": {
    "composite_quality":       0.81,
    "composite_quality_grade": "B+",
    "trend":                   "+0.03",
    "coverage_frontmatter":    0.94,
    "confidentiality_integrity": 1.0
  },
  "summary": {
    "run_id":         "string",
    "generated":      "ISO 8601",
    "total_findings": 1265,
    "total_files":    507,
    "by_severity":    {"ERROR": 4, "WARNING": 227, "INFO": 1034},
    "by_phase":       {"F1": 546, "F2": 719},
    "top_files":      [{"file": "path", "count": 12}],
    "elapsed_s":      8.4
  },
  "plan": {
    "block_1_critical":    {...},
    "block_2_important":   {...},
    "block_3_maintenance": {...},
    "block_4_quality":     {...}
  },
  "backlog": {"count": 42}
}
```

## Schema de bloque

```json
{
  "label":      "CRÍTICO — errores estructurales y secretos",
  "item_count": 3,
  "items": [
    {
      "id":              "1.1",
      "action":          "Remove secret in `java-rules.md`: JDBC Connection",
      "command_hint":    "manual",
      "auto_applicable": false,
      "severity":        "ERROR",
      "file":            "docs/rules/languages/java-rules.md",
      "job":             "secret_scan",
      "finding_refs":    ["secret_scan:docs/rules/languages/java-rules.md"]
    }
  ]
}
```

## composite_quality

| Score | Grade |
|-------|-------|
| ≥ 0.90 | A |
| ≥ 0.80 | B+ |
| ≥ 0.70 | B |
| ≥ 0.60 | C |
| < 0.60 | D |

Fórmula:
```
score = 1.0
       - min(error_count   * 0.05, 0.40)
       - min(warning_count * 0.02, 0.30)
       - min(info_count    * 0.01, 0.15)
score = max(score, 0.0)
```

## Bloques y reglas de asignación

| Bloque | Jobs/agentes asignados | Severidad default |
|--------|----------------------|-------------------|
| CRÍTICO | `secret_scan`, `confidentiality_leak`, cualquier ERROR | ERROR |
| IMPORTANTE | `frontmatter_lint`, `wikilink_check`, `context_coherence_judge`, `consistency_judge` | WARNING |
| MANTENIMIENTO | `staleness`, `duplicate_detection`, `context_obsolescence_judge`, `context_redundancy_judge` | INFO/WARNING |
| CALIDAD | `tag_consistency`, `context_quality_judge`, `relevance_judge`, `completeness_judge`, `actionability_judge` | INFO |

## Cap y backlog

Máximo 30 items en el plan visible (prioridad: CRÍTICO → IMPORTANTE → MANTENIMIENTO → CALIDAD).
El resto va al `backlog` — accesible en `consolidated.json`.
