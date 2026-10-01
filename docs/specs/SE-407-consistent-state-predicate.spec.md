---
status: APPROVED
approved_at: 2026-09-29
approval: "Operadora 2026-09-29 en chat: aprobada; sustituirá a SE-378 en el WIP (intercambio pendiente)"
priority: P0
developer_type: agent-single
created: 2026-09-29
phase: A
risk: L1
related_specs: [SE-396, SE-378, SE-369, SE-222, SE-338]
origin: output/research/harness-referencias-20260929.md (§1, learn-harness-engineering)
---

# SE-407 — Predicado único de estado consistente y cierre de sesión limpio

## Problema

En una semana entraron en `main` con CI verde tres regresiones de artefactos
generados. Ningún comando único comprueba que el repo está en un estado
consistente:

- `rule-manifest.json` desfasado desde #1165: `readiness-check` en FAIL crítico.
- Pin `settings-hooks` sin renovar desde #1168: `test-contract-pin` rojo.
- `docs/propuestas/INDEX.md` desfasado desde el 31/08: los hooks lo regeneraban
  y dejaban sucio el checkout principal, bloqueando cambios de rama.

Cada comprobación existe (`--check` de cada generador), pero está dispersa: ni
`validate-ci-local.sh` (gate G10 de `pr-plan`) ni la CI las invocan. Un auditor
externo (`learn-harness-engineering/tools/audit-harness.sh`, 19/70 sobre Savia)
señala el mismo hueco: falta un predicado de "estado consistente" (su `make check`)
y una comprobación de estado limpio al cerrar la sesión.

## Slices

### S1 — Frescura de artefactos generados en `validate-ci-local.sh`

Añadir `check_generated_fresh` (paralelo, como el resto) que ejecute los `--check`
existentes, sin reimplementarlos:
`rule-manifest-generate.sh --check`, `contract-pin.sh check settings-hooks`,
`sam.py check`, `propuestas-index-gen.sh --check` y `roadmap.sh validate`.
El fallo nombra el artefacto y el comando que lo regenera. Así la G10 de `pr-plan`
lo aplica en cada PR, y el job de CI que ya usa `validate-ci-local.sh` también.

- AC1: con cada artefacto desfasado en un fixture, el script sale ≠0 y nombra el
  artefacto y su comando de regeneración.
- AC2: en `main` al día sale 0; el tiempo añadido es < 15 s.
- AC3: `--quick` puede omitir `sam.py check` (el más lento) pero nunca los otros cuatro.

### S2 — Comprobación de estado limpio al cerrar

`validate-ci-local.sh --clean-state` (advisory) añade: checkout principal sin
cambios fuera de `output/`, sin worktrees `agent/*` de PRs ya mergeadas y
`docs/propuestas/session-handoff.md` actualizado si hubo commits en la sesión.

- AC4: cada dimensión se reporta por separado; solo S1 bloquea, S2 es advisory.
- AC5: un worktree `agent/*` con PR mergeada y sin cambios aparece como "retirable".

### S3 — Entrada que se explica sola

`CLAUDE.md` responde en sus 10 primeras líneas qué es Savia y enlaza clock-in
(traspaso + `validate-ci-local.sh`) y clock-out (`--clean-state` + traspaso),
dentro del límite de líneas vigente (Rule 11) y sin mover los imports críticos.

- AC6: `audit-harness.sh` deja de marcar FAIL en "answers 'what is this system?'".

### S4 — Auditor externo como sonda del Conformance Lab (Fase C, report-only)

Ejecutar `audit-harness.sh` fijado por commit SHA y sha256, en solo lectura, con
un mapa de equivalencias (`PROGRESS.md` ≙ `session-handoff.md`,
`feature_list.json` ≙ `planning-state.json`, …) para no contar diferencias de
convención como fallos. El resultado es una métrica externa, no un gate.

- AC7: el informe distingue "hueco real" de "equivalente Savia".

## Entregables (rutas)

- S1: `scripts/validate-ci-local.sh`, `tests/test-validate-ci-fresh.bats`; artefactos regenerados
  cuando estén desfasados (`docs/rules/domain/rule-manifest.json`, `.scm/`).
- S2: `scripts/validate-ci-local.sh`, `tests/test-validate-ci-clean-state.bats`.
- S3: `CLAUDE.md`, `AGENTS.md`.

## Fuera de alcance

Renombrar ficheros de Savia a las convenciones de LHE; añadir un Makefile.

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| `validate-ci-local.sh` (S1, S2) | bash | idéntico |
| `CLAUDE.md` (S3) | entrada | `AGENTS.md` regenerado (SE-371), sin cambio de contrato |
| `audit-harness.sh` (S4) | bash | idéntico |

### Verification protocol

- [ ] S1/S2 dan el mismo resultado en ambos runtimes (bash puro)
- [ ] S3: `AGENTS.md` regenerado conserva la cabecera

### Portability classification

- [x] **PURE_BASH**

## Resultados

### S1 (2026-10-01)

| AC | Evidencia | Estado |
|---|---|---|
| AC1 | `tests/test-validate-ci-fresh.bats`: con cada comprobación fallando (tabla de prueba) el script sale ≠0 y escribe `Generado desfasado: <artefacto> → regenerar: <comando>`; varios desfasados se listan por separado. Integración en un clon real: `INDEX.md` y una regla nueva sin manifiesto se detectan con los `--check` reales | OK |
| AC2 | Sin desfases, ninguna línea de desfase y cinco «al día». Tiempo: `validate-ci-local.sh` 4,2 s → 11,4 s (+7,2 s, < 15 s); `--quick` 5,7 s | OK |
| AC3 | `--quick` omite solo `sam.py check`; los otros cuatro siguen bloqueando | OK |

Hallazgo al implementarlo: `main` tenía `rule-manifest.json` desfasado desde #1188 (SE-410
añadió `rag-embedding-policy.md` sin regenerarlo) y ningún gate lo vio. Se regenera aquí.

Desviación: la spec suponía que un job de CI usa `validate-ci-local.sh`; no es así, solo
la G10 de `pr-plan`. La CI ya ejecuta `roadmap validate` en «Validate workspace»; añadir
los otros cuatro a la CI toca `.github/workflows` (tier 4) y queda para revisión humana.

### S2 (2026-10-01)

| AC | Evidencia | Estado |
|---|---|---|
| AC4 | `validate-ci-local.sh --clean-state` (y `--clean-state-only [--repo DIR]`) informa en líneas separadas checkout principal, worktrees y traspaso; solo PASS/WARN, salida 0. `tests/test-validate-ci-clean-state.bats` (11) con repos git temporales, incluido un traspaso borrado | OK |
| AC5 | Worktree `agent/*` sin cambios cuyo contenido ya está en main ⇒ «retirable», también tras squash y cambios posteriores en los mismos ficheros (patch-id). No retirable si tiene trabajo sin integrar o cambios sin commit. En el repo real marca exactamente los worktrees de #1197–#1204 | OK |

Sin script nuevo: la lógica vive en `validate-ci-local.sh` para no subir la entropía
(SE-380, ratchet 1623); un primer intento con `clean-state-check.sh` aparte la subía a 1624.

Interpretación: «commits en la sesión» se mide como commits en main posteriores a la
última actualización de `session-handoff.md` (sin estado de sesión que consultar).
