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

Configuración detallada: **→ `messaging-whatsapp.md`**
- Autenticación por QR
- Sesión persistente (~20 días)
- Listener para mensajes de grupo y directos

---

## Nextcloud Talk — Configuración

Integración con Nextcloud Talk vía API REST + webhooks.
Funciona con cualquier instancia de Nextcloud (self-hosted o cloud).

Configuración detallada: **→ `messaging-nextcloud.md`**
- Tokens de aplicación
- Salas del equipo y PM
- Webhooks para listener persistente
- API REST v4 endpoints

---

## Voice Inbox — Transcripción de audio

Transcripción local (Faster-Whisper) — audio NUNCA se envía a servicios externos.

```yaml
WHISPER_MODEL: "small"          # tiny/base/small/medium/large-v3
WHISPER_LANGUAGE: "auto"        # auto (detectar) / es / en / etc.
WHISPER_DEVICE: "cpu"           # cpu o cuda (si GPU disponible)
VOICE_AUTO_EXECUTE: false       # Pedir confirmación antes de ejecutar
VOICE_SAVE_TRANSCRIPTIONS: true # Guardar en inbox/transcriptions/
```

Requisitos: `pip install faster-whisper` + `ffmpeg`

---

## Modos de operación del Inbox

**Modo 1 — Manual**: `/inbox-check` bajo demanda (cero configuración)

**Modo 2 — Background polling**: `/inbox-start --interval N` (revisa cada N min durante sesión)

**Modo 3 — Listener 24/7**: Microservicio systemd/Docker (captura 24/7, procesa en siguiente sesión)

Detalles completos: Documentación en `docs/inbox-modos.md`

---

## Seguridad y privacidad

- **Audio**: se procesa LOCAL con Faster-Whisper, nunca se envía a APIs externas
- **Mensajes**: almacenados en SQLite local (WhatsApp) o ficheros locales (inbox)
- **Credenciales**: tokens y secrets en este fichero, que está en `.claude/rules/` (git-tracked).
  Para datos sensibles, usar variables de entorno o `config.local/` (git-ignored)
- **Confirmación**: por defecto, SIEMPRE se pide confirmación antes de ejecutar un comando
  detectado en un mensaje de voz (configurable con `VOICE_AUTO_EXECUTE`)

---

