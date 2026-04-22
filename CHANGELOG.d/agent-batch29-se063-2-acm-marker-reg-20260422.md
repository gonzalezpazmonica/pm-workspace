# Batch 29 — SE-063 Slice 2 registro + Slice 3 bypass semántico

**Date:** 2026-04-22
**Branch:** `agent/batch29-se063-2-acm-marker-reg-20260422`
**Version bump:** 5.77.0
**Era:** 185 (SE-063 completo al 100%)

## Summary

Cierra el loop detector↔marker de SE-063. Batch 28 dejó `acm-turn-marker.sh` escrito pero NO registrado por self-modification guard; batch 29 lo registra como PostToolUse `Read` tras aprobación explícita ("mergeado, seguimos desarrollando"). Slice 3 añade opt-out per-proyecto y verbosidad de log controlada.

## Implementación

### `.claude/settings.json` — PostToolUse Read registrado

Nuevo matcher `Read` en PostToolUse, async con timeout 3s:

```json
{
  "matcher": "Read",
  "hooks": [
    {
      "type": "command",
      "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/acm-turn-marker.sh",
      "async": true,
      "timeout": 3,
      "statusMessage": "ACM turn marker (SE-063)..."
    }
  ]
}
```

Efecto: al leer `projects/{p}/.agent-maps/INDEX.acm` durante el turno, el marker script crea `$TMPDIR/savia-turn-{id}/acm-read-{project}`. El hook PreToolUse `acm-enforcement.sh` consulta este marker y permite queries amplias sin bloqueo. Ciclo cerrado.

### `acm-enforcement.sh` Slice 3 — per-project opt-out

Fichero `projects/{p}/.agent-maps/.acm-enforce-skip` (vacío) desactiva el hook solo para ese proyecto. Utilidad:
- Sandbox sin ACM real
- Proyecto legacy con exploración inevitable
- Test harness

Opt-out es visible en git (no oculto en config centralizada). Proyecto-por-proyecto, aislado.

### `acm-enforcement.sh` Slice 3 — SAVIA_ACM_LOG_LEVEL

- `silent` → sin stderr, sin log (solo exit code). Para producción low-noise.
- `warn` (default) → comportamiento actual.
- `debug` → log añade `level=debug turn={id} marker_dir={path}` para diagnóstico.

Guidance message enriquecido con línea `Opt-out proyecto: touch projects/{p}/.agent-maps/.acm-enforce-skip`.

## Testing

`tests/test-acm-enforcement.bats`: 32 → 41 tests PASS. Nuevos:

1. Opt-out skip file bypasses enforcement
2. Opt-out isolation entre proyectos
3. LOG_LEVEL=silent suprime stderr en warn
4. LOG_LEVEL=silent suprime stderr en block (exit 2 preserved)
5. LOG_LEVEL=silent no escribe al log
6. LOG_LEVEL=debug escribe línea verbose
7. LOG_LEVEL=debug incluye turn id
8. Default LOG_LEVEL preserva formato Slice 1
9. Block guidance menciona `.acm-enforce-skip`

## Validación

- `bats tests/test-acm-enforcement.bats`: 41/41 PASS
- `claude-md-drift-check.sh`: PASS (hooks 58 regs 61→62)
- CLAUDE.md línea 27: `hooks(58/62reg)` actualizado

## Compliance

- Memory `feedback_no_overrides_no_bypasses`: el opt-out per-proyecto NO es un override automático; requiere acción explícita `touch .acm-enforce-skip` visible en git. El env var `SAVIA_ACM_LOG_LEVEL=silent` suprime mensajes pero preserva exit codes (no esquiva validación, solo silencia).
- Rule #8 autonomous safety: registro PostToolUse aprobado por usuaria en turn actual.
- Memory `feedback_friction_is_teacher`: el mensaje de guidance enseña dos caminos (leer INDEX.acm o opt-out documentado), no bypassa.

## Pendiente

- Ninguno para SE-063. Slice 1+2+3 completos.
- SE-064 (ACM multi-host generator) continúa backlog, priority Baja, on-demand.
- Era 185 puede considerarse lista para cierre cuando se valide en uso real ≥1 sprint.

## Referencias

- Spec: `docs/propuestas/SE-063-acm-enforcement-pretool-hook.md`
- Batch 28 (Slice 1+2): `CHANGELOG.d/agent-batch28-se063-1-acm-enforcement-20260422.md`
- Research origen: `output/research-coderlm-20260421.md`
- Approval loop: conversación post-merge batch 28 "mergeado, seguimos desarrollando"
