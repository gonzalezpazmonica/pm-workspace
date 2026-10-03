---
paths:
  - "**/savia-hub*"
  - "**/hub-sync*"
context_tier: L2
token_budget: 708
---

# Regla: SaviaHub Modo Vuelo y Sincronización
# ── Offline-first, cola de escritura, resync automático ──────────────────────

> SaviaHub funciona siempre en local. El remote es opcional.
> Modo vuelo permite trabajar sin conexión y sincronizar después.

## Modo vuelo (flight mode)

### Activación
Implementación: `scripts/savia-hub-sync.sh` (tests en `tests/test-savia-hub-sync.bats`).

```
savia-hub-sync.sh flight on   → push y pull bloqueados (exit 4, salvo --force)
savia-hub-sync.sh flight off  → quita el bloqueo; NO sincroniza (ejecutar pull y push)
```

### Comportamiento cuando ON
1. Las escrituras van a local, como siempre
2. No se intenta push ni pull
3. Lo pendiente se lee de `git status` y `git log`, no de una cola

### Comportamiento cuando OFF
Solo cambia `flight_mode: false`. Sincronizar es explícito: `pull` y después
`push` (vista previa) y `push --yes` tras confirmar con el PM.

## Cola de escritura (.sync-queue.jsonl)

- Fichero local, fuera de git (`.gitignore` y `.git/info/exclude`)
- Hoy ningún script lo escribe; `push --yes` lo trunca tras un sync correcto
- Formato reservado si se implementa: JSONL `{"ts","action","path","hash"}`

## Sin red o sin remote

- Sin remote: push y pull salen con exit 3; status dice `solo local`
- Remote inalcanzable (fetch con timeout `SAVIA_HUB_NET_TIMEOUT`, 20 s): exit 5;
  status dice `remote inalcanzable — estado desconocido`
- `sincronizado` solo se muestra con 0 commits por subir, 0 por bajar y 0 cambios sin commit

## Detección de divergencia

1. `git fetch` y comparación de `HEAD` con `origin/<rama actual>`
2. Push con el remote por delante → exit 7 (ejecutar pull antes)
3. Pull → rebase sobre el remote; los cambios locales sin commit se commitean antes
4. NUNCA auto-merge en ficheros de clientes (datos sensibles)

## Sync automático

No implementado. `sync_interval_seconds` y `auto_sync_on_change` son campos de
config reservados; ningún proceso los lee.

## Resolución de conflictos

```
1. pull detecta el conflicto, lista los ficheros y aborta el rebase (exit 8)
2. El hub queda con lo local commiteado; nada se pierde
3. El PM repite el pull con rebase a mano y decide por fichero:
   [Mantener local] [Aceptar remoto] [Merge manual]
4. push (vista previa) y push --yes; last_sync se actualiza
```

## Regla de oro

> El PM siempre tiene la última palabra en conflictos.
> Savia propone, el PM decide. NUNCA auto-resolver datos de clientes.
