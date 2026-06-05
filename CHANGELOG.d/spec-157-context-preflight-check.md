---
version_bump: patch
section: Added
---

### Added

- SPEC-157: Context Pre-Flight Check — multi-source token estimator + PreToolUse hook. Detects @-import file refs, skill refs, prompt tokens; warns at 80%, blocks at 100% of agent budget; caches by input hash; suggests context-rot-strategy + context-task-classifier. 29 tests certified 81/100.

