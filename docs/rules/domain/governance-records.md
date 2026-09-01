---
context_tier: L3
token_budget: 700
---

# Governance Records — capa consultable sobre Markdown (SE-363)

> Patrón "registros, no archivos" (Anthropic AI-Native SDLC Playbook): el
> Markdown (CRITERIO.md, CONSTITUCION.md) es la **interfaz legible**; debajo
> existe una capa de **registro estructurado y consultable** que responde quién
> aprobó, en qué estado está, qué política aplicó.

## Registro

`data/governance/criterios.jsonl` (versionado) — un registro por CRIT con:

- `id`, `title`, `dureza`, `principio`, `enforcement`, `provenance`
- `status` (ACTIVE/SUPERSEDED/DRAFT)
- `approved_by` (quién aprobó)

## Sincronización

`scripts/governance-sync.py sync --source CRITERIO.md --output data/governance/criterios.jsonl`
- Idempotente por `id` (upsert, no duplica)
- `--check` → exit 1 si hay drift (CRIT en MD sin registro, o registro sin MD)

## Consulta

`scripts/governance-query.sh [--status ACTIVE] [--approved-by X] [--json]`

## Garantías

- El Markdown **nunca se modifica** por el sincronizador (es la fuente).
- CRIT-001: todo local; el registro es consultable a escala, sin texto plano en
  prompts.

## Referencias

- SE-363: `docs/specs/SE-363-records-not-files.spec.md`
- `CRITERIO.md`, `CONSTITUCION.md`, CRIT-001
