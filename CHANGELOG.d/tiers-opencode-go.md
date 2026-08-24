---
version_bump: patch
section: Changed
---

### Changed

- **Tiers de modelos migrados a opencode-go** (decisión de la operadora
  2026-08-24):
  - `heavy` -> `opencode-go/glm-5.3` (agentes de juicio: code-reviewer,
    architect, security-guardian, business-analyst, judges).
  - `mid` -> `opencode-go/deepseek-v4-flash` (desarrolladores, test, etc.).
  - `fast` -> `opencode-go/deepseek-v4-flash` (explore/read-only; decisión
    inicial, editable según catálogo).
  - Default Savia (build/plan) -> `opencode-go/deepseek-v4-flash`.
  - Fuente de verdad: `~/.savia/preferences.yaml` (`provider: opencode-go`);
    resuelto vía `scripts/sync-model-tiers.sh` en `.claude/agents`,
    `.claude/commands` y `.opencode/agents` (167 ficheros, 254 líneas
    cambiadas, solo campo `model`).
  - `opencode.json`: agentes con IDs explícitos (validación JSON OK).
  - 0 aliases `heavy|mid|fast` sin resolver en el workspace.