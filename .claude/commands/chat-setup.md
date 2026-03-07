---
name: chat-setup
description: Guía de configuración de webhook de Google Chat
---

# /chat-setup

Asistente interactivo para configurar notificaciones de Google Chat.

## Flujo de configuración

1. **Verificar setup actual** — Comprobar si ya existe webhook en `.env`
2. **Recopilación de datos** — Guiar usuario paso a paso:
   - Acceder a espacio de Google Chat
   - Crear webhook entrante (instrucciones clickables)
   - Copiar URL de webhook
3. **Guardar configuración** — Almacenar en `.env`:
   ```
   GOOGLE_CHAT_WEBHOOK_URL=https://chat.googleapis.com/v1/spaces/...
   ```
4. **Validación** — Verificar que webhook es accesible
5. **Mensaje de prueba** — Enviar notificación de prueba al espacio
6. **Confirmación** — Mostrar resultado y próximos pasos

## Banderas

- `--reset` — Reconfigura webhook desde cero
- `--test` — Envía solo mensaje de prueba sin guardar

## Seguridad

- Webhook URL nunca se muestra en logs
- Validación local antes de enviar datos
- Reutiliza URL existente si está ya configurada

## Requisitos previos

- Acceso al espacio de Google Chat
- Permiso para crear webhooks entrantes
