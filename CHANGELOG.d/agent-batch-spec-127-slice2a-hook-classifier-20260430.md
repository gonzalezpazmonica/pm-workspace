---
version_bump: minor
section: Added
---

### Added

#### SPEC-127 Slice 2a IMPLEMENTED — Hook portability classifier + full 64-hook classification

- `scripts/hook-portability-classifier.sh` — clasifica deterministically cada hook de `.claude/hooks/*.sh` en uno de 4 tiers de portabilidad bajo cualquier frontend × cualquier provider:
  - **TIER-1 portable**: equivalente directo en OpenCode plugin TS (`tool.execute.before|after`). 23 hooks identificados (real-time enforcement preserved).
  - **TIER-2 git-pre-commit**: reroute a `.husky/pre-commit` o equivalente. 22 hooks (catches committed changes, no in-flight edits).
  - **TIER-3 ci-only**: too heavy para real-time; reroute a CI (GitHub Actions / GitLab CI / Jenkins / etc.). 0 hooks actualmente — Slice 2b puede tighter classification con timing data.
  - **TIER-4 lost**: depend de eventos no expuestos por otros frontends (Task tool, SubagentStart, session-lifecycle como Stop/SessionEnd/CwdChanged/PreCompact). 15 hooks — declare loss explícita per PV-05.
  - **LIB**: 4 hooks no registrados en settings.json — internal helpers, out of scope.
  - 4 modos: TSV (default), `--summary`, `--json`, `--markdown`. Idempotent.
  - Heurística agnostic — no menciona vendors comerciales. Branches en eventos/matchers (PreToolUse + Bash/Edit/Write matcher → TIER-1; Stop/SessionEnd → TIER-4; PreToolUse + file_path → TIER-2 git-pre-commit; PreToolUse + Task matcher → TIER-4).
- `output/hook-portability-classification.md` — reporte auto-generado (103 líneas). Estructura:
  - Tier definitions
  - Summary aggregate counts
  - Per-hook table (64 rows): hook | events | tier | reason | reroute target
  - Safety-critical coverage check (PV-02): los 3 hooks críticos (`block-credential-leak`, `block-gitignored-references`, `prompt-injection-guard`) verificados como TIER-1.

#### Tests de regresión

- `tests/structure/test-spec-127-slice2a-hook-classifier.bats` — 31 tests certified. Estructura por AC:
  - **AC-2.1 ×8**: classifier exists/executable/syntax + TSV/summary/JSON modes + processes all hooks + every row has tier
  - **AC-2.3 ×3**: 3 safety-critical hooks en TIER-1 o TIER-2 (PV-02 enforcement)
  - **AC-2.2 partial ×1**: ≥5 hooks TIER-1 (cumplido — 23)
  - **AC-2.4 ×6**: report exists + Tier definitions section + Summary section + Per-hook table + Safety-critical section + SPEC-127 reference
  - **PV-06 ×2**: classifier nunca menciona vendors hardcoded + report content tampoco
  - **Negative + edge ×4**: unknown flag → exit 2, missing hooks dir → exit 3, empty hooks dir → 0 rows, LIB hooks reported
  - **Markdown idempotency ×1**: --markdown twice produces same content
  - **Spec ref ×3**: AC-2.1/2.3/2.4 declared in spec + ref in test + classifier references SPEC-127
  - **Coverage ×3**: 4 modes defined + matcher reading from settings.json + 4 tiers + LIB

### Why this matters

Sin classifier, decidir cómo migrar 64 hooks a un nuevo stack es un análisis manual de horas. El classifier produce el mapa en segundos: 23 hooks portables vía plugin TS, 22 vía git pre-commit, 15 perdidos sin equivalente, 4 internals out-of-scope. El reporte es la base para Slice 2b (TS plugin top 5-10) y Slice 4 (single-shot fallback para los TIER-4 que dependen de Task tool). Los 3 hooks safety-critical ya están en TIER-1 — PV-02 cumplido sin trabajo adicional.

### Hard safety boundaries

- **PV-01 Backward compat absoluto**: cero modificación de los 64 hooks existentes. Solo análisis + clasificación + reporte.
- **PV-02 Safety layer crítica**: los 3 safety-critical hooks verificados TIER-1 — cobertura preservada.
- **PV-05 Visibilidad de pérdidas**: 15 hooks TIER-4 listados explícitamente con la razón. La pérdida no es silenciosa.
- **PV-06 No vendor lock-in**: classifier branches en capability events (PreToolUse, Stop, ...) y matchers (Bash, Edit, Write, Task), nunca en vendor names. BATS test enforce.
- Cero red, cero git operations en runtime, cero merge autónomo.
- Cumple `docs/rules/domain/autonomous-safety.md`: rama `agent/spec-127-slice2a-hook-classifier-20260430`, sin merge autónomo.

### Spec ref

SPEC-127 (`docs/propuestas/SPEC-127-savia-opencode-provider-agnostic.md`) → Slice 2a IMPLEMENTED 2026-04-30. AC-2.1, AC-2.3, AC-2.4 cumplidos. AC-2.2 (≥5 hooks portados a TS plugin con tests) PENDING para Slice 2b — el classifier ya identifica los 23 candidatos elegibles; Slice 2b construye el plugin con los top 5-10 reales.
