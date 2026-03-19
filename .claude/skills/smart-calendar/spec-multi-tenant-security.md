---
name: multi-tenant-security-reference
description: >
  Modelo de seguridad y amenazas para la sincronizacion multi-tenant
  de calendarios. Credenciales, cifrado, datos sincronizados.
type: reference
parent: spec-multi-tenant-sync.md
---

# Seguridad Multi-Tenant Sync — Referencia

## Credential Store detallado

Cada fichero `.enc` contiene (cifrado con passphrase del usuario):
```json
{
  "tenant_id": "xxx-xxx",
  "client_id": "xxx-xxx",
  "client_secret": "xxx",
  "user_email": "user@empresa.com",
  "calendar_id": "primary",
  "label": "Empresa A"
}
```

Cifrado: `openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000`
Permisos fichero: 600 (solo owner). Ruta dentro de `$HOME` (no en repo).

## Modelo de amenazas

| Amenaza | Mitigacion |
|---------|-----------|
| Credenciales en disco sin cifrar | AES-256 + PBKDF2 100K, passphrase en memoria |
| Passphrase comprometida | No se persiste. Se pide por sesion |
| Token leak | Tokens solo en memoria, refresh automatico |
| Exfiltracion datos reuniones | Solo free/busy, NUNCA contenido |
| Man-in-the-middle | HTTPS obligatorio (Graph API) |
| Acceso no autorizado a .enc | Permisos 600, bajo $HOME |
| Passphrase debil | Minimo 12 caracteres, warn si <16 |
| Tenant comprometido | Cada tenant es independiente, sin cross-access |

## Datos que NUNCA se sincronizan

- Titulo de la reunion
- Asistentes (nombres, emails)
- Descripcion / notas / body
- Adjuntos
- Respuestas de asistencia (accept/decline/tentative)
- Ubicacion (sala, link Teams/Zoom)
- Links de videoconferencia

## Datos que SI se sincronizan

- Hora inicio y hora fin
- Estado: busy / tentative / free / out-of-office
- Si es todo el dia (all-day event)
- Si es recurrente (para calcular instancias futuras)

## Flujo de setup (primera vez)

```
/sync-calendars setup

🦉 Configurando sincronizacion multi-tenant.
   Cifrare tus credenciales con una passphrase que solo tu conoces.

━━ Tenant A ━━━━━━━━━━━━━━━━━━━━━━━
  Etiqueta: _________ (ej: "Mi Consultora")
  Tenant ID: _________
  Client ID: _________
  Client Secret: _________
  Tu email: _________@_______.com

━━ Tenant B ━━━━━━━━━━━━━━━━━━━━━━━
  Etiqueta: _________ (ej: "Cliente X")
  ...

━━ Passphrase ━━━━━━━━━━━━━━━━━━━━━
  Cifrado (min 12 chars): _________
  Confirmar: _________

✅ Credenciales cifradas en ~/.pm-workspace/calendar-secrets/
   /sync-calendars para la primera sincronizacion.
```

## Config por usuario

`$HOME/.pm-workspace/calendar-secrets/{slug}/config.json`:
```json
{
  "sync_window_days": 14,
  "sync_block_prefix": "[Sync]",
  "sync_block_show_as": "tentative",
  "auto_sync_on_session_start": false,
  "conflict_notification": "inline",
  "tenants": ["tenant-a", "tenant-b"]
}
```

## Auth flows soportados

| Flow | Pros | Contras | Uso |
|------|------|---------|-----|
| Device Code | Sin redirect URI, funciona en CLI | Requiere navegador 1 vez | Recomendado |
| ROPC | Totalmente automatico | Requiere MFA off, menos seguro | Fallback |
| `az login` | Sin app registration | Requiere Azure CLI | Tenants restrictivos |

## Fallback para tenants restrictivos

Si el tenant corporativo no permite app registrations externas:
1. Usar `az login --tenant {id}` con login interactivo
2. El token se almacena en `~/.azure/` (gestionado por Azure CLI)
3. Savia lee el token de `az account get-access-token --resource https://graph.microsoft.com`
4. Menos automatizado pero funciona en cualquier tenant
