---
name: multi-tenant-calendar-sync
description: >
  Sincronizacion bidireccional de disponibilidad entre calendarios de dos
  tenants Microsoft 365. Bloques busy/free, deteccion de conflictos,
  credenciales cifradas por usuario.
type: spec
status: draft
priority: P0
parent: smart-calendar
---

# Spec: Sincronizacion Multi-Tenant de Calendarios

Referencia de seguridad: `spec-multi-tenant-security.md`

## Problema

Profesional trabaja en 2 empresas (consultora + cliente). Cada una tiene
su tenant Microsoft 365 con Teams/Outlook. Los calendarios son independientes.
Resultado: reuniones que se pisan, duplicacion manual, riesgo de aceptar
reuniones en huecos ocupados en el otro tenant.

## Restricciones de diseño

1. **Privacidad**: solo sincronizar free/busy, NUNCA contenido de reuniones
2. **Secretos individuales**: credenciales por usuario, cifradas, NUNCA en repo
3. **Bidireccional**: A↔B en ambas direcciones
4. **Idempotente**: ejecutar 2 veces = mismo resultado
5. **No destructivo**: solo crear/actualizar/borrar bloques `[Sync]`
6. **Offline-safe**: si un tenant falla, sincronizar el otro y avisar

## Arquitectura

```
/sync-calendars → Credential Store → Graph API Client ×2
                  (AES-256 local)    (Tenant A + Tenant B)
```

### 1. Credential Store — `$HOME/.pm-workspace/calendar-secrets/{slug}/`

```
calendar-secrets/{slug}/
├── tenant-a.enc    ← AES-256 cifrado con passphrase del usuario
├── tenant-b.enc    ← idem
└── sync-state.json ← estado ultima sync (timestamps, checksums)
```

Cifrado: AES-256-CBC, PBKDF2 100K iter. Passphrase en memoria, 1 vez/sesion.

### 2. Graph API Client — Device Code Flow (OAuth 2.0)

Permisos: `Calendars.ReadWrite` (delegated). Cada tenant requiere su propia
app registration en Azure AD. Tokens en memoria, refresh automatico (90 dias).

### 3. Sync Engine — Algoritmo

```
1. Autenticar ambos tenants (tokens en memoria)
2. Leer eventos de ambos (ventana: hoy + 14 dias)
3. Filtrar: excluir bloques [Sync] previos (solo eventos reales)
4. Para cada evento real en A:
   - Si no existe bloque [Sync] en B → crear
   - Si existe pero horario cambio → actualizar
   - Si evento cancelado → borrar bloque [Sync] en B
5. Repetir en direccion B → A
6. Detectar conflictos: evento real A pisa evento real B
7. Guardar sync-state.json
```

### 4. Conflict Detector

| Tipo | Condicion | Accion |
|------|-----------|--------|
| **Hard** | Reunion confirmada en A + confirmada en B, mismo horario | ALERTA ROJA |
| **Soft** | Tentative en A + evento en B | AVISO amarillo |
| **Resolved** | Bloque [Sync] ya cubre el hueco | OK, sin accion |

## Bloques sincronizados — Marcado

- **Subject**: `[Sync] Ocupado` (sin detalles del original)
- **Category**: `SaviaSync` (filtrar y limpiar)
- **ShowAs**: `Busy` (Teams lo respeta al planificar)
- **IsReminderOn**: `false` | **Sensitivity**: `Private`

## Comando /sync-calendars

| Subcomando | Descripcion |
|------------|-------------|
| `/sync-calendars` | Sincronizar ahora (default) |
| `/sync-calendars setup` | Wizard de config de credenciales |
| `/sync-calendars status` | Estado de ultima sync + conflictos |
| `/sync-calendars conflicts` | Listar solo conflictos activos |
| `/sync-calendars clean` | Eliminar bloques [Sync] (con confirmacion) |

## Flujo de sync (uso normal)

```
🔑 Passphrase: _________ (1 vez por sesion)

📋 1/4 — Autenticando ambos tenants... ✅ ✅
📋 2/4 — Leyendo calendarios (14 dias)...
   Empresa A: 23 eventos (18 reales + 5 [Sync])
   Empresa B: 31 eventos (28 reales + 3 [Sync])
📋 3/4 — Sincronizando...
   → 3 bloques nuevos en A, 2 actualizados en B, 1 eliminado
📋 4/4 — Conflictos...
   🔴 1 HARD: Lun 24 10:00-11:00 "Sprint Review" vs "Steerco"

✅ Sync completada — 6 cambios, 1 conflicto pendiente
```

## Reglas de negocio

1. NUNCA crear bloque [Sync] que pise evento real existente
2. Conflictos reales NO se resuelven automaticamente — alertar al usuario
3. Bloques [Sync] son `tentative` por defecto (override con `--busy`)
4. Ventana de sync: 14 dias (configurable `--days 7|14|30`)
5. Rate limit: max 1 sync cada 5 min (evitar throttling Graph API)
6. Si un tenant falla: sync parcial + error reportado
7. `/sync-calendars clean` requiere confirmacion explicita
8. Passphrase NUNCA viaja a ningun servidor — cifrado 100% local

## Integracion con Smart Calendar

- `/calendar-today` muestra bloques [Sync] con etiqueta del tenant
- `/calendar-plan` respeta [Sync] como tiempo ocupado no movible
- `/calendar-rebalance` no mueve bloques [Sync] (son espejo)
- `/criticality-dashboard` usa disponibilidad cruzada de ambos tenants

## Prerequisitos

1. App Registration en cada tenant con `Calendars.ReadWrite`
2. Admin o user consent segun politica del tenant
3. openssl instalado (cifrado local)

## Limitaciones

- Graph API rate limits (~10K req/10min por app)
- Tenants que bloquean app registrations externas → fallback con `az login`
- Reuniones private en origen → bloque opaco "[Sync] Ocupado" en destino
- Recurrencias: se sincronizan instancias individuales, no la serie
