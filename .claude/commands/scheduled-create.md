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
$ARGUMENTS = descripción --notify {platform} --cron "schedule"
```

- `descripción` — descripción de la tarea (ej: "Daily standup summary")
- `--notify {platform}` — plataforma: telegram|slack|teams|whatsapp|nextcloud
- `--cron "schedule"` — cronograma en formato cron (ej: "0 9 * * *" = cada día 09:00)

Ejemplo:
```
/scheduled-create "Daily standup summary" --notify slack --cron "0 9 * * *"
```

---

## Flujo

1. Validar que `scripts/notify-{platform}.sh` existe
2. Crear entrada de tarea programada en Claude Code Scheduled Tasks
3. Configurar step de notificación que capture output + invoque script
4. Guardar configuración en `output/scheduled-tasks/{task-id}.json`
5. Mostrar confirmación con próxima ejecución

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

## Restricciones

- Mínimo cronograma: cada 5 minutos
- Máximo 10 tareas programadas activas simultáneamente
- Si cronograma se ejecutaría <5 min respecto a otra tarea → advertencia (puede sobrecargar)
