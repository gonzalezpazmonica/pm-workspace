# Spec: SaviaClaw Cron Infrastructure — Scheduled Task System

**Task ID:**        SPEC-SE-096-SC-CRON
**PBI padre:**      Era 197 — SaviaClaw Autonomy
**Sprint:**         2026-05
**Fecha creacion:** 2026-05-02
**Creado por:**     Savia (analisis Hermes Agent cron architecture)

**Estimacion agent:** ~60 min
**Prioridad:** CRITICA

---

## Problema

SaviaClaw tiene un schedule hardcodeado en Python (git-status, talk-poll). Mónica quiere
crear tareas programadas ("backup diario a las 22:30") y SaviaClaw no tiene infraestructura
para eso. Hermes Agent tiene un sistema completo: `cron/scheduler.py` + `jobs.json` +
ejecución con logs por job. OpenClaw tiene `CronService` con lanes aisladas.

**Objetivo:** SaviaClaw debe aceptar, persistir y ejecutar tareas programadas definidas
por Mónica via Talk.

## Requisitos

- **REQ-01** `~/.savia/zeroclaw/cron/jobs.json` — almacena tareas programadas:
  ```json
  [{"id": "backup-diario", "schedule": "30 22 * * *", "action": "zip + email memoria",
    "created_by": "monica", "last_run": null, "last_status": null, "enabled": true}]
  ```

- **REQ-02** Comandos via Talk: "/cron list", "/cron add <cron> <descripcion>",
  "/cron remove <id>", "/cron run <id>" — ejecutados por opencode con acceso a tools.

- **REQ-03** `cron_tick()` se ejecuta cada 60s. Evalúa jobs pendientes. Si toca ejecutar uno,
  lanza `opencode run` en thread separado con timeout de 600s.

- **REQ-04** Log por ejecución: `~/.savia/zeroclaw/cron/logs/<job_id>/<timestamp>.json`
  con status (ok/error/timeout), output, duration.

- **REQ-05** Grace window: si un job programado no se ejecutó (SaviaClaw estaba apagado),
  se salta a la siguiente ocurrencia. No se ejecutan jobs atrasados.

- **REQ-06** Jobs son persistentes: sobreviven reinicios del daemon.

## AC

- **AC-01** Mónica: "/cron add 30 22 * * * backup diario: zip memoria + email" → SaviaClaw
  crea el job, confirma con ID.
- **AC-02** A las 22:30, SaviaClaw ejecuta el job y envía resultado por Talk.
- **AC-03** "/cron list" → lista jobs con última ejecución y estado.
- **AC-04** Reinicio del daemon → jobs persisten en `jobs.json`.
