---
version_bump: patch
section: Fixed
---

### Fixed

- sovereignty-auditor (D2): emergency-setup.sh fija credencial placeholder para Ollama, descarga todos los modelos de los alias, exige Ollama >= 0.20.0, redondea la RAM al GB y falla con exit 1/2 en vez de declarar setup completado; emergency-status.sh sale con 1 si hay problemas y ya no dice listo sin comprobar modelos, versión, base URL /v1 ni ANTHROPIC_AUTH_TOKEN

