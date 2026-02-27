# Anexo: Nextcloud Talk — Configuración Detallada
# ── API REST v4, webhooks, salas, tokens de aplicación ────────────────────

## Configuración Básica

```yaml
# Conexión
NCTALK_URL: "https://mi-nextcloud.empresa.com"  # URL instancia Nextcloud
NCTALK_USER: "pm-bot"                            # Usuario del bot
NCTALK_TOKEN: ""                                 # Token app (Ajustes → Seguridad)

# Salas del proyecto
NCTALK_ROOM_TEAM: "equipo-sala-reservas"   # Token sala del equipo
NCTALK_ROOM_PM: "pm-notifications"         # Sala privada PM

# Webhook (para listener persistente)
NCTALK_WEBHOOK_SECRET: ""       # Secret HMAC-SHA256 para verificar
NCTALK_WEBHOOK_PORT: 8085       # Puerto local del listener
```

## Primer Uso

```bash
# 1. Crear token de app en Nextcloud
#    Ajustes → Seguridad → Dispositivos y sesiones → Crear nuevo token
#    Copiar el token → NCTALK_TOKEN

# 2. Obtener token de la sala
#    Abrir sala en Nextcloud Talk → la URL contiene el token:
#    https://mi-nextcloud.com/call/abc123def → token = "abc123def"

# 3. (Opcional) Registrar bot webhook para listener persistente
#    Solo si se quiere listener 24/7
```

## API REST v4

- `GET /ocs/v2.php/apps/spreed/api/v4/room` — listar salas
- `GET /ocs/v2.php/apps/spreed/api/v4/chat/{token}` — mensajes sala
- `POST /ocs/v2.php/apps/spreed/api/v4/chat/{token}` — enviar mensaje
- `GET /ocs/v2.php/apps/spreed/api/v4/chat/{token}/{messageId}/share` — descargar
- Webhooks bot: `POST /bot/{token}/message` (requiere bots-v1 capability)
