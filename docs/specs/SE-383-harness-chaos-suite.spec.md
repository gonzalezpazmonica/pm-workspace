# SE-383 — Harness Adversarial / Chaos Suite (hooks y gates)

**Estado:** PROPOSED (pendiente de aprobación humana — Fase E, audit GPT-5.6 2026-09-05)
**Prioridad:** P1 · **Developer Type:** agent-team · **Context Risk:** medium
**Origen:** auditoría externa §14 (PARTIALLY_ALREADY_SOLVED)

## 1. Motivación

Los hooks son la capa enforcement real del workspace: 124 registros, 51 de ellos en PreToolUse (blast radius máximo). Existen 530 ficheros `.bats` + CI "BATS Hook Tests", pero no una suite sistemática de perturbaciones. Incidente real de esta sesión (2026-09-05): el hook `savia-gates` de branch-switch resultó **worktree-unaware** — bloqueó commits legítimos en un worktree aislado leyendo la rama del repo principal (exactamente el tipo de fallo cwd/repo-context que predice el audit, F7).

## 2. Alcance

Suite de caos para hooks y gates L3/L4 (según registry SE-375), ejecutada en sandbox hermético: temp dirs, sin red, seed reproducible, **cero escrituras al repo real**.

### Matriz de perturbaciones mínima (§14.2 del audit)

cwd equivocado · repo diferente · worktree · symlink · paths con espacios · path inexistente · variable sin expandir · nested shell · command substitution · `git -C` · `cd &&` · timeout · dependencia ausente · JSON parcial · JSON corrupto · stdout extra · stderr extra · exit code inesperado · hook async · session abort · branch protection · frontend diferente · ejecución concurrente · dirty workspace · dirty external repo.

## 3. Regla de incidentes

Todo bug real de hook/gate: (1) fixture que lo reproduce → (2) test rojo → (3) fix → (4) test verde. Sin fixture no hay fix, salvo emergencia declarada por la operadora. Fallos de la suite generan fingerprint consumible por el flujo RCA existente (evals RCA, gate G18).

## 4. Criterios de aceptación

- Suite en CI, determinista (seed fija), sin red, fixtures mínimos por perturbación.
- Hooks L3/L4 con la suite como requisito de merge.
- El incidente worktree-unaware de savia-gates queda capturado como fixture fundador.
- Fingerprints integrados al pipeline RCA.

## 5. OpenCode Implementation Plan

PENDING-APPROVAL — completar al aprobar. Depende de SE-375 (inventario de riesgo por hook).

## Referencias

- Auditoría externa §14 · `tests/bats/` · `bats-audit-sweep.yml` · `run-adversarial-evals.sh` · incidente savia-gates 2026-09-05
