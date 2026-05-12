# PM Radar Protocol

**Última actualización**: 2026-04-22

## Principio

El PM necesita una foto cruzada de TODOS sus pendientes, priorizada objetivamente, varias veces al día. Sin esto, navega por notificaciones (noise) en lugar de por prioridad (signal).

## Cuándo ejecutar

- **Inicio día** (antes de 09:00): baseline
- **Tras comida** (14:00): delta
- **Fin del día** (17:30): cierre + preparación mañana
- **Ad-hoc** cuando el PM siente que "algo se le escapa"

## Fuentes obligatorias

El radar cruza **20+ fuentes** organizadas en categorías. Si una fuente primaria viva falla, reportarlo explícito; NUNCA fingir datos no obtenidos.

**Correo**: mail-corp-a, mail-corp-b, mail-attachments (Excel/PDF/Word digeridos SPEC-M01).

**Calendarios**: calendar-corp-a-72h, calendar-corp-b-72h, team-vacations (SPEC-V01).

**Teams**: chats-dms, chats-grupos, chat-reuniones, teams-attachments (SPEC-T03), teams-channels (SPEC-T01).

**Transcripciones**: sharepoint-recordings + VTTs procesados (SPEC-S01).

**OneDrive**: recent-files-corp-a (SPEC-O01), recent-files-corp-b (SPEC-O02), documentos-local.

**DevOps read-only**: PBIs enriched con revisions/history (SPEC-R02), pipelines 24h (SPEC-D02), PRs+branches (SPEC-D03), tasks-progress.

**Repos locales**: git-sweep — commits sin push, branches huérfanas, dirty trees (SPEC-D01).

**State**: `~/.savia/pm-radar/state.json` (SPEC-P01).

**PM local**: PENDING.md por proyecto, meeting digests, decisions/, risks/, roadmap/*.md.

## Specs internas

Catálogo maestro: `projects/{proyecto}/specs/GAPS-CATALOG.md`. Specs principales: SPEC-SH02 (gate auth + auto-relanzamiento), SPEC-P01 (scoring + bandas + state), SPEC-P04 (synthesizer paralelos), SPEC-M01, SPEC-V01, SPEC-T01/T03, SPEC-S01, SPEC-O01/O02, SPEC-R02, SPEC-D01/D02/D03, SPEC-X01 (auto-update PENDING.md), SPEC-Q01 (PBI drafts para action=PM sin PBI).

## Scoring

Ver `skills/pm-radar/references/scoring.md` para fórmula completa.

## Inconsistencias auto-detectadas

PBI "Done" en DevOps referenciado como pendiente en Excel Sprint; action owner=PM sin progreso >7d; email a stakeholder alto sin responder >48h laborables; reunión <24h sin preparación en digests; compromiso roadmap <14d sin PBI asignado; decisión en decisions/ sin implementación verificable; PBI con mismo ID en múltiples sprints.

## State store

`~/.savia/pm-radar/state.json`:

```json
{
  "items": {
    "ITEM-ID": {
      "id": "AB#1234 | email-hash | decision-id",
      "source": "devops|email|calendar|roadmap|digest",
      "first_seen": "ISO8601",
      "last_updated": "ISO8601",
      "status": "active|closed|discarded|deferred",
      "defer_until": "YYYY-MM-DD",
      "reprio_band": "critico|urgente|importante|seguimiento",
      "history": [{"ts": "...", "action": "...", "note": "..."}]
    }
  },
  "runs": [{"ts": "...", "items_count": N, "sources_ok": [...]}]
}
```

Filtrar por status antes de mostrar: closed/discarded ocultos; deferred solo si `defer_until <= hoy`.

## Feedback loop

`/pm-radar update {id} {action}`: `close` (hecho, no reaparece), `discard` (no aplica, no reaparece), `defer {N}d` (reaparece en N días), `reprio {band}` (override banda), `assign @x` (delegado, sigue apareciendo con badge). State se actualiza atómicamente.

## Multi-ejecución

Segunda ejecución mismo día: sección DELTA al inicio (nuevos / cerrados / cambios banda); caches reutilizados si TTL vigente; solo refresh de sources con TTL expirado.

## Persistencia output

Cada run guarda copia en `projects/{proyecto}/reports/radar/YYYYMMDD-HHMM-{proyecto}-radar.md` — permite comparación histórica y lectura offline.

## Anti-patrones

NUNCA: inventar deadlines no presentes en fuente; inferir urgencia desde tono de email sin dato objetivo; ocultar inconsistencias para reportes "limpios"; ejecutar sin refresh de al menos una source primaria; perder estado entre ejecuciones.
