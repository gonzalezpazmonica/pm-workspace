---
version_bump: minor
section: Added
---
- SE-405: `savia-runs.sh cost` y hook `SubagentStop` (`runs-cost-capture`) registran tokens/USD por subagente en cada run autónomo, visibles en `show` y `status --json`; `scripts/config-snapshot.sh` + hook PreToolUse guardan copia de `.claude/settings.json`, `settings.local.json`, `opencode.json` y `~/.savia/preferences.yaml` antes de cada edición (restore con `--confirm`, 30 por fichero); `memory-store.sh timeline <topic_key|hash>` muestra las entradas de memoria antes y después de una dada.
