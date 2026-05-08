---
name: pm-radar
description: Radar diario del PM — cruza DevOps, email, calendar, roadmap, chats, digests y produce lista priorizada de pendientes con scoring. Con feedback loop para cerrar/descartar/diferir.
context: Activa cuando el PM pide "radar", "pendientes", "priorities", "qué tengo que hacer", "temas abiertos", "status del día".
argument-hint: "[--refresh-all | --source {devops|email|calendar|all} | --delta | update {id} {action}]"
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
category: pm-operations
priority: high
context_cost: high
max_context_tokens: 12000
output_max_tokens: 2000
---

**Última actualización**: 2026-04-22

# PM Radar

## Objetivo

Producir en <2 min una lista priorizada de pendientes del PM, cruzando 20+ fuentes, con scoring objetivo y feedback loop.

## Invocación

```
/pm-radar                              # refresh completo
/pm-radar --refresh-all                # alias explícito
/pm-radar --source devops|email|calendar|all   # refresh selectivo
/pm-radar --delta                      # solo cambios vs última ejecución
/pm-radar update AB#1234 close         # marca hecho
/pm-radar update EMAIL-abc defer 3d    # difiere
/pm-radar update ROADMAP-1 discard     # descarta
/pm-radar update AB#1234 reprio high   # re-banda
/pm-radar update AB#1234 assign @user  # delega
```

## REGLA INMUTABLE: Always refresh

Cada `/pm-radar` DEBE refrescar todas las fuentes primarias. TTLs son orientativos; invocación explícita = refresh completo.

## Fuentes (20+)

**Correo**: mail-{org1}, mail-{org2}, mail-attachments (SPEC-M01).
**Calendarios**: calendar-{org}-72h (×N orgs), team-vacations (SPEC-V01).
**Teams**: chats-dms, chats-grupos, chat-reuniones, teams-attachments (SPEC-T03), teams-channels (SPEC-T01).
**Transcripciones**: sharepoint-recordings + VTTs (SPEC-S01).
**OneDrive**: recent-files-{org} (SPEC-O01/O02), documentos-local.
**DevOps (read-only)**: PBIs enriched (PAT `$HOME/.azure/{proyecto}-devops-pat`, WIQL Sprint actual + anteriores abiertos, SPEC-R02), pipelines (SPEC-D02), PRs+branches (SPEC-D03), tasks-progress (CompletedWork/OriginalEstimate).
**Repos locales**: git-sweep (SPEC-D01).
**State**: `~/.savia/pm-radar/state.json` (SPEC-P01).
**PM local**: PENDING.md, meetings, decisions, risks, roadmap en `projects/{proyecto}/`.

## Pipeline ejecución

1. **Gate auth**: `scripts/ensure-daemons-auth.sh` (SPEC-SH02). Auto-relanza daemons zombie, polling CDP, espera `status=running`. Aborta solo si tras intento sigue sin auth.
2. **Paralelización**: ~20 agentes narrowscope en paralelo, uno por fuente. JSON con items. Timeout 90s/agente.
3. **Síntesis**: `scripts/radar-synthesizer.py` (SPEC-P04) → `radar-report.json` unificado.
4. **Scoring + state**: `scripts/pm-radar.py` (SPEC-P01). Aplica scoring, bandas, filtros state, detecta inconsistencias. Obligatorio — nunca omitir.
5. **Persistencia**: `projects/{proyecto}/reports/radar/YYYYMMDD-HHMM-{proyecto}-radar.md` + `~/.savia/pm-radar/state.json` atómico.

## Auto-sync outputs

- **PENDING.md auto-update** (SPEC-X01): cerrar items `closed` en state.json; añadir nuevos deferred.
- **PBI drafts locales** (SPEC-Q01): items action=PM sin PBI DevOps >7d → borrador en `projects/{proyecto}/devops-drafts/PBI-XXXX.md` (read-only DevOps preserved).

## Scoring

Ver `references/scoring.md`.

```
score = (urgencia × 3) + (importancia × 3) + (prioridad × 2) + (antigüedad × 2)
```

Bandas: **CRITICO ≥80 · URGENTE 60–79 · IMPORTANTE 40–59 · SEGUIMIENTO <40**.

## Inconsistencias auto-detectadas

- PBI Done en DevOps presente como pendiente en Excel Sprint
- Action item owner=PM sin progreso >7d
- Email sin responder a stakeholder alto >48h laborables
- Compromiso roadmap <14d sin PBI DevOps
- Decisión en `decisions/` sin implementación verificable
- Reunión 24h sin preparación en `digests/`
- PBI con mismo ID en múltiples sprints

## Feedback loop

Estado en `~/.savia/pm-radar/state.json`. Acciones:

| Acción | Efecto |
|--------|--------|
| `close` | Hecho, no reaparece |
| `discard` | No aplica, no reaparece |
| `defer Nd` | Reaparece en N días |
| `reprio {critico\|urgente\|importante\|seguimiento}` | Override banda |
| `assign @handle` | Marca delegado (sigue con badge) |

Update atómico tras cada `update`.

## Output

- Chat: resumen + top 10 (markdown)
- Fichero: `projects/{proyecto}/reports/radar/YYYYMMDD-HHMM-{proyecto}-radar.md` (histórico + offline)

## Read-only DevOps

Azure DevOps SOLO lectura. pm-radar NUNCA escribe/actualiza/crea work items.

## Multi-ejecución mismo día

Segunda+ del día: sección **DELTA** al inicio (nuevos, cerrados, cambios banda). Caches reutilizados si TTL vigente. Estado persistente.

## Anti-patrones

- Inventar deadlines no presentes en la fuente
- Inferir urgencia del tono sin dato objetivo
- Ocultar inconsistencias para reporte "limpio"
- Ejecutar sin refresh de al menos una source primaria
- Perder estado entre ejecuciones
