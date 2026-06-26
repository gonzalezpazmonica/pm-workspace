# project-update — Pipeline detallado


### F0 — Auth gate (graceful, per-source granularity)

`scripts/ensure-daemons-auth.sh` re-auth si caducó. Tras el intento, `probe_auth_per_account()` parsea `check-daemon-auth.sh` JSON. Cuentas con `status != running` van a `account_skip`. Solo se omiten los jobs **CDP-dependent** (`sp-recordings`, `onedrive`, `teams-transcripts`); los **saved-session** (`mail`, `calendar`, `teams-chats`) se intentan igual porque las cookies pueden seguir vivas aunque el daemon esté muerto. **NO aborta la run** — devops y todo lo viable continúa. Bypass: `--skip-auth` o `--dry-run`.

### F1 — Refresh paralelo (ThreadPoolExecutor, 8 workers)

| Job | Script | Timeout | Cuántos |
|---|---|---|---|
| `devops` | `scripts/project-update-devops.sh` (wrapper que lee `~/.azure/projects/<file>.json`) | 240s | 1 (slug) |
| `mail-{account}` | `scripts/inbox-check.py` | 90s | × cuentas |
| `calendar-{account}` | `scripts/calendar_72h.py` | 90s | × cuentas |
| `teams-chats-{account}` | `scripts/teams-check.py` | 90s | × cuentas |
| `sp-recordings-{account}` | `scripts/sp-recordings.py --action list` | 120s | × cuentas |
| `onedrive-{account}` | `scripts/onedrive_recent.py` | 120s | × cuentas |
| `teams-transcripts-{account}` | `scripts/extract-teams-transcripts.py --batch` (capturó 8 transcripts en validación 2026-04-24, incluye reuniones no-owner via Teams Recap iframe) | 900s | × cuentas |

Outputs:
- Cada job escribe a su path canónico bajo `~/.savia/project-update-tmp/{slug}/` o `~/.savia/captured-vtt/{account}/`.
- El orquestador captura `rc + elapsed_s + stderr_tail + stdout_preview` por job.

### F2 — Digestión

| Paso | Script | Naturaleza |
|---|---|---|
| Transcript → MD esqueleto | `scripts/meetings_auto_digest.py` | **Determinista basico**. Ingiere `**/*.vtt` y `**/*.transcript.txt` (recap-panel scrolling) recursivamente. Genera digest minimo: speakers, total_lines, preview, tail. NO invoca el agente meeting-digest — eso es manual sobre el fichero fuente cuando se necesita action items / decisiones / riesgos. |

Salida: `projects/{slug}_main/{slug}-monica/meetings/YYYYMMDD-{titulo}.md`.

**Importante**: el digest determinista NO sustituye al agente `meeting-digest`. El agente
produce digests ricos con action items, decisiones y riesgos cruzando con el contexto del
proyecto. Workflow recomendado:
1. F2 ingesta automática genera el esqueleto y deja la nota "Source file: X" + recordatorio.
2. PM revisa la lista de digests nuevos y, para reuniones criticas (1:1, decisiones, kickoffs),
   invoca manualmente el agente con: `Task(meeting-digest, source=<file>)`.
3. El digest enriquecido sobreescribe el esqueleto.

### F3 — Análisis determinista

`scripts/project-update-analyze.py` — pure Python, sin LLM. Lee F1 outputs (`mail.json`, `calendar.json`, `devops-summary.md`, `onedrive.json`, `sharepoint-recordings.json`, `orchestrator-*.json`) y F2 digests (`meetings/*.md`). Produce un radar consolidado:

- `## Sources status` — tabla con auth + counts por fuente
- `## DevOps snapshot` — estado del scan (pasa raw md)
- `## Calendario 72h` — eventos por día
- `## Reuniones digeridas` — listado con counts de action items / decisiones
- `## Action items abiertos (consolidado)` — checkbox items extraídos vía regex de todos los digests, agrupados por reunión origen

Idempotente: misma entrada → misma salida (modulo timestamp). Stub vs rich digests se distinguen automáticamente por count de checkboxes detectados.

Salida: `projects/{slug}_main/{slug}-monica/reports/radar/YYYYMMDD-HHMM-radar.md`.

### F4 — Sync determinista (PENDING.md auto-update)

`scripts/project-update-sync.py` — pure Python, sin LLM. Lee el radar más reciente, extrae action items consolidados, y los append a `PENDING.md` bajo `## Acciones esta semana`. Dedup por texto case-folded — **idempotente**: re-ejecutar añade 0 items. Actualiza la línea `**Última actualización**` al día actual.

Pendiente futuro: briefing del día siguiente + commit a Gitea machine-local.
