# SE-167 — Skill Maturity Kanban

> Status: IMPLEMENTED 2026-06-02
> Origin: ROADMAP rank 7, Era 252.
> Pattern: `Modern Web Guidance gd audit` (clean-room).

## Problema

98 skills sin eje único de madurez. Imposible priorizar trabajo de calibración. Algunas tienen tests+evals, otras son scaffolds vacíos, otras son obsoletas.

## Solución

Auditor reproducible que clasifica cada skill en 4 estados estructurales: Calibrated, Incomplete, Stub, Deprecated. Salida: TSV (machine-readable) + markdown kanban (human-readable). Sin opinión humana en el cálculo — todo basado en signals presentes en disco.

## Entregables

- `scripts/skill-maturity-audit.sh` — auditor con flags `--tsv-only` / `--markdown-only` / `--help`.
- `docs/rules/domain/skill-maturity-kanban.md` — reglas de transición y criterios.
- `tests/test-skill-maturity-audit.bats` — 23 tests cubriendo estructura, clasificación, idempotencia, edge cases.
- `output/skill-maturity-{audit,kanban}-YYYYMMDD.{tsv,md}` — output diario.

## Criterios

- **Calibrated**: `maturity: stable` + tests presentes (`tests/test-<name>.bats` o eval).
- **Incomplete**: SKILL+DOMAIN ok pero le falta una de las anteriores.
- **Stub**: missing DOMAIN.md o SKILL.md <50 líneas.
- **Deprecated**: frontmatter `deprecated: true`.
- `_template` excluido (scaffolding).

## Acceptance

- Auditor clasifica las 98 skills sin error (exit 0).
- Tests BATS 23/23 pass.
- TSV y markdown producidos en `output/` con fecha.
- Ejecuciones sucesivas son idempotentes (mismo md5 si nada cambia en skills).

## No-objetivos

- No reemplaza el frontmatter `maturity:` existente — lo combina con quality signals.
- No mide calidad semántica del prompt (eso es SE-084).
- No promueve skills automáticamente.
- No consulta tribunales.

## Estado inicial del workspace (2026-06-02)

- Calibrated: 1 (`knowledge-graph`)
- Incomplete: 94
- Stub: 3 (`grill-me`, `savia-identity`, `weekly-report`)
- Deprecated: 0

Esta línea base sirve como backlog gestionable para sprints futuros.

## Próximos pasos (opcional, fuera de SE-167)

- Hook post-commit que ejecute auditor cuando cambian skills.
- Comando `/savia-audit` que muestre el kanban en consola.
- Evolución a SE-166 (Skill Calibration Pipeline) cuando exista corpus de evals.
