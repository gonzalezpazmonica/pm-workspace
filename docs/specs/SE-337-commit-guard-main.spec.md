# SE-337 — Guard de commit en ramas humanas (bloquear `git commit` en main/master)

**Status:** APPROVED (operadora, 2026-08-22) → IMPLEMENTED 2026-08-22
**Fecha:** 2026-08-22
**Area:** Seguridad / Orquestación / Hooks
**Origen:** lección recurrente — 2 commits hechos en `main` por error en la sesión del 2026-08-22 (SCL-012, SCL-status). LP-20260822-71bb75c5.
**Developer Type:** agent-single
**Context risk:** low
**Estimación:** ~3h

---

## 1. Problema y objetivo

La regla `autonomous-safety.md` dice textualmente: **NUNCA hacer commit en la
rama de un humano (main, develop, feature/* de humano)**. Es una regla de
alineación crítica (CRIT-031 espejo de proceso). Pero no hay guard mecánico: la
única defensa es la atención del agente, que **falló 2 veces en la misma
sesión** (commits `f9c8bd11` SCL-012 y `90d91884` SCL-status hechos en `main`,
luego corregidos con rama + `reset --soft`).

**Objetivo**: un hook runtime PreToolUse que bloquee `git commit`, `git commit
-a` y `git commit --amend` cuando la rama actual sea `main` o `master`. El
bloqueo es desbloqueable SOLO con señal explícita de la operadora (env
`SAVIA_ALLOW_MAIN_COMMIT=1` con confirmación, estilo `--human-trailer`).

## 2. Contratos

### 2.1 `scripts/block-commit-to-main.sh`

```text
PreToolUse Bash(git commit*) — blocam si git branch --show-current ∈ {main, master}
  SALIDA en bloqueo:
    {"decision":"block","reason":"commit en rama humana (main) — prohibido por autonomous-safety. Crea rama agent/*"}
  Exit 0 con stdout JSON (patrón Claude Code block) o exit 1 si no JSON.
  Bypass consciente: SAVIA_ALLOW_MAIN_COMMIT=1 → permite (con registro en output/turn-sdlc/commit-guard.jsonl), SOLO uso humano explícito.
```

### 2.2 Registro
Cada bloqueo y bypass se anota en `output/turn-sdlc/commit-guard.jsonl`
`{ts, branch, action, block|bypass, hash}`. El log alimenta el reporte
Turn-SDLC (SE-336 S4) — visibiliza si el problema recurre.

## 3. Reglas de negocio

| ID | Regla | Incumplimiento |
|---|---|---|
| RN-01 | `main`/`master` → block siempre, salvo `SAVIA_ALLOW_MAIN_COMMIT=1` | Test |
| RN-02 | Rama `agent/*` → pass (no interfiere el flujo normal) | Test |
| RN-03 | `git checkout main`/`switch` NO se bloquea (solo commit); el cambio de rama está cubierto por block-branch-switch-dirty | Test |
| RN-04 | Bypass registrado en JSONL (no silencioso) | Test |
| RN-05 | No toca CRITERIO/CONSTITUCION; sin red; PURE_BASH | Test |

## 4. Criterios de aceptación

- [x] AC-01: estando en rama `main`, `git commit` → bloqueado (stdout JSON block).
- [x] AC-02: en rama `agent/foo`, `git commit` → pass (exit 0 sin JSON).
- [x] AC-03: `SAVIA_ALLOW_MAIN_COMMIT=1` en main → permite y registra bypass.
- [x] AC-04: bloqueo y bypass escritos en `output/turn-sdlc/commit-guard.jsonl`.
- [x] AC-05: suite BATS >= 6 verdes; hashes CRITERIO/CONSTITUCION invariantes.

## 5. Ficheros

**Crear**: `scripts/block-commit-to-main.sh` · `tests/test-se337-commit-guard.bats`

**Modificar**: `.claude/settings.json` (registro en PreToolUse `Bash(git commit*)`).

**No tocar**: CRITERIO/CONSTITUCION, plugins TS.

## 6. Riesgos

- **Falso bloqueo a usuarios humanos**: bypass explícito documentado; el humano
  puede commitear en main con `SAVIA_ALLOW_MAIN_COMMIT=1` (su elección).
- **Amend/merge**: el hook matchea `git commit*`; `git commit --amend` queda
  cubierto, `git merge` entra a main solo via PR (no bloqueado aquí).
- Rollback: quitar el registro de settings.json + eliminar script.

## 7. Referencias

- LP-20260822-71bb75c5 (la lección recurrente que mecaniza).
- `autonomous-safety.md` (regla NUNCA commit en rama humana).
- SE-336 (Turn-SDLC, reporte consume commit-guard.jsonl).
- Precedente: `block-force-push.sh`, `block-branch-switch-dirty.sh`.