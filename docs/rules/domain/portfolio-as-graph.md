# Portfolio-as-Graph — Cross-Project Dependencies

> **SPEC-SE-020 Slice 1** — foundational rule + schema.
> Ref: ROADMAP §Tier 5.12 · savia-enterprise portfolio coordination.

Las dependencias entre proyectos se declaran como archivos `.md`/`.yaml` locales.
El grafo de portfolio se **computa on-demand** desde esas declaraciones — nunca
se sube a un SaaS central (Soberanía #1, Privacidad #4).

## 1. Declaración per-project

Cada proyecto con dependencias cross-project incluye `projects/{name}/deps.yaml`:

```yaml
---
project: "erp-migration"
tenant: "acme-consulting"
dependencies:
  upstream:
    - project: "sso-integration"
      type: "blocks"              # blocks | feeds | shared-resource | shared-platform
      deliverable: "D-003"
      needed_by: "2026-07-15"
      status: "on-track"          # on-track | at-risk | blocked | delivered
      contact: "@pm-sso"
  downstream:
    - project: "mobile-app"
      type: "feeds"
      deliverable: "REST API spec"
      needed_by: "2026-09-01"
      contact: "@pm-mobile"
shared_resources:
  - person: "@dba-lead"
    projects: ["erp-migration", "data-platform", "mobile-app"]
    allocation_pct: [50, 30, 20]
    conflict: true
---
```

## 2. Schema obligatorio (Slice 1)

| Campo | Tipo | Requerido | Validación |
|---|---|---|---|
| `project` | string | sí | no vacío, sin espacios |
| `tenant` | string | sí | slug-kebab |
| `dependencies` | object | sí | tiene `upstream` y/o `downstream` |
| `dependencies.upstream[].project` | string | sí | no vacío |
| `dependencies.upstream[].type` | enum | sí | `blocks \| feeds \| shared-resource \| shared-platform` |
| `dependencies.upstream[].deliverable` | string | sí | no vacío |
| `dependencies.upstream[].needed_by` | date | sí | formato `YYYY-MM-DD` |
| `dependencies.upstream[].status` | enum | sí | `on-track \| at-risk \| blocked \| delivered` |
| `dependencies.upstream[].contact` | string | recomendado | `@handle` |
| `dependencies.downstream[]*` | ídem upstream | opcional | ídem |
| `shared_resources[].person` | string | sí si presente | `@handle` |
| `shared_resources[].projects` | array[string] | sí si presente | ≥2 proyectos |
| `shared_resources[].allocation_pct` | array[int] | sí si presente | suma ≤ 100, len == projects len |
| `shared_resources[].conflict` | bool | sí si presente | true/false |

## 3. Validador

`scripts/deps-validate.sh` valida un `deps.yaml` contra el schema:

```
scripts/deps-validate.sh --file projects/erp-migration/deps.yaml
```

Exit codes:
- `0` — válido
- `1` — errores de schema (listados en stdout)
- `2` — error de uso (fichero no existe, args inválidos)

Output humano y JSON (`--json`):

```
VALID: deps.yaml schema OK for project 'erp-migration'
  - 1 upstream deps  · 1 downstream deps  · 1 shared_resource
```

```json
{"valid":true,"project":"erp-migration","upstream":1,"downstream":1,"shared_resources":1}
```

## 4. Cuándo declarar

- Proyectos que bloquean o son bloqueados por otros proyectos (dependencia explícita)
- Proyectos con recursos compartidos (personas o plataformas)
- Tras kickoff en portfolio de ≥5 proyectos concurrentes

NO necesario para:
- Proyectos completamente aislados (standalone)
- Dependencias técnicas puras (libs, infra) — van en manifiesto del proyecto, no aquí
- Dependencias que se resuelven dentro de un mismo sprint (granularidad fina)

## 5. Confidencialidad y sovereignty

El fichero `deps.yaml` es **local al tenant**. No se sube a servicios SaaS
externos. Queries cross-tenant están prohibidas (Principio #4).

Si un proyecto declara `contact: "@handle"`, el handle es un identificador
interno del tenant — nunca email, nunca teléfono.

## 6. Ciclo de vida

```
new              → on-track       # kickoff
on-track         → at-risk        # slack_days ≤ threshold (5 días)
at-risk          → blocked        # needed_by pasado sin entrega
blocked/at-risk  → on-track       # recovery
on-track/at-risk → delivered      # entregado
```

Transitions emiten eventos (Slice 2+): `deps.at_risk`, `deps.blocked`,
`deps.delivered`, `deps.contention`.

## 7. Integración con otros specs

- **SE-017** (SOW) — `deliverable` puede referenciar un D-NNN de SOW
- **SE-014** (Release) — `deps.delivered` dispara checks de release
- **SE-029** (context compression) — declaraciones son clase `spec` (frozen)
- **Savia Flow** — estado deps se refleja en board de portfolio

## 8. Slicing completo SPEC-SE-020

| Slice | Contenido | Estado |
|---|---|---|
| **1** | Schema + rule + validator + tests (MVP) | este PR |
| 2 | `portfolio-grapher` agent (reads all deps.yaml → graph) | futuro |
| 3 | `critical-path-analyzer` (cross-project) | futuro |
| 4 | `contention-detector` + rebalancer proposals | futuro |
| 5 | Commands `/portfolio-graph`, `/portfolio-contention`, `/deps-status` | futuro |
| 6 | Events + Savia Flow integration | futuro |

## 9. Referencias

- Spec: `docs/propuestas/savia-enterprise/SPEC-SE-020-cross-project-deps.md`
- Validator: `scripts/deps-validate.sh`
- Sample: `docs/examples/deps.yaml.sample`
- PMI Pulse 2024: ~47% de program failures por dependencias mal gestionadas
