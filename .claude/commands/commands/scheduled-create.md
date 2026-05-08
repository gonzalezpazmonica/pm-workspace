---
name: scheduled-create
description: Crear tarea programada con notificaciones automáticas
developer_type: pm
agent: task
context_cost: medium
---

# /scheduled-create

> 📅 Crear una tarea programada que envía resultados a plataforma de mensajería

---

## Argumentos

```
$ARGUMENTS = descripción --notify {platform} --trigger {cron|api|event} [--cron "schedule"|--event {evento}]
```

- `descripción` — descripción de la tarea (ej: "Daily standup summary")
- `--notify {platform}` — plataforma: telegram|slack|teams|whatsapp|nextcloud
- `--trigger {tipo}` — tipo de disparador (default: `cron`)
  - `cron` — ejecución programada por horario
  - `api` — ejecución bajo demanda via remote-trigger API (Claude Code Routines, 2026-04-14)
  - `event` — ejecución por evento (webhook entrante, GitHub push, etc.)
- `--cron "schedule"` — cronograma POSIX (requerido si trigger=cron). Mín. 1h cloud, 1m desktop
- `--event {evento}` — nombre del evento (requerido si trigger=event)
- `--mode {cloud|desktop|session}` — dónde corre (default: `desktop`)

Ejemplos:
```
# Cron clásico
/scheduled-create "Daily standup" --notify slack --trigger cron --cron "0 9 * * *"

# API trigger — se invoca desde código o webhook externo
/scheduled-create "On-demand risk report" --notify teams --trigger api --mode cloud

# Event trigger — se dispara por GitHub push a main
/scheduled-create "Deploy notification" --notify slack --trigger event --event "github.push.main"
```

---

## Flujo

1. Validar que `scripts/notify-{platform}.sh` existe
2. Validar argumentos según trigger:
   - `cron` → exigir `--cron`
   - `event` → exigir `--event`
   - `api` → devolver endpoint invocable
3. Crear entrada según trigger:
   - `cron` → Scheduled Tasks (cloud si mode=cloud, Desktop si mode=desktop, /loop si mode=session)
   - `api` → registrar en remote-trigger API, devolver URL invocable
   - `event` → suscribir a event bus (webhook handler)
4. Configurar step de notificación que capture output + invoque script
5. Guardar configuración en `output/scheduled-tasks/{task-id}.json`
6. Mostrar confirmación con la forma de invocación resultante

---

## Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ /scheduled-create — Tarea creada
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📅 Tarea: Daily standup summary
🔔 Notificación: Slack
⏰ Cronograma: 0 9 * * * (diariamente 09:00)
🆔 ID: task-20260307-001
⏱️  Próxima ejecución: 2026-03-08 09:00 UTC

Gestión:
  /scheduled-list
  /scheduled-test slack
  /scheduled-update task-20260307-001 --cron "0 9 * * 1-5"
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Restricciones por trigger

| Trigger | Mín. intervalo | Requisitos | Notas |
|---------|----------------|------------|-------|
| cron + cloud | 1h | Pro/Max/Team/Enterprise | Sin acceso a MCPs locales |
| cron + desktop | 1m | Desktop app abierta | Acceso completo local (N3/N4) |
| cron + session | variable | Sesión activa | Vida corta; usa `/loop` |
| api | — | Token API Claude Code | Invocable por HTTPS |
| event | — | Webhook endpoint configurado | Configurar en `/scheduled-setup` paso 2 |

Límites generales:
- Máximo 10 tareas programadas activas simultáneamente
- Si cronograma se ejecutaría <5 min respecto a otra tarea → advertencia (puede sobrecargar)
