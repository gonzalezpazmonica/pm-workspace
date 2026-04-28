# Reconciliation Delta Engine — declared vs computed invariant

> **SPEC**: SPEC-SE-035 (`docs/propuestas/savia-enterprise/SPEC-SE-035-reconciliation-delta-engine.md`)
> **Slice**: 1 (primitive `tenant_reconciliation_status`) + 3 (CLI wrapper). Slices 2 (dispatch registry seed), 4 (webhook+alerting), 5 (ratchet baseline) follow.
> **Status**: canonical. Convierte drift silencioso entre estado declarado y computado en alerta del mismo día.

---

## Tesis (one paragraph)

Una organización Enterprise mantiene **dos imágenes** del mundo: lo que dice tener (header del backlog SP, budget firmado, headcount declarado, KPIs publicados, hash del catálogo de conocimiento) y lo que **realmente tiene** (suma de PBI estimates, hours ledger × tarifa, asignaciones activas, métricas computadas en runtime, hash del estado actual). El silencio entre ambas imágenes es donde acumula el riesgo: cada unidad de drift sin detectar es credibilidad o margen erosionados, y normalmente sale a la luz en una review trimestral incómoda. El patrón opuesto — Balance (`dreamxist/balance`) — se niega a mentir sobre el dinero: si la posición real no cuadra con la suma de transacciones, el sistema bloquea. SPEC-SE-035 generaliza esa disciplina a portfolio health: una **función invariant tenant-level** que computa `declared - computed = delta` por dimensión, asigna un tier (green / amber / red) según thresholds configurables, y deja que el resto del sistema decida qué hacer con el resultado (dashboard, alerta, gate de release).

---

## Diseño

### 1. Storage — `reconciliation_dimensions` registry + `reconciliation_alerts` log

Tabla de origen: `docs/propuestas/savia-enterprise/templates/reconciliation.sql` (template canónico, MIT clean-room re-implementación de `dreamxist/balance` `00009_reconciliation.sql`).

| Tabla | Por qué |
|---|---|
| `reconciliation_dimensions` | Registry: cada fila es una dimensión reconciliable (`backlog_sp`, `budget`, `capacity`, `knowledge_catalog_hash`, ...). Define `declared_query` + `computed_query` SQL strings + `amber_threshold` + `red_threshold`. Permite Enterprise tenants añadir dimensiones propias en runtime. |
| `reconciliation_alerts` | Append-only log de transitions a amber/red. Auditable vía `attach_audit('reconciliation_alerts'::regclass)` (sinergia SPEC-SE-037). Indexed por `(tenant_id, dimension, alerted_at DESC)` para query reciente rápida. |

### 2. Primitive — `tenant_reconciliation_status(tenant, dimension)`

Función `STABLE` que devuelve JSONB:

```json
{
  "tenant_id": "...",
  "dimension": "budget",
  "declared": 120000,
  "computed": 117500,
  "delta": 2500,
  "abs_delta": 2500,
  "tier": "amber",
  "thresholds": {"amber": 1000, "red": 5000},
  "checked_at": "2026-04-28T15:32:11Z"
}
```

Tier cálculo idéntico al CLI `delta-tier.sh` (re-implementado en SQL para consistencia cross-language):

```
abs(declared - computed) >= red    → 'red'
abs(declared - computed) >= amber  → 'amber'
otherwise                          → 'green'
```

`STABLE` (no `IMMUTABLE`) porque las queries sub-yacentes leen tablas vivas. No `VOLATILE` para permitir cache dentro del mismo statement.

### 3. CLI — `scripts/enterprise/reconciliation-status.sh`

Wrapper bash que itera todas las dimensiones activas para un tenant y renderiza una tabla colored (verde/ámbar/rojo) o JSON estructurado.

```
$ reconciliation-status.sh --tenant <uuid>
DIMENSION                      DECLARED        COMPUTED        DELTA           TIER
---------                      --------        --------        -----           ----
budget                         120000          117500          2500            ● amber
backlog_sp                     320             318             2               ● green
knowledge_catalog_hash         a7f9...         a7f9...         0               ● green
capacity                       18              19              -1              ● green
```

Modo CI gate: `--fail-on red` retorna exit 7 si cualquier dimensión está en tier rojo (mismo pattern que hook-coverage ratchet, Slice 5 lo formaliza).

```
$ reconciliation-status.sh --tenant <uuid> --fail-on red
[...] tabla [...]
ALARM: 1 dimension(s) at tier 'red'
exit code: 7
```

Decisiones de diseño:

