---
context_tier: L2
token_budget: 582
---

# Project Twin as Code — Regla canónica
# Spec: SPEC-169 · Status: IMPLEMENTED

> El twin de un proyecto es su reflejo versionado en markdown: estado,
> predicciones y reglas de negocio en un solo artefacto actualizable.

## Localización

`projects/{slug}/twin.md` — tracked por git, N2 (proyecto).

## Schema obligatorio (frontmatter)

```yaml
---
twin_id: "{slug}"
spec_version: "1.0"
last_refresh: "YYYY-MM-DDTHH:MM:SSZ"
stale_after_days: 14
token_budget: 2000
health: green | yellow | red
predictions:
  sprint_slip:      { value: 0.0-1.0, confidence: 0.0-1.0, evidence_ref: "..." }
  next_blocker:     { value: "descripción", confidence: 0.0-1.0, evidence_ref: "..." }
  scope_drift:      { value: 0.0-1.0, confidence: 0.0-1.0, evidence_ref: "..." }
  aggregate_health: { value: green|yellow|red, confidence: 0.0-1.0, evidence_ref: "..." }
---
```

## Secciones obligatorias (en orden)

1. `## Estado` — sprint activo, items abiertos, bloqueantes conocidos
2. `## Reglas` — reglas de negocio del proyecto (referencia a `reglas-negocio.md` si existe)
3. `## Predicciones` — las 4 predicciones del frontmatter en prosa con fuente citable

## Sección opcional

4. `## Grafo` — dependencias entre specs/PBIs (requires SE-162 ✓)

## Campos prohibidos en el cuerpo

Los campos siguientes nunca pueden aparecer en el cuerpo del twin
(el linter `scripts/twin-linter.sh` los bloquea en pre-commit):

- `assigned_to`, `assignee`, `owner`
- `evaluation`, `competencia`, `performance`
- `1on1`, `one_on_one`, `feedback_personal`
- `salary`, `salario`, `compensation`
- Handles nominativos (`@nombre-real`) — solo roles (`@backend-lead`)

## Decay

Si `last_refresh` supera `stale_after_days` días, el linter emite
`STALE` y bloquea `/twin-load` hasta refresh o reset manual.

## Vista pública (N1)

`/twin-anonymize {slug}` genera `docs/case-studies/{slug-anon}.twin.md`
sin nombre de organización, sin handles, solo métricas relativas.
Ver `docs/rules/domain/zero-project-leakage.md`.

## Telemetría

- `output/twin-runs/loads.jsonl` — cada `/twin-load` (append-only)
- `output/twin-runs/refresh-{slug}.jsonl` — cada refresh (append-only)

## Referencias

- `docs/propuestas/SPEC-169-project-twin.md`
- `docs/rules/domain/zero-project-leakage.md`
- `docs/propuestas/SPEC-156-token-budget-frontmatter.md`
