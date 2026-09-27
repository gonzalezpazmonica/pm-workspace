---
bump: patch
section: Fixed
---

- `savia-env.sh` contenía dos copias concatenadas de sí mismo; queda una (mismo comportamiento verificado).
- `llm-router.py` devuelve tiers canónicos (heavy|mid|fast) y aplica `--thresholds`, que antes se ignoraba.
- `subagent-dispatch-gate` acepta los alias nativos de Claude Code (opus/sonnet/haiku); cada dispatch registraba un fallo falso en la telemetría SE-313.
