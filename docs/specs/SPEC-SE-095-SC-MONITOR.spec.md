# Spec: SaviaClaw Self-Monitoring — Heartbeat + Stuck Detection + Status Reporting

**Task ID:**        SPEC-SE-095-SC-MONITOR
**PBI padre:**      Era 197 — SaviaClaw Autonomy
**Sprint:**         2026-05
**Fecha creacion:** 2026-05-02
**Creado por:**     Savia (analisis Hermes Agent + OpenClaw)

**Estimacion agent:** ~45 min
**Prioridad:** CRITICA

---

## Problema

SaviaClaw no tiene autoconocimiento. Si `opencode run` se cuelga, el hilo muere en silencio.
Si Mónica pregunta "¿estás viva?", la respuesta depende de si el poll loop llegó a ejecutarse.
No hay heartbeat, no hay detección de stuck, no hay reporte de estado entre mensajes.

Hermes Agent usa `_touch_activity()` en cada tool call + `get_activity_summary()` para saber
cuánto lleva inactivo. OpenClaw usa `channel-health-monitor.ts` con heartbeat periódico.

**Objetivo:** SaviaClaw debe saber si está viva, detectar tareas colgadas, y reportar estado
cuando se le pregunta.

## Requisitos

- **REQ-01** `_touch_activity()` se llama en cada evento: mensaje recibido, respuesta enviada,
  tool call de opencode detectado.
- **REQ-02** `get_activity_summary()` retorna dict: `seconds_since_activity`, `last_activity`,
  `current_task`, `pending_threads`, `tick_count`.
- **REQ-03** Cada 120s, si no hay actividad, SaviaClaw verifica que `opencode` siga respondiendo
  con un ping: `opencode run "responde solo: ok"`. Si falla 3 veces seguidas → reinicio
  automático del daemon vía `systemctl restart saviaclaw-headless`.
- **REQ-04** Cuando Mónica pregunta "¿estás bien?" o "¿estás viva?" vía Talk, SaviaClaw
  responde con `get_activity_summary()` en lenguaje natural.
- **REQ-05** Si una tarea async lleva >300s sin terminar → se marca como `stalled` y se notifica
  a Mónica: "La tarea 'crear backup' sigue ejecutándose (X segundos). ¿La cancelo?"
- **REQ-06** El archivo `headless-status.json` se actualiza en cada tick con estado completo,
  visible para OpenCode.

## AC

- **AC-01** "¿Estás viva?" → respuesta con uptime, ticks, última actividad, tareas pendientes.
- **AC-02** Tarea async >300s → mensaje automático de advertencia a Mónica.
- **AC-03** opencode no responde 3 pings → `systemctl restart` automático.
- **AC-04** `headless-status.json` contiene `pending_tasks`, `last_activity_sec`, `stalled_tasks`.
