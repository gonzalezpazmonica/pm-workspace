# Query Library Protocol — SE-031

> **Regla**: WIQL / JQL / Savia Flow queries viven como snippets versionados en `.claude/queries/`, accesibles por ID. Nunca inline en commands nuevos.

## Principio

1 query = 1 fichero. 1 fichero = 1 fuente de verdad.
Cuando el schema de Azure DevOps / Jira cambia, el fix es 1 sitio, no 10.

## Estructura canónica

```
.claude/queries/
├── azure-devops/   *.wiql
├── jira/           *.jql
├── savia-flow/     *.yaml
└── INDEX.md        (auto-generado, no editar a mano)
```

## Formato de un snippet

Cada fichero tiene **frontmatter YAML obligatorio** seguido del cuerpo:

```
---
id: kebab-case-unique                 # requerido
lang: wiql | jql | savia-flow         # requerido
description: Una linea en espanol     # requerido
params:                               # opcional
  - nombre: descripcion del parametro
returns: [campo1, campo2]             # opcional, documentativo
tags: [categoria1, categoria2]        # opcional
---
<cuerpo del query con {{param}} placeholders>
```

### IDs

- kebab-case, unicos en el arbol `.claude/queries/`
- Prefijo tematico recomendado pero no obligatorio: `blocked-`, `velocity-`, `bugs-`.
- No cambiar un ID una vez publicado (rompe commands que lo usan).

### Parametros

- Placeholder: `{{nombre}}` en el cuerpo.
- El resolver valida que los placeholders esten sustituidos; si no, emite warning en stderr.
- Escape automatico para `&`, `/`, `\` en los valores.

## Uso desde commands

**Prohibido** (drift garantizado):

```bash
QUERY="SELECT [System.Id] FROM WorkItems WHERE [System.IterationPath] UNDER '$SPRINT' AND [System.State] = 'Blocked'"
```

**Correcto**:

```bash
QUERY=$(bash scripts/query-lib-resolve.sh --id blocked-pbis-over-3d --param sprint="$SPRINT")
curl -u ":$(cat $PAT_FILE)" -X POST -H "Content-Type: application/json" \
  -d "{\"query\":\"$QUERY\"}" "$ORG_URL/$PROJECT/_apis/wiql?api-version=7.0"
```

## Resolver CLI

```
# Por ID
bash scripts/query-lib-resolve.sh --id <id> [--param k=v ...]

# Listado (table + filtros)
bash scripts/query-lib-resolve.sh --list [--lang wiql|jql|savia-flow] [--json]
```

Exit codes: `0` OK, `1` query no encontrada, `2` error de input.

## NL-to-query (slice 2)

```
# Natural language → query ID (stdout)
bash scripts/query-lib-nl.sh "PBIs bloqueados mas de 3 dias"
# → blocked-pbis-over-3d

# JSON verbose (score, path, resolved_by hint)
bash scripts/query-lib-nl.sh --json "velocity ultimos 3 sprints"

# Filtrar por lang y ajustar umbral
bash scripts/query-lib-nl.sh --lang jql --min-score 0.25 "mis issues abiertos"

# Pipe end-to-end NL → WIQL body
ID=$(bash scripts/query-lib-nl.sh "PBIs bloqueados mas de 3 dias")
bash scripts/query-lib-resolve.sh --id "$ID" --param sprint="$SPRINT_ACTUAL"
```

Algoritmo:
1. **Normalizacion**: lowercase + strip accents + drop puntuacion.
2. **Alias expansion**: mapa bilingue ES/EN (blocked↔bloqueado, sprint↔iteracion, pbi↔backlog↔item, velocity↔velocidad, days↔dias, open↔abierto↔activo, ...).
3. **F1 / Dice coefficient**: `2·|NL ∩ haystack| / (|NL| + |haystack|)` sobre descripcion + tags + id kebab tokens. Mas robusto que Jaccard frente a haystacks desbalanceadas.
4. **Shingle boost**: +0.1 si un 2-gram de la NL aparece literal en la descripcion (hasta 1.0).
5. **Winner rule**: match unico si 1 candidato pasa el umbral o el top supera al segundo por ≥0.15. Si no: exit 2 con lista de disambiguacion.
6. **Fallback**: exit 1 + schema prompt con campos WIQL de referencia.

Exit codes: `0` match unico, `1` sin match (prompt emitido), `2` ambiguo, `3` error de input.

Umbral por defecto `--min-score 0.30`. Bajalo a `0.20` para recall mayor en NL cortos (2 tokens).

## Index generator

```
bash scripts/query-lib-index.sh          # regenera INDEX.md
bash scripts/query-lib-index.sh --check  # CI: falla si esta stale
```

CI debe incluir `--check` para garantizar que cualquier snippet nuevo regenera el INDEX antes de merge.

## Hygiene rules (obligatorias)

1. **Un snippet por caso de uso** — sin multi-proposito con IFs.
2. **Sin hardcoded IterationPath** — siempre parametrizado con `{{sprint}}`, `{{owner}}`, `{{project}}`.
3. **Cambiar schema = 1 commit** — el punto del patron.
4. **Deprecacion explicita** — para sustituir un snippet, anadir el nuevo, migrar callers, borrar el viejo en el mismo PR.
5. **Backticks en el cuerpo** — permitidos en WIQL/JQL porque el resolver los trata como texto plano. Nunca usar backticks en el `description:` del frontmatter.

## Seguridad

- Los snippets son **lectura**: no mutan Azure DevOps / Jira.
- Un snippet futuro que mute estado (p.ej. update state) debe marcarse `mutating: true` en frontmatter y exigir `--confirm` en el resolver — alcance de SE-031 slice 2.
- Params con quotes peligrosos se escapan; revisa el output antes de pasar a `curl -d`.

## Lesson learned — fork bomb 2026-04-18

El generador INDEX inicial usaba `python3 <<PY` (heredoc no quoted). El cuerpo incluia backticks alrededor de `scripts/query-lib-index.sh`. Bash los interpreto como command substitution antes de pasar al python, ejecutando el script recursivamente. Resultado: 15.245 procesos bash fork-bombed.

Fix canonico: **heredocs con python embebido SIEMPRE usan `<<'PY'`** (delimitador quoted). Si se necesita pasar una variable bash al python, via `export` + `os.environ.get`. Test de regresion: `index script heredoc is quoted (no fork bomb)` en `tests/test-query-lib.bats`.

## Referencias

- Spec: `docs/propuestas/SE-031-query-library-nl.md`
- Skills relacionados: `nl-query`, `azure-devops-queries`, `savia-flow`
- Tests: `tests/test-query-lib.bats` (31 tests)
