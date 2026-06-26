---
context_tier: L2
token_budget: 400
spec_ref: SE-203
---

# Skill Trigger Map

> Auto-populated from `trigger.keywords` frontmatter in `.opencode/skills/*/SKILL.md`.
> Ref: SE-203 — Keyword triggers para skills.

## Tabla de triggers registrados

| Skill | Keywords |
|---|---|
| `adversarial-security` | vulnerabilidad, pentest, sql injection, xss, inyeccion, security audit, red team, blue team |
| `savia-memory` | recuerda, memory, guarda, memoriza, olvidas, recall |
| `tdd-vertical-slices` | tdd, test-first, red-green, vertical slice, anti-horizontal |
| `spec-driven-development` | spec, sdd, especificación ejecutable, specification |
| `knowledge-graph` | grafo, knowledge graph, entidades, relaciones, kg |
| `weekly-report` | informe semanal, weekly, reporte semanal |
| `caveman` | brutal, caveman, sin filtros, honestidad brutal, strip |
| `zoom-out` | zoom out, big picture, segunda orden, second-order, dependencies |
| `grill-me` | grill, weaknesses, edge cases, adversarial, hunt weaknesses |
| `performance-audit` | performance, hotspot, lento, optimiza, bottleneck, rendimiento |
| `write-a-skill` | crea skill, nueva skill, write-a-skill, skill nuevo |

## Cómo funciona

El detector `scripts/skill-keyword-detector.sh` lee todos los SKILL.md con frontmatter `trigger.keywords`, compara (case-insensitive) contra el texto de input, y devuelve la lista de skills a auto-cargar.

- **Detección**: `bash scripts/skill-keyword-detector.sh "quiero hacer tdd"` → `tdd-vertical-slices`
- **Multi-match**: `"spec de seguridad"` → `spec-driven-development` + otros skills con keywords coincidentes
- **Lista completa**: `bash scripts/skill-keyword-detector.sh --list`
- **JSON output**: `bash scripts/skill-keyword-detector.sh --json "<texto>"`

## Extensión

Para añadir triggers a un nuevo skill, editar el frontmatter YAML:

```yaml
trigger:
  type: keyword
  keywords: [kw1, kw2, kw3]
```

A continuación regenerar esta tabla ejecutando:
```bash
bash scripts/skill-keyword-detector.sh --list
```
