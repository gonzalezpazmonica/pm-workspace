---
version_bump: patch
section: Added
---

### Added

- SE-357 Control Bands autónomas: `control-band-detect.sh` (detección determinista sin LLM, métricas locales con threshold configurable) + `control-band-agent.sh` (tiers σ: 1σ log, 2σ diagnose read-only, 3σ propose con intent.md). Config `control-bands.yaml` versionada; historial append-only local; `intent/` como re-entrada al pipeline. 12 bats tests.
