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
