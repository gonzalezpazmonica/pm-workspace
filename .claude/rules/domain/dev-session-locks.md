# Regla: Dev-Session Locks — Recuperacion de Crash

> Inspirado en GSD 2: disk state machine con lock files y PID detection.
> Complementa dev-session-protocol.md con persistencia y crash recovery.

---

## Lock file

Al iniciar una dev-session, crear `.claude/sessions/{id}.lock`:

```json
{
  "session_id": "20260319-AB102-feature",
  "pid": 12345,
  "started_at": "2026-03-19T02:00:00Z",
  "updated_at": "2026-03-19T02:15:00Z",
  "current_slice": 3,
  "total_slices": 5,
  "state": "implementing"
}
```

Actualizar `updated_at` y `current_slice` tras cada transicion de slice.
Eliminar lock al completar la sesion (todos los slices verified/completed).

## Deteccion de lock stale

Un lock se considera stale si:
1. El PID del lock no esta corriendo (`kill -0 $PID` falla)
2. `updated_at` tiene mas de 30 minutos sin actualizacion
3. Ambas condiciones deben cumplirse (evitar falsos positivos)

Si stale: safe to resume. Limpiar lock y crear uno nuevo.

## Estados de slice

```
pending → implementing → validating → verified → completed
                ↓ (crash)
            [stale lock] → resume → implementing (retry)
```

Transiciones validas:
- pending → implementing (al cargar contexto del slice)
- implementing → validating (al completar codigo)
- validating → verified (al pasar tests + coherence)
- verified → completed (al integrar)
- implementing → implementing (retry tras crash recovery)

## State file

`output/dev-sessions/{id}/state.json` — actualizar tras cada slice:

```json
{
  "session_id": "20260319-AB102-feature",
  "spec_path": "specs/AB102.spec.md",
  "total_slices": 5,
  "current_slice": 3,
  "slices": [
    {"id": 1, "status": "completed", "files": ["Service.cs"]},
    {"id": 2, "status": "verified", "files": ["Repository.cs"]},
    {"id": 3, "status": "implementing", "files": ["Controller.cs"]},
    {"id": 4, "status": "pending", "files": ["Tests.cs"]},
    {"id": 5, "status": "pending", "files": ["IntegrationTests.cs"]}
  ]
}
```

## Comando /dev-session resume

1. Buscar locks en `.claude/sessions/`
2. Si hay lock stale: mostrar estado y preguntar si reanudar
3. Si reanudar: leer state.json, sintetizar briefing:
   - Slices completados: resumen de lo hecho
   - Slice actual: donde se quedo, que falta
   - Slices pendientes: lista
4. Cargar contexto del slice actual y continuar

## Integracion con commit-guardian

CHECK 11 (nuevo): si hay algun slice en estado `implementing` en cualquier
session activa, **warn** (no bloquear) al hacer commit. El codigo puede estar
incompleto.

## Limpieza

- Locks de sesiones completadas: eliminar automaticamente
- Locks de sesiones stale >24h: eliminar con warning
- State files: mantener 30 dias, luego archivar

## Directorio

```
.claude/sessions/           ← locks (gitignored)
output/dev-sessions/{id}/   ← state + outputs (gitignored)
```

Añadir `.claude/sessions/` a `.gitignore`.
