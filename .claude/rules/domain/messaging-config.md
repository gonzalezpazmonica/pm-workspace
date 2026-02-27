# Configuración de Mensajería — WhatsApp, Nextcloud Talk e Inbox

Configuración centralizada para todos los canales de mensajería de pm-workspace.
El PM puede activar uno, varios o todos los canales según su entorno.

---

## Canales disponibles

```yaml
# Activar/desactivar canales
WHATSAPP_ENABLED: true          # WhatsApp personal (no requiere Business)
NCTALK_ENABLED: false           # Nextcloud Talk
```

---

## WhatsApp — Configuración

Usa la cuenta personal de WhatsApp del PM (sin necesidad de WhatsApp Business).
Conexión vía API web multidevice (librería whatsmeow). Datos almacenados en SQLite local.

```yaml
# Autenticación
WHATSAPP_AUTH: "qr"             # Método: "qr" (escanear QR desde el móvil)
WHATSAPP_SESSION_PATH: "~/.whatsapp-mcp/session"  # Sesión persistente (~20 días)

# Contactos/grupos del proyecto
WHATSAPP_PM_CONTACT: "+34612345678"        # Teléfono del PM (para notificaciones personales)
WHATSAPP_TEAM_GROUP: "Equipo Sala Reservas" # Nombre del grupo del equipo (para notificaciones de equipo)

# Comportamiento
WHATSAPP_NOTIFY_DEFAULT: "pm"   # A quién notificar por defecto: "pm", "team", "both"
WHATSAPP_LISTEN_GROUP: true     # Escuchar mensajes del grupo del equipo
WHATSAPP_LISTEN_DM: true        # Escuchar mensajes directos al PM
```

### Primer uso

```bash
# 1. Instalar el MCP server de WhatsApp
git clone https://github.com/lharries/whatsapp-mcp
cd whatsapp-mcp && go build -o whatsapp-bridge ./cmd/bridge

# 2. Ejecutar el bridge (muestra QR para escanear)
./whatsapp-bridge

# 3. Escanear el QR con WhatsApp en el móvil
#    (Ajustes → Dispositivos vinculados → Vincular dispositivo)

# 4. La sesión se almacena localmente y persiste ~20 días
```

---

## Nextcloud Talk — Configuración

Integración con Nextcloud Talk vía API REST + sistema de bots webhook.
Funciona con cualquier instancia de Nextcloud (self-hosted o cloud).

```yaml
# Conexión
NCTALK_URL: "https://mi-nextcloud.empresa.com"  # URL de la instancia Nextcloud
NCTALK_USER: "pm-bot"                            # Usuario del bot (o del PM)
NCTALK_TOKEN: ""                                 # Token de app (Ajustes → Seguridad → Tokens de app)

# Salas del proyecto
NCTALK_ROOM_TEAM: "equipo-sala-reservas"   # Token/nombre de la sala del equipo
NCTALK_ROOM_PM: "pm-notifications"         # Sala privada para notificaciones al PM

# Webhook (para Modo 3 — listener persistente)
NCTALK_WEBHOOK_SECRET: ""       # Secret HMAC-SHA256 para verificar webhooks
NCTALK_WEBHOOK_PORT: 8085       # Puerto local del listener
```

### Primer uso

```bash
# 1. Crear un token de app en Nextcloud
#    Ajustes → Seguridad → Dispositivos y sesiones → Crear nuevo token
#    Copiar el token generado → NCTALK_TOKEN

# 2. Obtener el token de la sala
#    Abrir la sala en Nextcloud Talk → la URL contiene el token:
#    https://mi-nextcloud.com/call/abc123def → token = "abc123def"

# 3. (Opcional) Registrar bot webhook para Modo 3
#    Solo necesario si se quiere listener persistente (ver Modo 3 abajo)
```

---

## Voice Inbox — Transcripción de audio

Transcripción local de mensajes de voz con Faster-Whisper.
El audio NUNCA se envía a servicios externos — todo se procesa en local.

```yaml
# Transcripción
WHISPER_MODEL: "small"          # Modelo: tiny, base, small, medium, large-v3
WHISPER_LANGUAGE: "auto"        # Idioma: "auto" (detectar), "es", "en", etc.
WHISPER_DEVICE: "cpu"           # Dispositivo: "cpu" o "cuda" (si hay GPU)

# Comportamiento
VOICE_AUTO_EXECUTE: false       # true = ejecutar comando sin confirmar (solo si confianza alta)
VOICE_SAVE_TRANSCRIPTIONS: true # Guardar transcripciones en inbox/transcriptions/
```

### Instalación

```bash
# Transcriptor
pip install faster-whisper --break-system-packages

# Conversor de audio (necesario para algunos formatos)
sudo apt install ffmpeg    # Linux
brew install ffmpeg         # macOS
```

---

## Modos de operación del Inbox

### Modo 1 — Manual (sin infraestructura)

El PM ejecuta `/inbox:check` cuando quiere ver si hay mensajes nuevos.

