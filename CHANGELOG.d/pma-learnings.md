---
version_bump: minor
section: Added
---

### Added (SE-347 — lecciones PMA incorporadas)

- `scripts/savia-goals.sh` — goals durables con presupuesto (tokens/wall-clock)
  y `complete` como único final válido + heartbeats claimed-due (sin replay
  tras crash, coalescing de ticks perdidos). Ledger local en `~/.savia/goals`.
- `scripts/agent-messaging.sh` — bus de mensajería local agente→agente con
  roles (parent/child/steer/follow_up) y receipts (queued→delivered→read),
  broadcast y ack. Colas JSONL en `~/.savia/msg`.
- `scripts/parallel-dispatch.sh` — despacho paralelo con admission-handle:
  launch devuelve el id al instante, status/collect agregan resultados. Jobs
  en `~/.savia/dispatch`.
- `scripts/session-state-snapshot.sh` — snapshot de estado de sesión
  (git_state + label) para recuperación.
- Skills `parallel-dispatch` y `agent-messaging` (wrappers de los scripts) y
  template `_template_python` (skills Python-backed con `run()`).
- Regla `docs/rules/domain/mcp-security.md` — secrets MCP solo por env-var,
  precedencia proyecto-vs-usuario, tool allowlist.
- Skills actualizados con patrones PMA: formato estructurado de compactación
  (context-rot-strategy), goals/heartbeats claimed-due (automation-scheduler),
  feedback acotado de gates (overnight-sprint), convención Python-backed
  (write-a-skill).

### Fixed

- `block-pat-file-write.sh`: el patrón `*pat*` producía falsos positivos sobre
  substrings (`parallel-dispatch`, `compat*.sh`). Ahora solo bloquea tokens
  PAT (`pat`, `pat.*`, `*-pat`, `*_pat`). (Descubierto al implementar
  parallel-dispatch.)
