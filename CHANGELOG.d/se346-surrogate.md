---
version_bump: minor
section: Added
---

### Added (SE-346 Slice 1 — surrogate model + incertidumbre)

- `scripts/surrogate/` — librería de modelo sustituto (GP) + active learning
  local y determinista (CRIT-001, sin red): `gp_surrogate.py`, `acquisition.py`
  (ucb/ei/pi/variance), `orchestrator.py`, `sampling.py` (LHS), `storage.py`.
- `scripts/surrogate/llm-router.py --check` — routing de modelo LLM por
  incertidumbre (read-only): para cada tipo de tarea decide FAST/MID/AGENT por
  std del GP; telemetría en `output/surrogate-telemetry.jsonl`.
- `scripts/surrogate/router-check.sh` — wrapper.
- `tests/test-surrogate.bats` (10 tests) + `tests/eval-surrogate-benchmark.py`
  (Branin: ≥40% menos evaluaciones y ≥85% calibrado — PASS verificado).
- Regla `docs/rules/domain/surrogate-router.md` (umbrales + procedimiento de
  calibración).

### Added (SE-264 spec · SE-266 closure)

- Spec `docs/specs/SE-264-memory-auto-consolidation.spec.md` (PROPOSED):
  `memory-store.sh consolidate` — dedup por topic_key, strip test/bench, stale
  flag/archive; pipeline roadmap #29.
- `docs/specs/SE-266-agent-governance.spec.md` → **IMPLEMENTED** (verificado
  2026-08-27: hook + 30 tests + disciplina en docs/AGENTS.md).
