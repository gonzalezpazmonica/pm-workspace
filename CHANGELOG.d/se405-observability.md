---
version_bump: minor
section: Added
---
- SE-405: `savia-runs.sh cost` y hook `SubagentStop` (`savia-runs.sh capture-cost`) registran tokens/USD por subagente en cada run autónomo, visibles en `show` y `status --json`; `scripts/config-snapshot.sh` + hook PreToolUse guardan copia de `.claude/settings.json`, `settings.local.json`, `opencode.json` y `~/.savia/preferences.yaml` antes de cada edición (restore con `--confirm`, 30 por fichero); `memory-store.sh timeline <topic_key|hash>` muestra las entradas de memoria antes y después de una dada.
- SE-405 entropía neta 0: la captura de coste vive en `savia-runs.sh capture-cost` (no en un script aparte) y se retira `scripts/corporate/engagement-evidence-package.sh` (SE-271 PROPOSED, sin llamadores).
