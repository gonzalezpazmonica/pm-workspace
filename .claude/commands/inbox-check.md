---
name: inbox-check
description: >
  Revisar mensajes nuevos en todos los canales de mensajería.
  Transcribir audios, interpretar peticiones y proponer acciones.
---

# Inbox Check

**Argumentos:** $ARGUMENTS

> Uso: `/inbox:check` o `/inbox:check --channels wa` o `/inbox:check --since {fecha}`

## Parámetros

- `--channels {wa|nctalk|all}` — Canales a revisar (defecto: todos los activos)
- `--since {fecha|last}` — Desde cuándo (defecto: último check, o 24h si es primera vez)
- `--audio-only` — Solo procesar mensajes de audio
- `--no-transcribe` — No transcribir audios (solo listar)
- `--project {nombre}` — Filtrar mensajes relacionados con un proyecto

## Contexto requerido

1. @.claude/rules/domain/messaging-config.md — Config canales activos
2. `.claude/skills/voice-inbox/SKILL.md` — Transcripción de audio
3. MCP de WhatsApp y/o API de Nextcloud Talk según canales activos

## Pasos de ejecución

### 1. Determinar ventana temporal
- Leer `inbox/last-check.txt` → timestamp del último check
- Si no existe → usar últimas 24 horas
- Si `--since {fecha}` → usar esa fecha

### 2. Recopilar mensajes nuevos

**WhatsApp (si habilitado):**
- MCP: `list_chats` → chats con mensajes nuevos
- MCP: `list_messages` con filtro desde último check
- Separar: textos, audios, imágenes, documentos

**Nextcloud Talk (si habilitado):**
- API: `GET /chat/{token}?lookIntoFuture=0&lastKnownMessageId={id}`
- Separar: textos, audios, ficheros compartidos

**Inbox local (Modo 3):**
- Leer `inbox/pending.json` si existe (mensajes del listener)

### 3. Procesar audios

Para cada mensaje de audio:
1. Descargar: MCP `download_media` (WhatsApp) o API share (NCTalk)
2. Convertir si necesario: `ffmpeg -i input.ogg -ar 16000 -ac 1 output.wav`
3. Transcribir: Faster-Whisper con modelo configurado
4. Interpretar: mapear texto a comando de pm-workspace
5. Clasificar confianza: alta / media / baja

### 4. Presentar resumen

```
## 📬 Inbox Check — 2026-02-27 11:00
Último check: 2026-02-27 09:00 (hace 2h)

### WhatsApp — 5 mensajes nuevos (1 audio)
Grupo "Equipo Sala Reservas":
  [09:15] Ana García: "¿Podemos adelantar la review a jueves?"
  [09:22] Pedro López: "Por mí bien, si el PM confirma"
  [10:30] Ana García: 🎤 Audio (12s):
    📝 "Ponme el estado del sprint de sala reservas, porfa"
    → /sprint:status --project sala-reservas [confianza: alta]
    → ¿Ejecutar? (s/n)

Chat "Carlos Sanz":
  [10:45] Carlos: "Los tests de integración ya pasan todos"
  [10:46] Carlos: 📎 test-results.png

### Nextcloud Talk — 2 mensajes nuevos
Sala "equipo-sala-reservas":
  [09:30] María Ruiz: "He subido los mockups al Drive"
  [10:00] Pedro López: "Revisado, falta el flujo de error"

### Resumen de acciones pendientes
1. 🎤 Ejecutar /sprint:status --project sala-reservas (Ana, WhatsApp)
2. 💬 Ana pregunta adelantar review → requiere decisión del PM
3. ℹ️ Carlos confirma tests OK → informativo
```

### 5. Actualizar timestamp
- Guardar timestamp actual en `inbox/last-check.txt`
- Guardar transcripciones en `inbox/transcriptions/` (si configurado)

## Integración

- `/inbox:start` → lanza inbox:check en background cada N minutos
- `/context:load` → puede invocar inbox:check al inicio de sesión
- `/notify:whatsapp` y `/notify:nctalk` → responder a mensajes encontrados
- Skill `voice-inbox` → lógica de transcripción y mapeo voz→comando

## Restricciones

- Comandos detectados en audio SIEMPRE requieren confirmación del PM
  (salvo `VOICE_AUTO_EXECUTE = true` con confianza alta)
- No responde automáticamente a mensajes — solo informa al PM
- Audio se procesa local (Faster-Whisper), nunca en APIs externas
