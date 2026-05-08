---
name: chat-notify
description: Enviar notificación formateada a Google Chat
argument-hint: "[type] [project]"
---

# /chat-notify

Enviar notificación de evento de PM a Google Chat con formato de tarjeta.

## Parámetros

`$ARGUMENTS`:
- `type` (requerido): Tipo de notificación
  - `sprint-status` — Estado del sprint (burndown, velocidad, bloqueadores)
  - `deployment` — Notificación de despliegue
  - `escalation` — Alertas de bloqueo o retraso
  - `standup` — Resumen de standup diario
  - `custom` — Mensaje personalizado
- `project` (requerido): Nombre del proyecto (ej: pm-workspace, sala-reservas)

## Opciones

- `--message "texto"` — Contenido personalizado (si type es custom)
- `--emoji ":rocket:"` — Emoji adicional para el mensaje

## Flujo

1. Validar webhook URL en `.env` (`GOOGLE_CHAT_WEBHOOK_URL`)
2. Recopilar datos según tipo de notificación
3. Formatear tarjeta con estándar Google Chat
4. Enviar vía POST a webhook
5. Mostrar confirmación con timestamp

## Ejemplos

**✅ Correcto:**
```
/chat-notify sprint-status pm-workspace
→ Envía estado actual del sprint a Google Chat
→ Confirmación: "✅ Notificación enviada a 09:15"
```

**❌ Incorrecto:**
```
/chat-notify invalid-type pm-workspace
→ Error: Tipo no reconocido. Usa: sprint-status, deployment, escalation, standup, custom
```

## Requisitos previos

- Webhook configurada: `/chat-setup`
- Proyecto válido en `CLAUDE.md`
