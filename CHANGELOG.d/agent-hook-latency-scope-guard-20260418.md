---
version_bump: patch
section: Fixed
---

### Fixed

- **\`.claude/hooks/scope-guard.sh\`**: optimizado de 203ms → 48ms. Restringe find a 3 paths conocidos (projects/, docs/specs/, docs/propuestas/) + maxdepth 6 + prune de node_modules/.git/build/dist/target. Elimina el timeout SLA 200ms que bloqueaba PRs en CI Hook Latency Gate.

