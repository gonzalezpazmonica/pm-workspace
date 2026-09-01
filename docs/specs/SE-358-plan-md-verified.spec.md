# SE-358 — plan.md verificado: plan versionado + sync hook plan↔diff

**Status:** APPROVED (2026-08-31, operadora grant merge sesión nocturna)
**Fecha:** 2026-08-31
**Área:** SDD / Build / Review
**Fuente de inspiración:** Anthropic AI-Native SDLC Playbook (Stage 3 — Build, plan mode + plan.md; Stage 5 — review checkea diff contra plan.md)
**Criterio humano aplicable:** CRIT-001

---

## Objetivo

Introducir `plan.md` como artefacto versionado del pipeline SDD: el plan de
implementación (archivos que cambian, orden, riesgos, pruebas que lo demuestran)
se commitea junto al código, y un **sync hook** garantiza que el diff final no
diverja del plan sin una actualización explícita de `plan.md` en el mismo commit.

## Contexto

El playbook de Anthropic propone que el PR review "chequea el diff contra
plan.md" y que un hook enforce la sincronización plan↔diff. Verificado en Savia:
`spec-judge` y `correctness-judge` verifican contra la **spec** SDD, pero **no
existe un `plan.md`** — el plan de implementación del `dev-orchestrator` vive en
el turno, no como artefacto versionado. El gap: nadie puede auditar que el diff
final corresponde al plan aprobado, y las divergencias silenciosas (scope creep)
no se detectan.

**Rechazo explícito (CRIT-001):** todo local; el sync hook es bash sobre el repo
local, sin servicio externo.

## Diseño

### 1. `plan.md` (nuevo artefacto)

Formato (al estilo del playbook):

```markdown
# Plan: {título} (from {spec_id})

## Files that change
path/a.ts (new), path/b.py (modified), tests/test_b.py (new)

## Order of work
1. ...
2. ...

## Risks
...

## Proof
test_b.py cubre X; screenshot coincide con mock aprobado
```

### 2. Sync hook `plan-diff-check.sh` (PreToolUse/PostToolUse)

- Detecta commits que tocan archivos fuera de `plan.md`'s "Files that change"
- Si un archivo fuera del plan se modifica y `plan.md` no se actualizó en el
  mismo commit → WARN (mode warn) o BLOCK (mode block)
- Comando: `scripts/plan-diff-check.sh --plan plan.md --diff <files>` 

### 3. Integración con court

- `spec-judge` recibe `--plan plan.md` opcional: añade un pass "plan adherence"
  que reporta archivos del diff fuera del plan como finding de severidad
  configurable.

## Criterios de aceptación

- **AC-0** `plan.md` con formato válido (parser valida Files/Order/Risks/Proof)
- **AC-1** Hook detecta archivo modificado fuera del plan (exit warn)
- **AC-2** Hook pasa si archivo fuera del plan + plan.md actualizado en mismo commit
- **AC-3** `spec-judge --plan` reporta archivos divergentes como finding
- **AC-4** Parser tolera plan malformado (fail-soft, no bloquea)
- **AC-5** Sin regresión: suite de spec-judge existente verde

## OpenCode Implementation Plan

### Bindings touched
- `scripts/plan-diff-check.sh` (nuevo), `scripts/plan-validate.py` (nuevo)
- `docs/specs/SPEC-PR-PLAN.spec.md` (referencia plan.md)
- `spec-judge` prompt (pass plan adherence opcional)

### Verification protocol
```bash
bats tests/bats/test-plan-diff-check.bats
python3 scripts/plan-validate.py --plan sample-plan.md
```

### Portability classification
- Bash + python3 stdlib; local; portable

## Validación (ejecutada en esta sesión)

- `scripts/plan-validate.py`: valida secciones (Files/Order/Risks/Proof) y extrae archivos; fail-soft salvo --strict; 11 bats verdes
- `scripts/plan-diff-check.sh`: compara diff contra plan.md; mode warn (exit 0) / block (exit 2); artefactos de proceso excluidos; plan inexistente → fail-soft

## Referencias
- Anthropic: claude.com/blog/the-ai-native-sdlc-playbook (Stage 3 plan mode, Stage 5 review)
- Savia: SPEC-PR-PLAN, SDD, spec-judge, CRIT-001
