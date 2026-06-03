# Skill Maturity Kanban — 4 estados canónicos

> Pattern alignment: `Modern Web Guidance gd audit` (clean-room) — SE-167.
> Auditor: `scripts/skill-maturity-audit.sh`. Output diario: `output/skill-maturity-{audit,kanban}-YYYYMMDD.{tsv,md}`.

## Por qué

Las 98 skills del workspace existen en estados muy distintos: algunas son scaffolds vacíos, otras tienen tests + evals completos, otras son obsoletas. Sin un eje único de madurez es imposible priorizar dónde invertir trabajo de calibración.

Este kanban da un veredicto reproducible por skill — sin opinión humana — para que `savia` pueda decir "estas 12 skills son Calibrated, estas 47 son Incomplete por falta de tests, estas 3 son Stub que hay que cerrar o borrar".

## Los 4 estados

| Estado | Criterio reproducible | Acción típica |
|---|---|---|
| **Calibrated** | `maturity: stable` + tests/evals presentes + DOMAIN.md completo | Mantener, monitorizar regresiones |
| **Incomplete** | SKILL+DOMAIN ok, pero falta uno de: `maturity: stable`, tests, evals | Añadir tests; promover de beta/experimental a stable |
| **Stub** | Falta DOMAIN.md, o SKILL.md `<50` líneas | Decidir: terminar o eliminar |
| **Deprecated** | Frontmatter `deprecated: true` | Eliminar tras periodo de gracia |

`_template` queda excluido (scaffolding, no deployable).

## Reglas de transición

- **Stub → Incomplete**: añadir DOMAIN.md y al menos 50 líneas de protocolo en SKILL.md.
- **Incomplete → Calibrated**: marcar `maturity: stable` + crear `tests/test-<skill>.bats` o `tests/evals/*<skill>*.bats`.
- **Calibrated → Deprecated**: añadir `deprecated: true` al frontmatter cuando se reemplaza la skill o se retira del catálogo.
- **Cualquier → Deprecated**: solo vía marcador explícito en frontmatter, nunca implícito.

## Invariantes verificadas por tests BATS

`tests/test-skill-maturity-audit.bats` enforz:
- Estado de cada skill ∈ {Calibrated, Incomplete, Stub, Deprecated}
- Suma de estados en kanban markdown = filas TSV
- Calibrated implica stable + has_test
- Stub implica missing DOMAIN.md OR <50 lines
- Idempotencia: re-ejecutar produce TSV idéntico

## Uso

```bash
bash scripts/skill-maturity-audit.sh                  # TSV + markdown
bash scripts/skill-maturity-audit.sh --tsv-only       # solo TSV
bash scripts/skill-maturity-audit.sh --markdown-only  # solo kanban
```

Ejecutar diariamente vía cron o hook post-commit en cambios de skills es opcional — el TSV ya identifica los cambios sin scheduling.

## Compatibilidad con `maturity:` existente

El frontmatter `maturity:` actual (`stable` / `beta` / `experimental` / `template`) se mantiene. Este kanban no sustituye el campo — lo combina con quality signals (DOMAIN.md, tests) para producir el estado de 4 columnas.

Mapping informal:
- `template` → excluido
- `stable` + tests → Calibrated
- `stable` sin tests → Incomplete
- `beta` / `experimental` → Incomplete (independientemente de tests)

## No-objetivos

- No mide quality interna del prompt — eso es SE-084 (skill-catalog-audit).
- No corrige ni promueve skills automáticamente.
- No consulta tribunales — es estructural, no semántico.
