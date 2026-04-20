# Portfolio-as-Graph — Cross-Project Dependencies

> **SPEC-SE-020 Slice 1** — foundational rule + schema.
> Ref: ROADMAP §Tier 5.12 · savia-enterprise portfolio coordination.

Cross-project dependencies are declared as local `.md`/`.yaml` files.
The portfolio graph is **computed on-demand** from those declarations —
never uploaded to a central SaaS (Sovereignty #1, Privacy #4).

## 1. Per-project declaration

Each project with cross-project dependencies includes `projects/{name}/deps.yaml`:

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

## 2. Required schema (Slice 1)

| Field | Type | Required | Validation |
|---|---|---|---|
| `project` | string | yes | non-empty, no spaces |
| `tenant` | string | yes | kebab-slug |
| `dependencies` | object | yes | has `upstream` and/or `downstream` |
| `dependencies.upstream[].project` | string | yes | non-empty |
| `dependencies.upstream[].type` | enum | yes | `blocks \| feeds \| shared-resource \| shared-platform` |
| `dependencies.upstream[].deliverable` | string | yes | non-empty |
| `dependencies.upstream[].needed_by` | date | yes | `YYYY-MM-DD` format |
| `dependencies.upstream[].status` | enum | yes | `on-track \| at-risk \| blocked \| delivered` |
| `dependencies.upstream[].contact` | string | recommended | `@handle` |
| `dependencies.downstream[]*` | same as upstream | optional | ditto |
| `shared_resources[].person` | string | yes if present | `@handle` |
| `shared_resources[].projects` | array[string] | yes if present | ≥2 projects |
| `shared_resources[].allocation_pct` | array[int] | yes if present | sum ≤ 100, len == projects len |
| `shared_resources[].conflict` | bool | yes if present | true/false |

## 3. Validator

`scripts/deps-validate.sh` validates a `deps.yaml` against the schema:

```
scripts/deps-validate.sh --file projects/erp-migration/deps.yaml
```

Exit codes:
- `0` — valid
- `1` — schema errors (listed in stdout)
- `2` — usage error (file not found, invalid args)

Human output and JSON (`--json`):

```
VALID: deps.yaml schema OK for project 'erp-migration'
  - 1 upstream deps  · 1 downstream deps  · 1 shared_resource
```

```json
{"valid":true,"project":"erp-migration","upstream":1,"downstream":1,"shared_resources":1}
```

## 4. When to declare

- Projects that block or are blocked by other projects (explicit dependency)
- Projects with shared resources (people or platforms)
- After kickoff in portfolios of ≥5 concurrent projects

NOT required for:
- Fully isolated standalone projects
- Pure technical dependencies (libs, infra) — those go in project manifest, not here
- Dependencies resolved within a single sprint (fine granularity)

## 5. Confidentiality & sovereignty

The `deps.yaml` file is **local to the tenant**. Never uploaded to external
SaaS services. Cross-tenant queries are forbidden (Principle #4).

If a project declares `contact: "@handle"`, the handle is an internal
tenant identifier — never email, never phone.

## 6. Lifecycle

```
new              → on-track       # kickoff
on-track         → at-risk        # slack_days ≤ threshold (5 days)
at-risk          → blocked        # needed_by passed without delivery
blocked/at-risk  → on-track       # recovery
on-track/at-risk → delivered      # delivered
```

Transitions emit events (Slice 2+): `deps.at_risk`, `deps.blocked`,
`deps.delivered`, `deps.contention`.

## 7. Integration with other specs

- **SE-017** (SOW) — `deliverable` can reference a D-NNN from SOW
- **SE-014** (Release) — `deps.delivered` triggers release checks
- **SE-029** (context compression) — declarations are class `spec` (frozen)
- **Savia Flow** — deps status reflected in portfolio board

## 8. Complete SPEC-SE-020 slicing

| Slice | Content | Status |
|---|---|---|
| **1** | Schema + rule + validator + tests (MVP) | merged |
| **2** | `portfolio-graph` (reads all deps.yaml → graph, ASCII/Mermaid/JSON) | merged |
| **3** | `portfolio-critical-path` (topological + slack + bottleneck) | merged |
| **4** | `portfolio-contention` (over-alloc + collision + bus-factor) | merged |
| 5 | Commands `/portfolio-graph`, `/portfolio-contention`, `/deps-status` | future |
| 6 | Events + Savia Flow integration | future |

## 9. References

- Spec: `docs/propuestas/savia-enterprise/SPEC-SE-020-cross-project-deps.md`
- Validator: `scripts/deps-validate.sh`
- Grapher: `scripts/portfolio-graph.sh`
- Critical path: `scripts/portfolio-critical-path.sh`
- Contention: `scripts/portfolio-contention.sh`
- Sample: `docs/examples/deps.yaml.sample`
- PMI Pulse 2024: ~47% of program failures from poorly managed dependencies

## 10. Related

- Spanish version: `docs/rules/domain/portfolio-as-graph.md`
