---
id: SE-318
title: "SE-318 — Blast-radius pre-commit: simulación de impacto antes de escribir"
status: IMPLEMENTED
priority: media
---

# SE-318 — Blast-radius pre-commit: simulación de impacto antes de escribir

**Status:** IMPLEMENTED
**Fecha:** 2026-08-09
**Area:** Code intelligence / Agent guards / Commit guardian
**Branch sugerida:** `agent/se318-blast-radius`
**Estimacion total:** ~26h (3 slices)
**Inspiracion:** `zzet/gortex` (preview_edit / simulate_chain, blast-radius reach index)

---

## Contexto y evidencia (2026-08-09)

gortex ofrece `preview_edit` y `simulate_chain`: responden "qué cambiaría si
aplicara este WorkspaceEdit?" **sin tocar disco**, gracias a un índice de
reach precomputado (depth-3) que convierte consultas de blast-radius en
lookups O(seeds × reach).

Savia tiene:
- `commit-guardian` (verifica staged contra reglas, antes del commit),
- `codegraph` (indexación AST persistente, callers/callees),
- `feasibility-probe` (prototipo time-boxed para validar viabilidad de specs).

**El hueco.** Ningún gate de Savia responde *"qué más se rompe si cambio este
símbolo/función/fichero"* antes de aplicar el cambio. El commit-guardian actúa
después del edit (sobre staged); codegraph puede navegar callers pero no hay
una consulta de blast-radius integrada en el flujo pre-write. Un cambio de
firma en un método público puede romper 20 callers sin que el agente lo sepa
hasta que fallan los tests.

---

## Objetivo

Añadir una consulta de blast-radius pre-write integrada en el flujo de edición:
dado un cambio propuesto (símbolo/función/fichero), listar los callers y
dependientes afectados antes de aplicar el edit. Reutiliza el índice de
`codegraph` y expone CLI + hook.

---

## Out of scope

- NO implementar un simulador de ejecución (ejecutar el cambio en sandbox es
  factibilidad, no blast-radius estático).
- NO sustituir tests: el blast-radius es un aviso, no una verificación.
- NO indexar proyectos ajenos al workspace (codegraph ya limita el scope).

---

## Diseno

### S1 — Consulta de blast-radius sobre codegraph

`scripts/blast-radius.sh --symbol <name> [--file <path>]`:
- consulta `codegraph` (callers/callees) para el símbolo,
- emite lista de ficheros afectados con profundidad (direct/transitive),
- salida JSON: `{symbol, direct: [...], transitive: [...], files: {...}}`.

### S2 — Modo diff (cambio propuesto)

`scripts/blast-radius.sh --diff <range>`:
- para cada símbolo nuevo/modificado en el diff, resuelve blast-radius,
- consolida en un reporte único con el conteo de ficheros afectados por
  cambio y el total del diff.

### S3 — Hook pre-write + integración commit-guardian

- Hook `pre-tool-use` (Edit/Write en ficheros de código) invoca blast-radius
  en modo ligero y muestra `AFFECTED: N files` como advertencia (no bloquea).
- `commit-guardian` añade check opcional: si el PR/diff toca un símbolo con
  blast-radius > umbral (config, default 10 ficheros), lo reporta al revisor.
- Telemetría SE-313: evento `blast.radius` con símbolo y nº de afectados.

---

## Criterios de aceptacion

### AC-S1: Consulta

- [ ] AC-S1.1: símbolo con 3 callers directos → `direct` los lista.
- [ ] AC-S1.2: símbolo con callers transitivos → `transitive` los lista con
  profundidad.
- [ ] AC-S1.3: símbolo inexistente → `{symbol: null, files: {}}`, exit 0.

### AC-S2: Diff

- [ ] AC-S2.1: diff que modifica 2 símbolos → reporte agrega ambos con sus
  afectados.
- [ ] AC-S2.2: diff sin símbolos detectables → reporte vacío, exit 0.

### AC-S3: Integración

- [ ] AC-S3.1: hook pre-write muestra advertencia AFFECTED sin bloquear.
- [ ] AC-S3.2: commit-guardian reporta cambios con blast-radius > umbral.
- [ ] AC-S3.3: `blast.radius` aparece en `output/telemetry-events.jsonl`.

---

## Ref

- `zzet/gortex` → `docs/features.md` (preview_edit, simulate_chain), `docs/lsp.md`
- `scripts/commit-guardian` (guard), `.opencode/skills/codegraph/SKILL.md`

## Implementación (2026-08-11)

- S1: `scripts/blast-radius.sh --symbol` — codegraph con fallback grep.
- S2: `scripts/blast-radius.sh --diff` — definiciones del diff + reporte.
- S3: hook `blast-radius-hook.sh` (opt-in `SAVIA_BLAST_RADIUS=on`) + check en
  commit-guardian + telemetría `blast.radius`.
- Job CI `Blast-radius (report-only)` + 9 tests BATS.
