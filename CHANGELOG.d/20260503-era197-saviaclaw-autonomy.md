## 6.14.1 — Era 197: SaviaClaw Autonomy — monitor + cron + streaming (2026-05-03)

### Added
- SaviaClaw self-monitoring: heartbeat every 120s, auto-restart after 3 failures, stuck task detection (>300s)
- SaviaClaw cron infrastructure: `/cron add/list/remove/run` via Talk, jobs.json persistence
- SaviaClaw streaming feedback: progressive stdout capture with `▸` prefix every 5s during execution
