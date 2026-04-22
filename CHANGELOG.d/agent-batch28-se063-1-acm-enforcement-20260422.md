# Batch 28 — SE-063 Slice 1+2 ACM enforcement hooks

**Date:** 2026-04-22
**Branch:** `agent/batch28-se063-1-acm-detector-20260422`
**Version bump:** 5.76.0

## Summary

Era 185 arranca. SE-063 (ACM enforcement pre-tool hook) activa el sistema `.agent-maps/INDEX.acm` que existía pero era ignorado por los agentes. Slice 1 (detector) + Slice 2 (marker) implementados en un batch.

## Implementación

### `.claude/hooks/acm-enforcement.sh` (PreToolUse Glob|Grep)

Lógica:
1. Si `SAVIA_ACM_ENFORCE=0|off` → exit 0 (disabled)
2. Parse tool_input via jq
3. Sólo actúa sobre Glob/Grep
4. Detecta query amplia: pattern en `{.*, **/*, **, *, ., empty}`, o Grep sin path/type/glob, o Glob sin path
5. Extrae project name de `path=projects/{name}/...`
6. Skip si path es `.claude|docs|scripts|tests|output|hooks|.github`
7. Skip si no existe `projects/{name}/.agent-maps/INDEX.acm`
8. Verifica marker `$TMPDIR/savia-turn-{id}/acm-read-{project}`
9. Si marker existe → exit 0 (ACM ya consultado)
10. Loguea en `output/acm-enforcement.log`
11. Modo warn: emite a stderr, exit 0. Modo block: stderr + exit 2.

### `.claude/hooks/acm-turn-marker.sh` (PostToolUse Read)

Lógica:
1. Sólo actúa sobre Read
2. Si `file_path` matchea `*/projects/{name}/.agent-maps/*` → crea marker
3. No-op en cualquier otro caso

**Registro en settings.json**: PreToolUse Glob|Grep ya registrado. PostToolUse Read pendiente de aprobación (self-modification guard bloqueó la edición automática).

## Testing

`tests/test-acm-enforcement.bats`: 32 tests PASS, certified por test-auditor.

Cobertura:
- Positive paths: queries narrow allowed, queries on infra exempt
- Warn/block modes: comportamiento esperado
- Marker bypass: reconocimiento de ACM consultado
- Env overrides: 0/off disable
- Edge cases: malformed JSON, missing tool_name, empty pattern, deeply nested paths
- Companion tests: marker hook creates/skips correctly

## Validación

- `readiness-check.sh`: PASS (98 checks, 0 fail, 0 warn)
- `claude-md-drift-check.sh`: PASS (hooks 56→58, regs 60→61)

## Pendiente

1. **Aprobación explícita** para registrar `acm-turn-marker.sh` como PostToolUse Read en `.claude/settings.json`. Sin esto, el marker script existe pero no se invoca automáticamente → en warn mode no hay impacto (sólo advertencias); en block mode NO se debe activar hasta aprobar marker.
2. **Slice 3 SE-063** (bypass semántico adicional, 1-2h): env override runtime, logs verbosity, exception list por proyecto.

## Compliance

- Memory feedback_no_overrides_no_bypasses: el hook no tiene override automático; `SAVIA_ACM_ENFORCE=0` es explícito y documentado en el script
- Rule #8 autonomous safety: registro PostToolUse queda gated por aprobación humana
- Default warn-only evita bloqueo sorpresa en primer deploy

## Referencias

- Spec: `docs/propuestas/SE-063-acm-enforcement-pretool-hook.md`
- Origen research: `output/research-coderlm-20260421.md` (batch 25)
- ACM base skill: `.claude/skills/agent-code-map/SKILL.md`
