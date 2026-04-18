---
version_bump: minor
section: Fixed
---

### Fixed

- **\`.github/workflows/auto-rebase-open-prs.yml\`**: nuevo workflow que rebased automáticamente PRs abiertos tras cada push a main. Resuelve el problema raíz: \`merge.ours.driver\` en .gitattributes solo funciona local, no en GitHub server-side merge. El workflow ejecuta \`resolve-pr-conflicts.sh\` desde runner GHA (donde sí puede configurar el driver). Elimina la fricción "mergear un PR genera conflicto en todos los demás" — ahora Monica mergea y el auto-rebase resuelve los PRs en cola sin intervención.

