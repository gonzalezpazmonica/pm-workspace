---
version_bump: patch
section: Fixed
---

### Fixed

- **\`scripts/resolve-pr-conflicts.sh\`**: bugfix — cuando \`git merge origin/main\` tenía éxito SIN conflictos pero CON cambios (merge commit nuevo), el script reportaba "already in sync" y exit 0 sin pushear. Ahora detecta via \`rev-parse HEAD\` pre/post si hubo merge real y pushea. Resuelve el caso en que los PRs quedaban CONFLICTING en GitHub pese a que \`resolve-all-open-prs.sh\` reportaba "resolved".

