---
name: context-update
description: Audit and update Savia's markdown knowledge context — frontmatter lint, broken wikilinks, stale TODOs, duplicate IDs, schema drift, confidentiality leaks, tag consistency. SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2 Slice 6.
usage: /context-update [--scope all|opencode|content|vault|raw] [--slug SLUG] [--only structural|semantic] [--apply] [--dry-run] [--json]
aliases: [context-update, ctx-update]
---

# /context-update

Audita el contexto de conocimiento markdown del workspace y genera un informe
de hallazgos estructurales (F1) y semánticos (F2/F3, sub-slice 6b).

## Prerrequisitos

- Python 3.10+
- `scripts/context_update_main.py` y paquete `scripts/lib/context_update/`
- Workspace root resuelto por `savia-env.sh` (SPEC-127)

## Uso

```
/context-update                                 # scan completo, sin escrituras
/context-update --dry-run                       # idem (alias explícito)
/context-update --slug acme-project                # solo proyecto acme-project
/context-update --scope opencode                # solo .opencode/ y .claude/
/context-update --only structural               # solo F1 (8 jobs)
/context-update --apply                         # aplica fixes auto-aplicables (F4)
/context-update --json                          # output JSON para pipes
```

## Opciones

| Opción | Valores | Default | Descripción |
|---|---|---|---|
| `--scope` | all, opencode, content, vault, raw | all | Alcance del scan |
| `--slug` | string | — | Filtrar a un proyecto |
| `--only` | structural, semantic | — | Solo una fase |
| `--apply` | flag | false | Aplica fixes auto-aplicables |
| `--dry-run` | flag | false | Sin escrituras |
| `--json` | flag | false | Salida JSON |
| `--run-id` | string | auto | Reutilizar run existente |

## Fases

| Fase | Descripción | Estado |
|---|---|---|
| F0 | Discovery: resolución de raíces y listado de ficheros | ✅ Slice 6a |
| F1 | Structural checks: 8 jobs (lint, wikilinks, duplicados, etc.) | ✅ Slice 6a |
| F2/F3 | Semantic analysis + consolidación (agentes jueces) | Sub-slice 6b |
| F4 | Apply: aplica fixes opt-in | Parcial (auto-aplicables F1) |

## Jobs F1

1. `inventory` — estadísticas de ficheros por edad, nivel conf, scope
2. `frontmatter_lint` — validación de schema de frontmatter por patrón
3. `wikilink_check` — `[[wikilinks]]` rotos
4. `tag_consistency` — tags huérfanos/typos (singleton)
5. `confidentiality_leak` — señales PII/salario en ficheros de baja confidencialidad
6. `duplicate_ids` — IDs duplicados entre ficheros (`id:`, `spec_id:`, `slug:`)
7. `stale_todos` — TODO/FIXME/HACK sin actualizar > 30 días
8. `schema_drift` — keys obsoletas + drift respecto a mayoría del grupo

## Salida

- Run store: `~/.savia/context-update-tmp/{run_id}/`
- F1 por job: `F1/{job_id}.json`
- Agregado F1: `F1/_aggregate.json`
- F0 manifest: `F0_discovery.json`

## Ejecución

```bash
bash scripts/context-update.sh [opciones]
```
