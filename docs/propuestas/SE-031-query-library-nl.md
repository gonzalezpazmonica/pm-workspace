---
id: SE-031
title: Query Library + NL-to-WIQL/JQL — Retool-inspired patterns
status: PROPOSED
origin: Retool research (2026-04-18) — roba Query Library + NL-to-SQL patterns
author: Savia
related: nl-query skill, azure-devops-queries skill, savia-flow skill
---

# SE-031 — Query Library + NL-to-WIQL/JQL

## Why

Retool y sus clones OSS destacan 2 patrones con fit real para Savia (el resto es GUI que no necesitamos):

1. **Query Library** — snippets reusables por ID, evita copy-paste de WIQL/JQL/SQL en 532 commands.
2. **Text-to-query** — un PM escribe "PBIs bloqueados > 3 días" y obtiene WIQL/JQL ejecutable.

Savia hoy: cada command tiene WIQL inline. Cuando el schema de Azure DevOps cambia, hay drift en 10+ sitios. `nl-query` skill existe pero sin grammar training WIQL específica.

## Scope

### 1. Query Library (SE-031-L)

Directorio canónico `.claude/queries/` con estructura:

```
.claude/queries/
├── azure-devops/
│   ├── blocked-pbis-over-3d.wiql
│   ├── active-sprint-capacity.wiql
│   ├── pbis-by-owner.wiql
│   └── ...
├── jira/
│   ├── blocked-issues.jql
│   └── ...
├── savia-flow/
│   └── ...
└── INDEX.md
```

Cada snippet tiene header YAML:

```wiql
---
id: blocked-pbis-over-3d
description: PBIs bloqueados más de 3 días sin actualización
params:
  - sprint: Sprint iteration path (e.g. "ProjectX\\Sprint 2026-04")
returns: id, title, state, assignedTo, changedDate
tags: [azure-devops, blocked, sla]
---
SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo], [System.ChangedDate]
FROM WorkItems
WHERE [System.WorkItemType] = 'Product Backlog Item'
  AND [System.IterationPath] UNDER '{{sprint}}'
  AND [System.State] = 'Blocked'
  AND [System.ChangedDate] < @Today - 3
```

### 2. Query resolver (SE-031-R)

Script `scripts/query-lib-resolve.sh`:

```bash
# Get raw query
bash scripts/query-lib-resolve.sh --id blocked-pbis-over-3d --lang wiql

# Substitute params
bash scripts/query-lib-resolve.sh --id blocked-pbis-over-3d --param sprint="ProjectX\\Sprint 2026-04"

# List all queries
bash scripts/query-lib-resolve.sh --list --json
```

### 3. NL-to-query (SE-031-N)

Script `scripts/query-lib-nl.sh` — recibe NL, consulta library, y si no hay match exact, propone WIQL con schema prompt:

```bash
bash scripts/query-lib-nl.sh "PBIs blocked more than 3 days"
# → matches: blocked-pbis-over-3d
# → output: resolved WIQL

bash scripts/query-lib-nl.sh "count commits per dev this week"
# → no match — emits placeholder + schema prompt for human/LLM
```

## Design

### Structure of INDEX.md (auto-generated)

```markdown
# Query Library INDEX

| ID | Lang | Tags | Description |
|---|---|---|---|
| blocked-pbis-over-3d | WIQL | blocked, sla | PBIs bloqueados > 3 días |
| ... |
```

Regenerar con `scripts/query-lib-index.sh`. CI check freshness.

### Integration con commands existentes

Commands que hoy tienen WIQL inline (ej. `sprint-status`, `board-flow`) se migran a:

```bash
QUERY=$(bash scripts/query-lib-resolve.sh --id blocked-pbis-over-3d \
  --param sprint="$SPRINT_ACTUAL")
curl ... -d "$QUERY" https://dev.azure.com/.../wiql
```

Reducción: 1 fuente de verdad por query. Cambio de schema → 1 sitio.

## Acceptance Criteria

- [ ] AC-01 `.claude/queries/{azure-devops,jira,savia-flow}/` directorios creados con ≥8 snippets iniciales
- [ ] AC-02 `scripts/query-lib-resolve.sh` implementado con `--id`, `--param`, `--list`, `--json`
- [ ] AC-03 `scripts/query-lib-nl.sh` heurístico exact+fuzzy match, fallback schema prompt
- [ ] AC-04 `scripts/query-lib-index.sh` genera `INDEX.md` auto
- [ ] AC-05 Tests bats 25+ (resolve, substitute, list, nl-match)
- [ ] AC-06 Docs: `docs/rules/domain/query-library-protocol.md`
- [ ] AC-07 CHANGELOG entry

## Agent Assignment

Capa: Skills + scripts
Agente: tech-writer + python-developer (opcional)

## Slicing

- Slice 1 (este PR): snippets + resolver script + INDEX generator + tests
- Slice 2: NL-to-query heurístico + schema prompts
- Slice 3: Migrar 5 commands existentes a query library (demo value)

## Feasibility Probe

Time-box: 3h para slice 1. Riesgo principal: params substitution con quotes/escapes tricky en WIQL. Mitigación: resolver usa placeholder-replacement simple + tests case-by-case.

## Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Params con quotes/backslashes rompen WIQL | Alta | Medio | Resolver valida + escapa; tests bats coverage |
| Drift entre INDEX.md y snippets | Media | Bajo | `query-lib-index.sh --check` en CI |
| NL matching falla en queries no listadas | Alta | Bajo | Fallback graceful con schema prompt |
| Migrar 5 commands existentes rompe flujo | Media | Alto | Slice 3 separado, feature-flag |

## Métricas éxito

- 8+ snippets listos en slice 1
- ≥ 5 commands migrados en slice 3 (reducción WIQL inline)
- Drift-check passing en CI

## Referencias

- Retool Query Library pattern
- [Appsmith datasources + queries](https://github.com/appsmithorg/appsmith)
- Skills existentes: `nl-query`, `azure-devops-queries`
