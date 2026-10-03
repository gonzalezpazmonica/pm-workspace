---
version_bump: patch
section: Fixed
---

### Fixed

- savia-hub-sync calibrada: init deja la config local fuera de git al clonar, siembra remotes vacíos, respeta SAVIA_HUB_REMOTE y crea la rama main; nuevo savia-hub-sync.sh (status/push/pull/flight) con exit codes, sin decir «sincronizado» sin remote o sin red y abortando el rebase ante conflictos.

