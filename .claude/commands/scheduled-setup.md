---
name: scheduled-setup
description: Wizard interactivo para configurar notificaciones automáticas en plataformas de mensajería
developer_type: pm
agent: task
context_cost: medium
---

# /scheduled-setup

> 🚀 Wizard: Configurar notificaciones automáticas en Telegram, Slack, Teams, WhatsApp o NextCloud Talk

Flujo completo de 5 fases: seleccionar plataforma → credenciales → módulo → tarea → test

---

## Argumentos

`$ARGUMENTS` = nombre de plataforma (opcional)

- Si se proporciona: `telegram|slack|teams|whatsapp|nextcloud` → directamente a credenciales
- Si no se proporciona: mostrar menú interactivo de plataformas

---

## Flujo

### Paso 1 — Seleccionar plataforma (si no se proporcionó)

Banner con 5 opciones:
```
¿Cuál es tu plataforma de notificaciones?

1. 📱 Telegram (⭐⭐ — 5 min)
2. 💬 Slack (⭐⭐ — 5 min)
3. 👔 Microsoft Teams (⭐⭐ — 5 min)
4. 📲 WhatsApp (⭐⭐⭐ — 10 min)
5. ☁️ NextCloud Talk (⭐⭐⭐ — 15 min)

¿Cuál eliges? (1-5):
```

Usuario elige → continuar

### Paso 2 — Credenciales

Mostrar guía específica de plataforma (de `@SKILL.md` Fase 2):
- Pasos claros con ejemplos
- URLs a botones/paneles si aplica
- Campos a rellenar

Usuario proporciona credenciales → guardar en `.env` (nunca hardcoded)

Verificar: intentar pequeño ping a API:
- ✅ Válidas → continuar
- ❌ Inválidas → mostrar error, pedir revisar

### Paso 3 — Generar módulo

Crear `scripts/notify-{platform}.sh` con:
- POST HTTP a plataforma
- Parsing de stdin (recibe salida de comando anterior)
- Formateo de mensajes (markdown donde aplique)
- Manejo de errores (reintentos, timeout)
- Logging a `output/notifications/`

Output: `✅ Módulo generado: scripts/notify-{platform}.sh (145 líneas)`

### Paso 4 — Crear tarea programada

Preguntar: "¿Qué acciones quieres notificar automáticamente?"

Plantillas:
1. **Daily standup** — 09:30 cada día
2. **Blockers alert** — cada 2h si hay bloqueados
3. **Sprint burndown** — viernes 17:00
4. **Deploy notifications** — manual (post-deploy)
5. **Security scan** — cada 24h (medianoche)

Usuario elige → crear entrada en `Claude Code Scheduled Tasks`

### Paso 5 — Test

Enviar test message:
```
✅ [PM-Workspace] Test
Platform: {platform}
Time: {ISO8601}
Status: OK
```

Resultado:
- ✅ Mensaje recibido → guardar configuración, fin exitoso
- ❌ Fallo → mostrar error, pedir revisar credenciales (volver a Paso 2)

---

## Output

Ficheros generados:
- `scripts/notify-{platform}.sh` — módulo notificación
- `.env` — actualizado con credenciales (NUNCA commitear)
- `output/scheduled-messaging/setup-{YYYYMMDD}.log` — resumen

Banner final:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ /scheduled-setup — Completado
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 Plataforma: {platform}
🔧 Módulo: scripts/notify-{platform}.sh
📅 Tareas programadas: {count}
💾 Credenciales guardadas en: .env

Próximos pasos:
  /scheduled-test {platform}
  /scheduled-create --notify {platform} --cron "0 9 * * *"
  /scheduled-list

🔐 IMPORTANTE: Nunca commitear .env a Git
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Restricciones

- Máx 3 reintentos en credenciales antes de cancelar
- Timeout por test: 10 segundos
- Las credenciales NO se almacenan en historial de comandos (seguridad)