```
PM: /inbox:check
→ Revisando WhatsApp... 3 mensajes nuevos (1 audio)
→ Revisando Nextcloud Talk... 0 mensajes nuevos
→
→ 📩 WhatsApp — Grupo "Equipo Sala Reservas":
→   [10:15] Ana García: "¿Podemos adelantar la review a jueves?"
→   [10:22] Pedro López: "Por mí bien, pero falta revisar el PR #42"
→   [10:30] Ana García: 🎤 Audio (12s) → Transcripción:
→     "Oye, ¿puedes ponerme el estado del sprint? Que no me da tiempo a mirarlo"
→     → Comando sugerido: /sprint:status --project sala-reservas
→     → ¿Ejecutar? (s/n)
```

**Cuándo usar**: PMs que abren Claude Code puntualmente. Cero configuración extra.

### Modo 2 — Background polling (sesión activa)

Al iniciar sesión, el PM lanza `/inbox:start` y un proceso en background
revisa los canales cada N minutos mientras la sesión esté abierta.

```
PM: /inbox:start --interval 5
→ ✅ Inbox monitor iniciado (cada 5 min)
→ Canales activos: WhatsApp ✅, Nextcloud Talk ✅
→ Task ID: bg-inbox-7a3f (ver con /tasks)
→
→ ... el PM trabaja normalmente ...
→
→ 📩 [11:45] Nuevo mensaje de voz en WhatsApp:
→   Ana García: 🎤 Audio (8s) → "Descompón el PBI 1234 en tareas"
→   → Comando sugerido: /pbi:decompose 1234
→   → ¿Ejecutar? (s/n)
```

**Cuándo usar**: PMs que mantienen Claude Code abierto durante la jornada.
El proceso se detiene automáticamente al cerrar la sesión.

```
PM: /inbox:start                    # Iniciar con intervalo por defecto (5 min)
PM: /inbox:start --interval 2      # Revisar cada 2 minutos
PM: /inbox:start --channels wa      # Solo WhatsApp
PM: /inbox:start --channels nctalk  # Solo Nextcloud Talk
```

### Modo 3 — Listener persistente (24/7)

Un microservicio que corre como daemon, escuchando webhooks y polling.
Encola mensajes en `inbox/pending.json` para que `/inbox:check` los lea.

```bash
# Opción A: Script Python como servicio systemd
sudo cp scripts/inbox-listener.py /opt/pm-workspace/
sudo cp scripts/inbox-listener.service /etc/systemd/system/
sudo systemctl enable --now inbox-listener

# Opción B: Docker
docker run -d --name pm-inbox \
  -v ~/.whatsapp-mcp:/data/whatsapp \
  -v ./inbox:/data/inbox \
  -e NCTALK_WEBHOOK_PORT=8085 \
  pm-workspace/inbox-listener
```

**Cuándo usar**: Empresas que quieren captura de mensajes 24/7,
incluso cuando el PM no tiene Claude Code abierto.
Los mensajes se acumulan y se procesan en la siguiente sesión.

```
PM: /inbox:check
→ 📬 12 mensajes acumulados desde 2026-02-27 18:00
→   WhatsApp: 8 mensajes (2 audios)
→   Nextcloud Talk: 4 mensajes (0 audios)
→
→ 🎤 Audio 1 (Ana, 10:15): "El cliente quiere cambiar el alcance del sprint"
→   → No mapea a comando → archivado como nota informativa
→
→ 🎤 Audio 2 (Pedro, 14:30): "Hazme un report de horas del proyecto"
→   → Comando sugerido: /report:hours --project sala-reservas
→   → ¿Ejecutar? (s/n)
```

---

## Seguridad y privacidad

- **Audio**: se procesa LOCAL con Faster-Whisper, nunca se envía a APIs externas
- **Mensajes**: almacenados en SQLite local (WhatsApp) o ficheros locales (inbox)
- **Credenciales**: tokens y secrets en este fichero, que está en `.claude/rules/` (git-tracked).
  Para datos sensibles, usar variables de entorno o `config.local/` (git-ignored)
- **Confirmación**: por defecto, SIEMPRE se pide confirmación antes de ejecutar un comando
  detectado en un mensaje de voz (configurable con `VOICE_AUTO_EXECUTE`)

---

## Referencia MCP

### WhatsApp (whatsapp-mcp — lharries)
- `search_contacts` — buscar contactos por nombre
- `list_chats` — listar conversaciones recientes
- `list_messages` — mensajes de un chat (con filtro temporal)
- `send_message` — enviar texto a contacto o grupo
- `send_file` — enviar fichero adjunto
- `download_media` — descargar audio, imagen, documento recibido

### Nextcloud Talk (API REST v4)
- `GET /ocs/v2.php/apps/spreed/api/v4/room` — listar salas
- `GET /ocs/v2.php/apps/spreed/api/v4/chat/{token}` — mensajes de una sala
- `POST /ocs/v2.php/apps/spreed/api/v4/chat/{token}` — enviar mensaje
- `GET /ocs/v2.php/apps/spreed/api/v4/chat/{token}/{messageId}/share` — descargar adjunto
- Webhooks bot: `POST /bot/{token}/message` (requiere bots-v1 capability)
