---
bump: patch
section: Fixed
---

- Aislamiento de tests: 16 suites dejaban de escribir en ficheros versionados, en el ledger de `~/.savia` o en los logs vivos de `output/`. `pr-rebase.sh` opera sobre el repo del directorio actual (un test hacía commit y push de la rama activa). Se resincronizan `.github/hooks/savia.json` y `docs/RESOLVER.md`, el INDEX de propuestas deja de reescribirse solo por la marca de tiempo, los twins usan rutas relativas y se versiona la política `config/source-authority.yaml`.
