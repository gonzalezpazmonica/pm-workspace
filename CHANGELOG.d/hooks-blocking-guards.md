---
version_bump: patch
section: Fixed
---

### Fixed

- Guards de seguridad PreToolUse (block-credential-leak, block-force-push, agent-git-discipline, block-infra-destructive, validate-bash-global) marcados blocking: true para el fail-closed de Savia Space en modo mediado (D23-5); data-sovereignty-gate excluido hasta acotar su latencia. Nuevo auditor scripts/hooks-blocking-audit.sh con política config/hooks-blocking-policy.txt.

