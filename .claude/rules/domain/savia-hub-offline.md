---
paths:
  - "**/savia-hub*"
  - "**/hub-sync*"
---

# Regla: SaviaHub Modo Vuelo y Sincronización
# ── Offline-first, cola de escritura, resync automático ──────────────────────

> SaviaHub funciona siempre en local. El remote es opcional.
> Modo vuelo permite trabajar sin conexión y sincronizar después.

## Modo vuelo (flight mode)

### Activación
```
/savia-hub flight-mode on   → Desactiva sync, solo escritura local
/savia-hub flight-mode off  → Reactiva sync, drena cola pendiente
```

### Comportamiento cuando ON
1. Todas las escrituras van a local
2. Cada escritura se registra en `.sync-queue.jsonl`
3. No se intenta push/pull
4. Status muestra `✈️ Modo vuelo activo — N cambios pendientes`

### Comportamiento cuando OFF
1. Se verifica conectividad con remote (si configurado)
2. Si hay cola pendiente → drenar (commit + push)
3. Si hay cambios remotos → pull con rebase
4. Si hay conflictos → notificar al PM, no auto-resolver
5. Status muestra `✅ Online, sincronizado`

## Cola de escritura (.sync-queue.jsonl)

```json
{"ts":"2026-03-05T14:30:00Z","action":"write","path":"clients/acme/profile.md","hash":"abc123"}
{"ts":"2026-03-05T14:31:00Z","action":"write","path":"company/identity.md","hash":"def456"}
```

- Formato: JSONL append-only
- Campos: `ts` (ISO 8601), `action` (write|delete), `path`, `hash` (SHA256)
- Máximo: 10.000 entradas (warn al 80%, error al 100%)
- Limpieza: tras sync exitoso, truncar cola

## Detección de divergencia

Al desactivar modo vuelo o ejecutar `/savia-hub push`:
1. Comparar `HEAD` local vs `origin/HEAD`
2. Si fast-forward posible → rebase automático
3. Si divergencia → mostrar lista de ficheros en conflicto
4. NUNCA auto-merge en ficheros de clientes (datos sensibles)

## Sync automático (cuando flight-mode OFF y remote configurado)

- Intervalo: cada `sync_interval_seconds` (default 3600 = 1h)
- Trigger: también al ejecutar `/savia-hub push` o `/savia-hub pull`
- Auto-sync on change: si `auto_sync_on_change: true`, commitea y pushea
  tras cada escritura via comando Savia

## Resolución de conflictos

```
1. Detectar ficheros con conflicto
2. Para cada fichero:
   a. Mostrar diff (local vs remote) al PM
   b. Opciones: [Mantener local] [Aceptar remoto] [Merge manual]
   c. Registrar decisión en commit message
3. Commit merge + push
4. Actualizar last_sync
```

## Mensajes de estado

```
✅ Online, sincronizado (último sync: hace 5 min)
✈️ Modo vuelo activo — 3 cambios pendientes
⚠️ Divergencia detectada — 2 ficheros en conflicto
❌ Remote no configurado — solo modo local
🔄 Sincronizando... (3/5 cambios)
```

## Regla de oro

> El PM siempre tiene la última palabra en conflictos.
> Savia propone, el PM decide. NUNCA auto-resolver datos de clientes.
