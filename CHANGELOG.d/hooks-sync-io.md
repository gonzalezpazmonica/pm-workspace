---
version_bump: patch
section: Fixed
---

### Fixed

- Hooks de arranque sin esperas de red: session-init y shield-autostart sondean Ollama y Shield en segundo plano (estado para el siguiente arranque) y ya no retienen stdout con tareas de fondo; pr-summary-gate acota la revisión LLM a 3 s de conexión y PR_SUMMARY_LLM_TIMEOUT (30 s) y deja de usar un fichero compartido en /tmp.

