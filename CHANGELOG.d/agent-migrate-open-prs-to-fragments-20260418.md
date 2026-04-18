---
version_bump: patch
section: Fixed
---

### Fixed

- **\`.gitattributes\`**: añade \`CHANGELOG.md merge=union\` (built-in, sin config necesaria) y \`.scm/* merge=ours\` (requiere driver). Eliminates 3 de 4 tipos de conflictos recurrentes sin necesidad de tooling externo.
- **\`scripts/setup-merge-drivers.sh\`**: configura \`merge.ours.driver = true\` local. Sin esto, los \`merge=ours\` en .gitattributes eran silent no-ops — razón por la que los conflictos persistían pese a tener el attribute.
- **\`.claude/hooks/session-init.sh\`**: invoca setup-merge-drivers idempotentemente al arrancar sesión. Zero-config para usuarios — drivers quedan wired automáticamente en cualquier checkout fresco.
- **\`tests/test-merge-drivers.bats\`**: 23 tests incluyendo integración real de merge en sandbox git (union, ours, sin driver = conflict). Auditor score 82.

