---
name: notify-whatsapp
description: >
  Enviar notificaciones e informes por WhatsApp al PM o al grupo del equipo.
  Funciona con cuenta personal de WhatsApp (no requiere Business).
---

# Notify WhatsApp

**Argumentos:** $ARGUMENTS

> Uso: `/notify-whatsapp {contacto|grupo} {mensaje}` o `/notify-whatsapp --team {msg}`

## Parámetros

- `{contacto}` — Nombre de contacto o número de teléfono
- `{grupo}` — Nombre del grupo de WhatsApp
- `{mensaje}` — Texto a enviar (se puede omitir para enviar último informe generado)
- `--team` — Enviar al grupo del equipo configurado en `messaging-config.md`
- `--pm` — Enviar al contacto del PM (auto-notificación)
- `--file {ruta}` — Adjuntar fichero (PDF, imagen, etc.)
- `--project {nombre}` — Contexto de proyecto (para mensajes automáticos)

## 2. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **Messaging** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/preferences.md`
   - `profiles/users/{slug}/tone.md`
3. Adaptar tono y formalidad según `tone.formality` y `preferences.language`
4. Si no hay perfil → continuar con comportamiento por defecto

## 3. Contexto requerido

1. @.claude/rules/domain/messaging-config.md — Config WhatsApp (WHATSAPP_ENABLED, contactos)
2. MCP WhatsApp configurado y sesión activa

## 4. Pasos de ejecución

### 1. Verificar conexión
- Comprobar que `WHATSAPP_ENABLED = true`
- Verificar sesión activa del bridge WhatsApp
- Si no hay sesión → indicar al PM cómo reconectar (QR code)

### 2. Resolver destinatario
- Si `--team` → usar `WHATSAPP_TEAM_GROUP` de config
- Si `--pm` → usar `WHATSAPP_PM_CONTACT` de config
- Si nombre → MCP: `search_contacts` para resolver número

### 3. Preparar mensaje
- Si se proporciona texto → usar directamente
- Si no → usar último informe generado en `output/`
- Formatear para WhatsApp (markdown simplificado: *bold*, _italic_)
- Truncar si excede 4096 caracteres (límite WhatsApp)

### 4. Enviar
- MCP: `send_message` con contacto/grupo y texto
- Si `--file` → MCP: `send_file` con el adjunto
- **Confirmar con PM antes de enviar** (regla 7)

### 5. Confirmar envío

```
✅ Mensaje enviado por WhatsApp
Destinatario: Grupo "Equipo Sala Reservas" (5 miembros)
Contenido: Resumen sprint 2026-04 (324 chars)
Adjunto: sprint-report.pdf
```

## Ejemplos

```bash
/notify-whatsapp --team "Sprint review mañana a las 10:00"
/notify-whatsapp "Ana García" "El PR #42 necesita tu revisión"
/notify-whatsapp --pm --file output/reports/sprint-report.pdf
/notify-whatsapp --team   # envía último informe generado
```

## Restricciones

- NUNCA enviar sin confirmación del PM
- No enviar datos sensibles (passwords, tokens, secrets)
- Respetar horario laboral configurable (no enviar de noche)
- Requiere bridge WhatsApp con sesión activa
