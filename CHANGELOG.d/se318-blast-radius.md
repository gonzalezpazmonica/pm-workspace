---
version_bump: minor
section: Added
---

### Added

- SE-318 Blast-radius pre-commit — consulta de impacto antes de escribir:
  - `scripts/blast-radius.sh --symbol <name>`: lista callers y ficheros
    dependientes de un símbolo antes de modificarlo. Backend preferido
    `codegraph` (índice AST); fallback grep determinista sobre ficheros de
    código. Salida JSON `{symbol, direct[], transitive[], files{}, total}`.
    Símbolo inexistente → `{symbol:null, files:{}}`, exit 0 (AC-S1).
  - `scripts/blast-radius.sh --diff <base..head>`: extrae definiciones nuevas/
    modificadas del diff y consolida su blast-radius en un reporte único con
    conteo de ficheros afectados. Diff sin símbolos → reporte vacío (AC-S2).
  - Hook `blast-radius-hook.sh` (PreToolUse Edit|Write, switch
    `SAVIA_BLAST_RADIUS=on`, Rule #19): avisa `AFFECTED: N fichero(s)` sin
    bloquear (AC-S3.1). Registrado en `.claude/settings.json`.
  - Check opcional en `commit-guardian`: si el diff toca >10 ficheros
    dependientes (`BLAST_RADIUS_THRESHOLD`), lo reporta al revisor. Nunca
    bloquea (AC-S3.2).
  - Telemetría SE-313: evento `blast.radius` con símbolo y nº de afectados
    (AC-S3.3).
  - Job CI `Blast-radius (report-only)` con `continue-on-error: true`.
  - 9 tests BATS (`tests/test-blast-radius.bats`): AC-S1, AC-S2, AC-S3 +
    zero-secrets.

### Notes

- La heurística grep filtra definiciones/imports/comentarios para evitar
  falsos positivos; no distingue definiciones de bash (`name()`) de callers,
  por lo que la definición puede contar como dependiente si hay más de una
  mención. Calibrar con codegraph (backend semántico) en proyectos indexados.
- El hook y el job son opt-in/report-only por diseño (SE-318 S3): el
  blast-radius es un aviso, no un gate de seguridad.

### Fixed

- `scripts/blast-radius.sh` concilia dos interfaces: la file-based de SE-260
  (`<file>`, `--depth`, `--format`, `--project`) y la symbol/diff de SE-318
  (`--symbol`, `--diff`, `--list-backends`). El dispatch se decide por el
  primer argumento. Ambas suites de tests pasan (10 SE-260 + 9 SE-318).
- `docs/hooks-coverage-matrix.md` regenerado (SE-253) para incluir
  `blast-radius-hook.sh`.
