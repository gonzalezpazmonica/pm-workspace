---
spec_id: SE-094
title: Hooks integrity — registered without file & files without registration
status: IMPLEMENTED
implemented_at: 2026-05-30
implemented_by: opencode-claude-opus-4.7
approved_by: operator (2026-05-27)
priority: P0
effort: S
estimated_time: 45 min
depends_on: none
source: output/20260527-auditoria-obsoleto-legado.md (Tier 1.1, 1.2)
---

# SE-094 — Hooks integrity

## Problema

Auditoría 2026-05-27 detecta:
- 2 hooks registrados en `.claude/settings.json` sin fichero `.sh` correspondiente (`check-daemon-auth.sh`, `post-compaction.sh`) — fallan silenciosamente en runtime.
- 7 ficheros `.sh` en `.opencode/hooks/` sin registro: `android-adb-validate`, `auto-grill-me`, `auto-zoom-out`, `cognitive-debt-hypothesis-first`, `cognitive-debt-telemetry`, `project-isolation-gate`, `recommendation-tribunal-pre-output` — código muerto o wiring incompleto.

## Solución

### Slice 1: Hooks fantasma (~15 min)
Para cada uno de los 2 registrados sin fichero:
1. `grep` su nombre en specs y CHANGELOG para entender intención original
2. Decisión: crear .sh stub funcional, o eliminar entrada de `.claude/settings.json`
3. Commit con justificación

### Slice 2: Hooks huérfanos (~30 min)
Para cada uno de los 7 sin registro:
1. Leer cabecera del .sh para determinar evento esperado (PreToolUse, PostToolUse, Stop, ...)
2. Decidir: registrar en settings.json o mover a `.opencode/hooks/archive/`
3. Confirmar uno a uno con operadora (no auto-decisión)

## Aceptación

- [x] AC-1: `hooks-orphan-check` reporta 0 huérfanos en ambos sentidos (`scripts/hooks-integrity-check.sh`)
- [x] AC-2: CLAUDE.md drift check sigue PASS
- [x] AC-3: CHANGELOG documenta cada decisión (`CHANGELOG.d/feat-se-094-finish-orphan-hook-20260530.md`)
- [x] AC-4: allowlist mechanism for deliberate non-registration — `.claude/hooks-allowlist.tsv` + `scripts/hooks-integrity-check.sh` reads it + `tests/structure/test-hooks-integrity-allowlist.bats` enforces contract (justification ≥10 chars + spec/rule citation)

## Notas

Algunos huérfanos (`auto-grill-me`, `auto-zoom-out`, `recommendation-tribunal-pre-output`) sugieren features parcialmente implementadas — confirmar si son trabajo futuro pendiente de wiring.

## Notas de implementación (2026-05-27)

**Hallazgos al ejecutar**:
- Los 2 "fantasma" eran falso positivo del auditor original: `check-daemon-auth.sh` y `post-compaction.sh` existen en `scripts/` (auditor solo buscaba en `.opencode/hooks/`).
- Los "7 huérfanos" eran realmente **5**: `auto-grill-me.sh` y `auto-zoom-out.sh` SÍ estaban registrados (auditor falló al detectarlos).
- `.opencode/hooks` es symlink a `.claude/hooks` — find requiere `-L` o trailing slash.

**Acciones tomadas**:
- Creado `scripts/hooks-integrity-check.sh` con detección bidireccional (phantom + orphan), búsqueda en ambas ubicaciones (`.opencode/hooks/` y `scripts/`), soporte symlink (`-L`).
- Registrados 4 hooks en `.claude/settings.json`:
  - `android-adb-validate.sh` → PreToolUse / Bash (blocking, ADB safety)
  - `cognitive-debt-hypothesis-first.sh` → PreToolUse / Edit|Write (SPEC-107 I1)
  - `cognitive-debt-telemetry.sh` → PostToolUse / Edit|Write|Task (SPEC-107 I4)
  - `project-isolation-gate.sh` → PreToolUse / Edit|Write|Read (SE-093 zero-leak)
- Backup: `.claude/settings.json.bak-se094`
- `hooks-integrity-check.sh` ahora reporta solo 1 huérfano restante: `recommendation-tribunal-pre-output.sh` (SPEC-125, pendiente decisión).


## Notas de cierre (2026-05-30)

El último orphan residual (`recommendation-tribunal-pre-output.sh`) no es un fallo:
es un hook WIRE-READY de SPEC-125 Slice 1 que requiere revisión humana deliberada
antes de activarse (gobernanza). Para cerrar SE-094 sin forzar esa activación:

- Añadido mecanismo de allowlist en `scripts/hooks-integrity-check.sh`.
- `.claude/hooks-allowlist.tsv` lista hooks WIRE-READY con justificación obligatoria
  (formato `filename.sh<TAB>justificación`, una entrada por hook).
- Test BATS `tests/structure/test-hooks-integrity-allowlist.bats` valida el contrato:
  cada entrada de la allowlist requiere justificación ≥10 chars y referencia a un spec.
- Resultado: `bash scripts/hooks-integrity-check.sh` reporta PASS (0 orphans, 0 phantoms).
