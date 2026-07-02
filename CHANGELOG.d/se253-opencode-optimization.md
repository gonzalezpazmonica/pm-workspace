---
spec: SE-253
---

## SE-253 — Optimización OpenCode: coste de contexto, fan-out de hooks y deuda estructural

### Slice 1 — Catálogo de comandos core/extended

287 comandos `core` + 271 `extended` (48.6% reducción de índice por sesión).
Campo `tier: core|extended` en frontmatter de los 558 comandos.
Nuevo comando `/catalog [keyword]` para explorar extended bajo demanda.
`scripts/command-tier-audit.sh` con modos `--classify`, `--check`, `--stats`.
25 BATS tests, AC-1.1 a AC-1.5.

### Slice 2 — Matriz real de cobertura de hooks en OpenCode

`docs/hooks-coverage-matrix.md` — 103 hooks clasificados por cobertura TS/git/CI/NONE.
`scripts/hooks-coverage-matrix.sh --check` en CI.
Cobertura real: 17 guards TS (16.5%) + 9 mitigados (4 git + 5 CI) = 25% efectivo.
21 bloqueantes sin TS guard tienen degradación documentada (eventos no disponibles en OpenCode).
HOOKS-STRATEGY.md corregido: eliminada cifra "~80%" fósil, enlace a matriz real.
17 BATS tests, AC-2.1 a AC-2.4.

### Slice 3 — Guard de sync de agentes en CI

`scripts/agents-catalog-sync.sh --check` en CI job `agent-sync-check`.
`docs/agents-sync-allowlist.md` — 22 agentes single-side documentados (7 top-level + 10 decision-trees + 5 references).
0 divergencias estructurales entre .claude/agents y .opencode/agents.
19 BATS tests, AC-3.1 a AC-3.4.

### Slice 4 — Dispatcher único por evento

`hooks/routing-pretooluse.tsv` (45 entradas) + `routing-posttooluse.tsv` (30 entradas).
`.opencode/hooks/dispatch-pretooluse.sh` + `dispatch-posttooluse.sh`.
Reducción spawns bash por Edit: 75 → 2 (97%). settings.json NO modificado — integración manual requerida.
`scripts/benchmark-hook-dispatch.sh` — harness de medición.
21 BATS tests, AC-4.1 a AC-4.5.

### Slice 5 — Higiene de registros

8 matchers vacíos en PostToolUse resueltos con matcher + comentario justificativo.
`recommendation-tribunal-pre-output.sh` movido a `.claude/hooks/_legacy/` (evento PreOutput no disponible).
`recommendation-tribunal-followup.sh` y `twin-posttooluse.sh` registrados explícitamente.
`scripts/doc-counts-check.sh` en CI — compara counts declarados vs disco.
HOOKS-STRATEGY.md: "69 hooks" → "101 hooks".
12 BATS tests, AC-5.1 a AC-5.4.

### Slice 6 — Archivo de specs y trazabilidad spec→código

`docs/specs-archive/` — estructura creada con README.md que documenta gap SE-143→SE-252.
14 specs del backfill archivados en `docs/specs-archive/2026/`.
`scripts/changelog-spec-field-check.sh` — warning en CI para feat(seNNN) sin campo `spec:`.
14 BATS tests, AC-6.1 a AC-6.5.

### Slice 7 — Language-boundaries rule + migración test-workspace.sh

`docs/rules/domain/language-boundaries.md` — heurística: >=5 jq o >300 líneas → Python.
`scripts/test-workspace.sh` (860 líneas) → wrapper 7 líneas delegando a `test_workspace.py`.
`scripts/test_workspace.py` (887 líneas) — migración completa de las 9 suites de validación.
`scripts/language-boundary-check.sh` — warning pre-commit para scripts nuevos con >=5 jq.
22 pytest + 25 BATS tests, AC-7.1 a AC-7.5.

### Total SE-253

- 563 ficheros modificados
- 7 scripts nuevos + 1 migración Python
- 7 ficheros de infraestructura (TSV, dispatchers, _legacy)
- 7 suites BATS (128 tests) + 22 pytest
- Ahorro estimado: 48.6% reducción índice sesión, 97% reducción spawns por Edit
