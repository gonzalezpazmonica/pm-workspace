---
version_bump: patch
section: Security
---

### Security

- **Guard de commit-a-main activo en el runtime OpenCode (SE-337)**:
  - Nuevo guard TS `block-commit-to-main.ts` conectado al router
    `savia-foundation.ts` (`tool.execute.before`): bloquea `git commit`
    cuando la rama actual es `main`/`master`, mecanizando la regla
    autonomous-safety "NUNCA commit en ramas de humanos".
  - Detección real de rama vía `git branch --show-current` (subprocess
    read-only, ~5-10ms); bypass consciente `SAVIA_ALLOW_MAIN_COMMIT=1`
    con registro en `output/turn-sdlc/commit-guard.jsonl` (no silencioso).
  - 7 tests bun (bloquea en main/master, bloquea `--amend`, bypass
    registrado, permite agent/*, feature/*, y no interfiere en comandos
    no-commit). 23 tests de guards existentes siguen verdes.

### Fixed

- **Diagnóstico de por qué el hook bash no activó (documentado en el PR)**:
  el guard shell `block-commit-to-main.sh` estaba registrado en
  `.claude/settings.json` (PreToolUse/Bash) pero el plugin `savia-gates`
  que debería ejecutar los hooks del settings.json en OpenCode **no tiene
  manifest generado** (no se está cargando en el snap). El guard TS
  conectado a `savia-foundation` es la capa activa; la reinstalación/
  activación de `savia-gates` queda documentada como pendiente de
  investigación (no se afirma arreglado lo que no está).