# Anexo: WhatsApp — Configuración Detallada
# ── Autenticación QR, sesión persistente, comportamiento del listener ────────

## Configuración Básica

```yaml
# Autenticación
WHATSAPP_AUTH: "qr"             # Método: "qr" (escanear QR desde el móvil)
WHATSAPP_SESSION_PATH: "~/.whatsapp-mcp/session"  # Sesión persistente (~20 días)

# Contactos/grupos del proyecto
WHATSAPP_PM_CONTACT: "+34612345678"        # Teléfono del PM
WHATSAPP_TEAM_GROUP: "Equipo Sala Reservas" # Grupo del equipo

# Comportamiento
WHATSAPP_NOTIFY_DEFAULT: "pm"   # A quién notificar: "pm", "team", "both"
WHATSAPP_LISTEN_GROUP: true     # Escuchar grupo del equipo
WHATSAPP_LISTEN_DM: true        # Escuchar mensajes directos
```

## Primer Uso

```bash
# 1. Instalar MCP server de WhatsApp
git clone https://github.com/lharries/whatsapp-mcp
cd whatsapp-mcp && go build -o whatsapp-bridge ./cmd/bridge

# 2. Ejecutar bridge (muestra QR para escanear)
./whatsapp-bridge

# 3. Escanear QR con WhatsApp en móvil
#    Ajustes → Dispositivos vinculados → Vincular dispositivo

# 4. Sesión se almacena localmente (~20 días)
```

## MCP Tools

- `search_contacts` — buscar contactos por nombre
- `list_chats` — listar conversaciones recientes
- `list_messages` — mensajes de un chat (con filtro temporal)
- `send_message` — enviar texto a contacto o grupo
- `send_file` — enviar fichero adjunto
- `download_media` — descargar audio, imagen, documento
