---
version_bump: patch
section: Fixed
---

### Fixed

- Shield TUI overlap: hooks PreToolUse que bloquean (data-sovereignty-gate.sh) ahora emiten la decision como JSON hookSpecificOutput.permissionDecision=deny en stdout con exit 0, en vez de stderr+exit 2. OpenCode v1.14 TUI concatenaba stderr al frame de render causando overlap visual. Corolario de SHIELD-AUDIT-STDOUT-01. Anade leccion SHIELD-GATE-STDOUT-01.

