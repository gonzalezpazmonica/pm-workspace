---
name: google-chat-notifier
description: Enviar notificaciones de PM a espacios de Google Chat mediante webhooks
maturity: stable
category: "communication"
tags: ["google-chat", "webhooks", "notifications", "pm"]
priority: "low"
---

# Google Chat Notifier

Notificador de eventos de PM para Google Chat. Integra webhooks de Google Chat como adaptador de plataforma en el sistema de mensajería programada.

## Configuración

### 1. Crear Webhook en Google Chat

1. Abre el espacio de Google Chat donde deseas recibir notificaciones
2. Haz clic en el nombre del espacio → Aplicaciones y integraciones
3. Busca "Webhooks entrantes" → Crear nueva webhook
4. Nombra la webhook (ej: "PM Workspace Notifier")
5. Copia la URL de la webhook
6. Guarda en `.env` como:
   ```
   GOOGLE_CHAT_WEBHOOK_URL=https://chat.googleapis.com/v1/spaces/...
   ```

## Tipos de Mensaje

### Sprint Status
Estado del sprint: gráfico de burndown, velocidad, items bloqueados y próximas tareas críticas.

### PBI State Changes
Cambios en historias: creada, en progreso, completada con contexto de prioridad y asignado.

### Deployment Notifications
Notificaciones de despliegue: versión, rama, estado (exitoso/fallido), cambios incluidos.

### Escalation Alerts
Alertas de bloqueos: tareas bloqueadas, items vencidos, recursos faltantes, riesgos.

### Daily Standup Summary
Resumen de standup: completado hoy, en progreso, bloqueadores, próximas acciones.

## Formato de Tarjeta

Utiliza el formato de tarjeta nativa de Google Chat para mensajes ricos:

```json
{
  "cardsV2": [{
    "cardId": "unique-id",
    "card": {
      "header": {
        "title": "Título",
        "subtitle": "Subtítulo",
        "imageUrl": "..."
      },
      "sections": [
        {
          "widgets": [
            {"textParagraph": {"text": "..."}},
            {"keyValue": {"topLabel": "Key", "content": "Value"}}
          ]
        }
      ],
      "cardActions": [
        {"actionLabel": "Ver", "onClick": {"openLink": {"url": "..."}}}
      ]
    }
  }]
}
```

## Integración

Funciona como adaptador de plataforma con el skill `scheduled-messaging`. Permite encadenar notificaciones automáticas por eventos de PM o cronogramas.

## Seguridad

- URL de webhook desde `.env` solamente
- No incluir credenciales en logs
- Validar estructura antes de enviar
- Reintentos con backoff exponencial