- **UUID validation antes de DSN/psql checks**: arg validation barata primero, fail-fast.
- **`--fail-on` accepta solo `green|amber|red`** (no levels custom; mantiene API limpia).
- **`--dimension` opcional** filtra a una sola dimensión (útil para CI gates específicos: e.g. solo `budget`).
- **`--json` mode** emite `jsonb_agg` con todas las dimensiones para integración con dashboards externos.
- **Color rendering inline** (no depende de `delta-tier.sh --color` para evitar fork overhead por fila).

### 4. Helper — `delta-tier.sh` (numeric tiering reutilizable)

`scripts/enterprise/delta-tier.sh` (pre-existente) computa tier desde dos numeric values en bash puro. Útil cuando un comando pm-workspace quiere renderizar drift sin tocar la DB (sprint-status, portfolio-overview con datos de Azure DevOps in-memory). El helper es **independiente** del SQL primitive — ambos usan los mismos thresholds por convención (1000 amber / 5000 red default).

### 5. Recompute strategy

| Estrategia | Cuándo | Coste | Implementado en |
|---|---|---|---|
| **On-demand** (CLI llama función) | Dashboard, CI gate, debug | O(query × N dimensiones) | Slice 1+3 (este) |
| **Materialized view** + `REFRESH CONCURRENTLY` | Reads frecuentes desde varios consumidores | O(query × tenants × dimensiones) batched | Slice 3 follow-up |
| **Trigger AFTER UPDATE** sobre tablas declarativas | Recompute tras cada write | O(N writes); riesgo recursivo | Slice 4 |

### 6. Recursión + race conditions

- **Triggers recursivos** (recompute → write → recompute) → `pg_advisory_lock` + flag `_in_reconciliation` en sesión (Slice 4).
- **Falsos amber por timing** (write vs read race) → re-check en amber: solo alerta tras 2 lecturas consecutivas (Slice 4).
- **Webhook abuse** → rate-limit per `(tenant, dimension)`: max 1 alerta / 15 min (Slice 4).

---

## Atribución

Re-implementación clean-room de `dreamxist/balance` `supabase/migrations/00009_reconciliation.sql` (MIT). El patrón position-vs-accumulated y la función `get_reconciliation_status()` son la fuente; aquí se **generaliza** a una primitiva tenant-aware con dispatch por dimensión, no se copia código verbatim.

---

## Cross-refs

- **SPEC-SE-002** — RLS multi-tenant para `reconciliation_dimensions` y `reconciliation_alerts`
- **SPEC-SE-018** — project-billing: dimension `budget` consume este primitive
- **SPEC-SE-022** — resource-bench: dimension `capacity` consume este primitive
- **SPEC-SE-023** — knowledge-federation: dimension `knowledge_catalog_hash` consume este primitive
- **SPEC-SE-024** — client-health: cross-tenant rollup de tiers
- **SPEC-SE-037** — `reconciliation_alerts` debe estar wired vía `attach_audit('reconciliation_alerts'::regclass)`
- **SPEC-SE-006** — governance-compliance auditará el log de alertas como evidencia

---

## Dimensiones seed (Slice 2 follow-up)

Plan de seed inicial cuando se implemente Slice 2:

| Dimension | declared_query (concept) | computed_query (concept) | Default thresholds |
|---|---|---|---|
| `backlog_sp` | `SELECT tenant_id, total_sp FROM tenant_backlog_header` | `SELECT tenant_id, sum(estimate_sp) FROM pbis WHERE active` | 5 / 20 (small numeric range) |
| `budget` | `SELECT tenant_id, signed_amount FROM tenant_budget` | `SELECT tenant_id, sum(hours * rate) FROM hours_ledger` | 1000 / 5000 (EUR) |
| `capacity` | `SELECT tenant_id, declared_headcount FROM tenant_contract` | `SELECT tenant_id, count(*) FROM active_assignments` | 0.5 / 2 (FTEs) |
| `knowledge_catalog_hash` | `SELECT tenant_id, declared_hash FROM tenant_knowledge_catalog` | `SELECT tenant_id, encode(digest(string_agg(content, '|'), 'sha256'), 'hex') FROM knowledge_entries GROUP BY 1` | 0 / 1 (hash equality binary) |

---

## No hace (esta Slice)

- NO implementa Slice 2 dispatch registry seed con dimensiones reales.
- NO implementa Slice 4 webhook + alerting (trigger + rate-limit).
- NO implementa Slice 5 ratchet baseline en CI.
- NO añade dependencia Supabase ni servicio managed.
- NO redefine RLS multi-tenant (asume SPEC-SE-002 estable).
- NO inventa thresholds — son configurables per dimension; defaults conservadores 1000/5000 (override per Enterprise tenant).
- NO escribe a sistemas externos (webhook explícito en Slice 4 con config gate).
