# SPEC-SE-012 — Signal/Noise Reduction: Hooks y CI Reliability

> **Prioridad:** P0 · **Estima:** 1 día · **Tipo:** plataforma + observabilidad

## Objetivo

Reducir el ruido crónico que degrada la eficiencia de Savia al operar sobre
pm-workspace, en dos frentes medibles:

1. **Falsos positivos de hooks PreToolUse:Bash** que saturan la pantalla y
   bloquean comandos legítimos (merge commits, análisis con `git merge-tree`,
   flags de git no-commit).
2. **Tasa de fallo de pipelines CI** sin trazabilidad: los PRs fallan
   repetidamente por las mismas causas (p.ej. ficheros ausentes en git por
   ser directorios vacíos) sin un mecanismo de detección local previo al push.

## Principios afectados

- #3 Honestidad radical (medir fallos reales, no ocultarlos)
- #5 El humano decide (hooks no deben bloquear por falsos positivos)

## Diagnóstico

### Frente 1 — Hooks ruidosos

`.claude/settings.json:168-180` define un hook tipo `prompt` con modelo Haiku
que evalúa cada commit vía LLM. Dos bugs concretos:

- **Matcher permisivo:** `if: "Bash(git commit*)"` dispara sobre `git merge-tree`
  (que contiene la subcadena `git` pero no es un commit). El LLM reconoce que
  no es un commit y devuelve `{ok: false}`, pero eso bloquea el comando en
  lugar de pasarlo.
- **Prompt sin contexto de subcomando:** critica `--no-edit` en merge commits,
  donde es el comportamiento estándar (usar el mensaje auto-generado).

Coexiste con `prompt-hook-commit.sh` (tipo `command`, modo `warning`), que ya
valida commits de forma determinista con checks específicos:
- `fix:` vs solo additions
- `add/feat:` vs solo deletions
- Longitud mínima
- Primera línea ≤72 chars
- Links de CHANGELOG

El hook determinista hace mejor trabajo sin coste de tokens y sin falsos
positivos. El hook LLM es redundante y ruidoso.

### Frente 2 — CI sin feedback loop

BATS Hook Tests falla en el primer push del PR #517 y #518 por 5 tests
(`test-validate-layer-contract.bats` 11-14, 19). Causa: `.claude/enterprise/
{agents,commands,rules,skills}` son directorios vacíos que git no trackea, así
que CI ve los subdirs ausentes y los tests del contrato de capas fallan.

Local los mismos tests pasan (porque las carpetas existen en el workspace del
desarrollador). No hay hook pre-push que ejecute el subset de tests que se
rompen en CI. Resultado: un ciclo de push → esperar CI → leer logs → fix →
re-firmar → re-push, multiplicado por cada rama en paralelo.

No existe métrica de tasa de fallo de pipelines. No sabemos si este patrón
es sistémico o aislado.

## Diseño

### Módulo 1 — Deshabilitar hook LLM redundante

Eliminar el bloque `{"type": "prompt", ...}` de `.claude/settings.json:168-180`.
Mantener `prompt-hook-commit.sh` como único validador semántico de commits.

**Rationale:** el hook determinista ya cubre los casos reales y está en modo
`warning` por defecto (no bloquea). El hook LLM tiene 0 valor añadido y
genera regresiones de UX.

**Reversibilidad:** trivial — es una eliminación de 13 líneas en settings.json,
el hook LLM queda comentado en histórico git si se quiere reactivar con
mejor prompt.

### Módulo 2 — CI Failure Tracker

Script nuevo: `scripts/ci-failure-tracker.sh`

```
ci-failure-tracker.sh record <pr-number>
  → Lee `gh pr view {pr} --json statusCheckRollup`
  → Para cada check FAILURE, append a output/ci-runs.jsonl:
     {"ts":"...","pr":N,"workflow":"CI","check":"BATS Hook Tests",
      "run_id":"...","conclusion":"FAILURE","job_url":"..."}

ci-failure-tracker.sh health [--days 30]
  → Agrega output/ci-runs.jsonl
  → Reporta tasa de fallo por workflow y por check
  → Top-5 causas recurrentes
```

Comando slash: `/ci-health` — invoca `ci-failure-tracker.sh health` y renderiza
tabla con banner UX estándar.

### Módulo 3 — Pre-push guard que ejecuta los BATS críticos

Hook `scripts/pre-push-bats-critical.sh` (manual, no automático):

- Detecta ficheros modificados en el push que tocan `.claude/hooks/` o
  `scripts/` relevantes.
- Ejecuta únicamente los `.bats` relacionados.
- Si falla → aborta el push con mensaje accionable.

Se integra en `/pr-plan` como Gate G12 (opcional, configurable).

**No** se hace hook git automático: el usuario ya usa `/pr-plan` antes de cada
push por Rule #25. Añadir un gate más en ese flujo es el mínimo coste.

## Criterios de aceptación

1. Eliminado el hook tipo `prompt` de `.claude/settings.json`. `git commit`
   legítimos no reciben el banner "PreToolUse:Bash hook error" del LLM.
2. `git merge-tree`, `git log`, `git diff` no disparan validación de commit.
3. `scripts/ci-failure-tracker.sh record 517` captura el fallo de BATS Hook
   Tests en `output/ci-runs.jsonl`.
4. `/ci-health` lista tasa de fallo por workflow con al menos 1 fila real.
5. Tests BATS de este spec (`tests/test-ci-failure-tracker.bats`) ≥ 10 tests,
   todos PASS.
6. CHANGELOG actualizado con entrada SE-012.

## Tests

- `tests/test-ci-failure-tracker.bats`
  - record append correctly
  - health computes rates correctly
  - handles empty log
  - handles malformed JSON gracefully
  - filter by days
- Validación manual: reproducir `git merge-tree` en sesión con settings.json
  actualizado → no dispara el hook.

## Fuera de scope

- Refactor completo de hooks (lo cubre SE-009 Observability).
- Métricas de CI para workflows GitHub no-propios.
- Dashboard web (solo CLI).

## Dependencias

- Ninguna. SE-012 es independiente del resto del plan enterprise y se puede
  mergear antes que SE-002..011.

## Notas de implementación

- El hook tipo `prompt` existe también en worktrees (`.claude/worktrees/.../
  settings.json`). Son copias — no tocar, se regeneran.
- Al escribir `ci-failure-tracker.sh` usar `set -uo pipefail` y `jq` para
  parsear la salida de `gh`.
- `output/ci-runs.jsonl` es append-only y va en `.gitignore` (datos de uso
  local, nivel N3).
