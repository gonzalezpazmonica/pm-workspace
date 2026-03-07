---
name: scheduled-list
description: Listar todas las tareas programadas y su configuración de notificaciones
developer_type: pm
agent: task
context_cost: low
---

# /scheduled-list

> 📋 Ver todas las tareas programadas, cronogramas y plataformas de notificación

---

## Argumentos

Ninguno (opcional: `--verbose` para detalles completos)

---

## Flujo

1. Leer `output/scheduled-tasks.log` y `output/scheduled-tasks/*.json`
2. Construir tabla con: ID, descripción, cronograma, plataforma, última ejecución, próxima ejecución, estado
3. Mostrar resumen de ejecuciones recientes (últimos 7 días)

---

## Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 Tareas Programadas (3 activas)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

| ID | Descripción | Cron | Notif. | Última ejecución | Próxima | Estado |
|----|-------------|------|--------|------------------|---------|--------|
| 1 | Daily standup | 0 9 * * * | Slack | 2026-03-07 09:00 | 2026-03-08 09:00 | ✅ OK |
| 2 | Blocker alert | */2 * * * * | Telegram | 2026-03-07 16:00 | 2026-03-07 18:00 | ✅ OK |
| 3 | Deploy notify | manual | Teams | 2026-03-05 14:32 | (manual) | ✅ Ready |

Ejecuciones últimas 7 días:
  ✅ 15 exitosas
  ⚠️  2 con avisos
  ❌ 0 fallidas

Sugerencias:
  /scheduled-test {platform} — test específico
  /scheduled-update {task-id} --cron "..." — actualizar
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Modo Verbose

Con `--verbose`:
- Mostrar payload completo de cada tarea
- Últimas 5 ejecuciones detalladas (timestamp, duración, resultado)
- Logs de error si las hay
