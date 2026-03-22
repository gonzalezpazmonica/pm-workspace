# SPEC-026: PreCompact Hook — Transcript Backup

> Status: **READY** · Fecha: 2026-03-22
> Origen: disler/claude-code-hooks-mastery — PreCompact lifecycle event
> Impacto: Zero data loss on /compact. Aligns with SPEC-016.

---

## Problema

Cuando se ejecuta /compact, Claude Code descarta contexto. Nuestro
SPEC-016 (intelligent compact) extrae decisiones antes de compactar,
pero NO se ejecuta automaticamente — depende de que Savia lo haga.

El hook PreCompact de Claude Code se dispara ANTES de cada compact,
automaticamente. Es el lugar perfecto para persistir lo valioso.

## Solucion

Hook `.claude/hooks/pre-compact-backup.sh` que:

1. Lee el contexto actual (ultimos N turnos via stdin)
2. Extrae: decisiones, correcciones, descubrimientos
3. Guarda en memory-store.sh como session entries
4. Sale con code 0 (nunca bloquea compact)

## Implementacion

```json
{
  "hooks": {
    "PreCompact": [{
      "command": ".claude/hooks/pre-compact-backup.sh"
    }]
  }
}
```

El hook recibe el transcript como JSON en stdin. Extrae:
- Lineas con "decision", "chose", "decided", "will use"
- Correcciones del usuario ("no", "wrong", "change to")
- Ficheros modificados en la sesion

Guarda via `memory-store.sh session-summary`.

## Tests

- Hook existe y es bash valido
- Hook no bloquea (exit 0 siempre)
- Con input simulado, genera session-summary
