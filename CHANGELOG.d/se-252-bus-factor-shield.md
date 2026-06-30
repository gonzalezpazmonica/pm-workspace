# SE-252 — Bus Factor Shield

**Date:** 2026-06-30
**Spec:** SE-252
**PR:** #892 (pending)

## Added

### Scripts (5)
- `scripts/bus-factor-scan.py` — motor CST(change-size-ratio); análisis de ownership por archivo via git blame + log
- `scripts/bus-factor-scan.sh` — orquestador bash; output JSON con BF por módulo y riesgo CRITICAL/HIGH/MEDIUM/LOW
- `scripts/context-dome-generate.sh` — genera CONTEXT_DOME.md por módulo: propósito, decisiones, runbook, owners
- `scripts/bus-factor-distribute.sh` — plan de knowledge transfer ordenado por riesgo para un developer objetivo
- `scripts/bus-factor-report.sh` — informe ejecutivo markdown + JSON

### Skills (2 + 2 DOMAIN.md)
- `.claude/skills/bus-factor-analysis/` — skill para análisis de bus factor en proyectos
- `.claude/skills/context-dome/` — skill para generación de cúpulas de contexto

### Hook
- `.claude/hooks/bus-factor-warn.sh` — PostToolUse warn-only; avisa si se modifica archivo con BF=1

### Regla de dominio
- `docs/rules/domain/bus-factor-protocol.md` — cuándo ejecutar, umbrales, protocolo de acción ante BF=1

### Spec
- `docs/propuestas/SE-252-bus-factor-shield.md` — spec completa con algoritmo CST, CAs, edge cases, limitaciones

### Tests
- `tests/test-se252-bus-factor-scan.bats` — 34 tests
- `tests/test-se252-context-dome.bats` — 22 tests
- `tests/test-se252-distribute.bats` — 17 tests
- `tests/test-se252-hook.bats` — 20 tests
- **Total: 93 tests BATS, 93/93 pasan**

## Context

Motivado por el artículo de Microsiervos (29-Jun-2026) sobre el factor autobús y el análisis de
Avelino et al. (ICPC 2016): el 65% de proyectos OSS tienen BF ≤ 2. El sistema implementa el
algoritmo CST(change-size-ratio) de Cosentino et al. (SANER 2015) sin dependencias externas.
