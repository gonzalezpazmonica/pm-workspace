# Scheduling Guide — /loop vs /schedule vs Routines vs cron

> Guía para elegir el mecanismo correcto de ejecución programada/recurrente
> en pm-workspace, tras la introducción de Claude Code Routines (2026-04-14).

---

## Los 4 mecanismos

| Mecanismo | Dónde vive | Vida | Mín. intervalo | Triggers |
|-----------|-----------|------|----------------|----------|
| **`/loop` skill** | Sesión Claude Code actual | Mientras la sesión esté abierta | N/A (pacing libre o manual) | Solo cron simple |
| **`/schedule` skill (cloud)** | Servidores Anthropic (remote-trigger) | Persistente cross-sesión | 1 hora | cron, API, eventos |
| **Desktop Scheduled Tasks** | Tu máquina (Desktop app) | Persistente mientras Desktop corra | 1 minuto | cron local |
| **cron del SO** | Sistema operativo | Siempre | 1 minuto | cron |

---

## Cuándo usar cada uno

### `/loop` — Polling dentro de una sesión activa

Usar cuando la tarea solo tiene sentido mientras estás trabajando:
- "Comprueba el build cada 5 min hasta que acabe"
- "Recuérdame en 30 min revisar el PR"
- Polling de estado externo durante una sesión de trabajo

No usar para tareas que deben sobrevivir a cerrar la sesión.

### `/schedule` (cloud) — Rutinas persistentes sin acceso local

Usar cuando:
- La tarea NO necesita ficheros locales ni MCPs locales
- Quieres que corra aunque tu ordenador esté apagado
- Intervalo ≥ 1 hora es aceptable
- Requieres trigger por API o evento (webhook)

Requisito: plan Pro / Max / Team / Enterprise.

Ejemplo típico: informe ejecutivo diario generado desde APIs externas
(Azure DevOps, GitHub) y enviado por Slack.

### Desktop Scheduled Tasks — Rutinas con acceso local

Usar cuando:
- La tarea NECESITA acceder a ficheros locales (datos N3/N4)
- Necesitas MCPs locales (Ollama, bases de datos internas)
- Intervalo < 1 hora
- El ordenador estará encendido durante la ventana de ejecución

Requisito: Desktop app de Claude Code abierta.

Ejemplo típico: digest diario de reuniones en carpetas locales de proyecto.

### cron del SO — Fallback determinista

Usar solo si:
- No puedes depender de Claude Code estando activo
- La tarea es un script puro sin necesidad de LLM
- O la tarea debe correr incluso si la cuenta/sesión caduca

pm-workspace prefiere `/schedule` o Desktop Scheduled Tasks sobre cron del SO
porque mantienen el ciclo completo dentro del ecosistema Claude Code (auditoría,
logs, compactación de contexto).

---

## Árbol de decisión rápido

```
¿La tarea debe sobrevivir a cerrar la sesión?
├─ NO  → /loop
└─ SÍ  → ¿Necesita ficheros o MCPs locales?
         ├─ SÍ → Desktop Scheduled Tasks
         └─ NO → ¿Intervalo <1h o trigger API/evento?
                  ├─ <1h sin API → Desktop Scheduled Tasks
                  └─ ≥1h o API/evento → /schedule (cloud)
```

---

## Relación con comandos de pm-workspace

- `/scheduled-setup` — wizard que configura notificaciones para los 3 modos
- `/scheduled-create` — crea una rutina con `--mode cloud|desktop|session`
  y `--trigger cron|api|event`
- `/scheduled-list` — lista rutinas activas en los 3 backends
- `/scheduled-test` — envía test message via la plataforma configurada

---

## Auto Mode y scheduling

Para rutinas que invoquen modos autónomos (`overnight-sprint`,
`code-improvement-loop`), activar Auto Mode en la sesión o rutina:

- CLI: lanzar con `claude --enable-auto-mode`
- Desktop/VS Code: Settings → Claude Code → Auto Mode

Auto Mode añade un classifier pre-tool-call que bloquea acciones destructivas
sin requerir `--dangerously-skip-permissions`. Es complementario a los gates
de `autonomous-safety.md`, no los sustituye.

---

## Referencias externas

- [Claude Code Scheduled Tasks — docs oficiales](https://code.claude.com/docs/en/scheduled-tasks)
- [Anthropic: Routines announcement (2026-04-14)](https://9to5mac.com/2026/04/14/anthropic-adds-repeatable-routines-feature-to-claude-code-heres-how-it-works/)
- [Anthropic Engineering: Auto Mode](https://www.anthropic.com/engineering/claude-code-auto-mode)
- [Comparativa /schedule vs /loop vs cron — wmedia.es](https://wmedia.es/en/tips/claude-code-schedule-vs-loop-vs-cron)
