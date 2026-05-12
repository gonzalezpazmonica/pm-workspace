# PM Radar Protocol

**Última actualización**: 2026-04-22

## Principio

El PM necesita una foto cruzada de TODOS sus pendientes, priorizada objetivamente, varias veces al día. Sin esto, el PM navega por notificaciones (noise) en lugar de por prioridad (signal).

## Cuándo ejecutar

- **Inicio del día** (antes de 09:00): radar baseline
- **Tras comida** (14:00): radar delta
- **Fin del día** (17:30): cierre + preparación mañana
- **Ad-hoc**: cuando el PM siente que "algo se le escapa"

## Fuentes obligatorias

El radar cruza **20+ fuentes** organizadas en categorías. Ninguna ejecución es válida si fallan simultáneamente las fuentes primarias vivas de una categoría.

### Correo
1. **mail-zenith** — browser-daemon cuenta Zenith Industries (inbox + enviados 48h)
2. **mail-vass** — browser-daemon cuenta VASS (inbox + enviados 48h)
3. **mail-attachments** — adjuntos Excel/PDF/Word digeridos (SPEC-M01)

### Calendarios
4. **calendar-zenith-72h** — eventos Outlook Zenith próximas 72h
5. **calendar-vass-72h** — eventos Outlook VASS próximas 72h
6. **team-vacations** — ausencias y vacaciones del equipo (SPEC-V01)

### Teams
7. **chats-dms** — DMs sin responder de stakeholders altos
8. **chats-grupos** — chats grupales con @menciones o pendientes
9. **chat-reuniones** — chats asociados a reuniones
10. **teams-attachments** — adjuntos compartidos en Teams (SPEC-T03)
11. **teams-channels** — canales con actividad sin leer (SPEC-T01)

### Transcripciones
12. **sharepoint-recordings** — grabaciones SharePoint + VTTs procesados (SPEC-S01)

### OneDrive
13. **recent-files-zenith** — ficheros recientes OneDrive Zenith (SPEC-O01)
14. **recent-files-vass** — ficheros recientes OneDrive VASS personal (SPEC-O02)
15. **documentos-local** — cambios recientes en `Documentos/` local

### DevOps (read-only)
16. **PBIs enriched** — PAT `$HOME/.azure/{proyecto}-devops-pat`, WIQL enriquecido con revisions/history (SPEC-R02)
17. **pipelines** — estado builds/releases últimas 24h (SPEC-D02)
18. **PRs+branches** — PRs asignados/a revisar + ramas activas (SPEC-D03)
19. **tasks-progress** — progreso de tasks vs estimación

### Repos locales
20. **git-sweep** — commits sin push, branches huérfanas, dirty trees (SPEC-D01)

### State
21. **state.json** — `~/.savia/pm-radar/state.json` (SPEC-P01)

### PM local
22. **PENDING.md** — `projects/{proyecto}/<area-monica>/notes/PENDING.md`
23. **meetings** — digests en `projects/{proyecto}/meetings/`
24. **decisions** — `projects/{proyecto}/decisions/`
25. **risks** — `projects/{proyecto}/risks/`
26. **roadmap** — `projects/{proyecto}/roadmap/roadmap-*.md`

Si una fuente falla: reportar explícitamente en el output qué sources están stale. NUNCA fingir tener datos que no se obtuvieron.

## Specs internas del sistema radar

El sistema radar se compone de specs ejecutables cuyo catálogo vive en:

- **`projects/vass_main/specs/GAPS-CATALOG.md`** — catálogo maestro de specs del radar, estado de implementación y dependencias.

Specs principales referenciadas:

| ID | Propósito |
|---|---|
| SPEC-SH02 | Gate auth check + auto-relanzamiento (`scripts/ensure-daemons-auth.sh`, que invoca `check-daemon-auth.sh` y, si falta auth, abre ventana de login por cuenta, auto-detecta fin de login vía CDP y toca SIGNAL). Sólo aborta el radar si tras el intento sigue sin auth. |
| SPEC-P01 | pm-radar.py — scoring, bandas, state.json |
| SPEC-P04 | radar-synthesizer.py — consolidación de outputs paralelos |
| SPEC-M01 | Digestión de adjuntos de email (Excel/PDF/Word) |
| SPEC-V01 | Ausencias y vacaciones del equipo |
| SPEC-T01 | Teams channels con actividad sin leer |
| SPEC-T03 | Teams attachments |
| SPEC-S01 | SharePoint recordings + VTTs |
| SPEC-O01 | OneDrive Zenith recent files |
| SPEC-O02 | OneDrive VASS recent files |
| SPEC-R02 | DevOps PBIs enriched con revisions/history |
| SPEC-D01 | Git sweep repos locales |
| SPEC-D02 | DevOps pipelines |
| SPEC-D03 | DevOps PRs + branches |
| SPEC-X01 | Auto-update PENDING.md tras radar |
| SPEC-Q01 | PBI drafts locales para items action=PM sin PBI |

## Scoring aplicado

Ver `skills/pm-radar/references/scoring.md` para formula completa.

## Inconsistencias (auto-detect)

El radar DEBE flaguear estas inconsistencias sin pedir:
- PBI "Done" DevOps referenciado como pendiente en Excel Sprint
- Action item con owner=PM sin progreso >7d
- Email sin responder a stakeholders altos > 48h laborables
- Reunión próximas 24h sin preparación en digests/briefings
- Compromiso roadmap <14d sin PBI DevOps asignado
- Decisión escrita en decisions/ sin implementación verificable en DevOps
- PBI con mismo ID en múltiples sprints

## State store

Ubicación: `~/.savia/pm-radar/state.json`

Formato:
```json
{
  "items": {
    "ITEM-ID": {
      "id": "AB#1234 o email-hash o decision-id",
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

Antes de mostrar items: filtrar por status. Los closed/discarded NO aparecen. Los deferred solo si defer_until <= hoy.

## Feedback loop

Comando `/pm-radar update {id} {action}`:
- `close` — marcado hecho, no reaparece
- `discard` — no aplica, no reaparece
- `defer {N}d` — reaparece en N días
- `reprio {band}` — override banda
- `assign @x` — marca delegado (sigue apareciendo con badge)

State se actualiza atómicamente.

## Multi-ejecución

Segunda ejecución mismo día:
- Sección DELTA al inicio: nuevos items, cerrados, cambios banda
- Caches reutilizados si TTL vigente
- Solo refresh de sources con TTL expirado

## Persistencia output

Cada run guarda copia en:
`projects/{proyecto}/reports/radar/YYYYMMDD-HHMM-{proyecto}-radar.md`

Para permitir comparación histórica y lectura offline.

## Anti-patrones (prohibidos)

- NUNCA inventar deadlines que no estén en fuente
- NUNCA inferir urgencia desde tono de email sin dato objetivo
- NUNCA ocultar inconsistencias para hacer el reporte "limpio"
- NUNCA ejecutar sin refresh de al menos una source primaria
- NUNCA perder estado entre ejecuciones
