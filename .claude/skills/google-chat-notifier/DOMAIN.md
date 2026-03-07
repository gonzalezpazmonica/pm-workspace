---
name: google-chat-notifier
domain: clara-philosophy
---

# Google Chat Notifier — Clara Philosophy

## Propósito

Extender las capacidades de notificación de PM Workspace a Google Chat, permitiendo que equipos reciban alertas contextuales sobre eventos de sprint, despliegues y escalaciones.

## Valores Clara

**Claridad**: Mensajes estructurados en tarjetas con títulos, contexto y llamadas a acción claras.

**Acción**: Integración con webhooks nativos de Google Chat para respuestas inmediatas.

**Responsabilidad**: Notificaciones justas basadas en roles y contexto del proyecto.

## Flujos Principales

### Notificación de Evento
Usuario → Evento de PM → Chat Notifier → Google Chat Webhook → Espacio Team

### Setup Guiado
Usuario ejecuta `/chat-setup` → Valida webhook → Envía mensaje de prueba → Confirma conexión

## Adaptadores

Como adaptador de `scheduled-messaging`:
- Soporta triggers cronológicos
- Integrable con reglas de escalación
- Platform-agnostic para múltiples destinos

## Responsabilidades

- Validar configuración de webhook
- Formatear mensajes según estándar de Google Chat
- Manejar reintentos y errores gracefully
- Respetar límites de rate-limiting
