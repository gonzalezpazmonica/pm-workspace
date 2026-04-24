---
id: SPEC-031
title: SPEC-031: Workspace Doctor — Health Check del Entorno
status: PROPOSED
origin_date: "2026-03-23"
migrated_at: "2026-04-19"
migrated_from: body-prose
priority: media
---

# SPEC-031: Workspace Doctor — Health Check del Entorno

> Status: **DRAFT** · Fecha: 2026-03-23 · Score: 4.40
> Origen: Análisis de malopezr7/jato — comando doctor
> Impacto: Diagnóstico rápido de problemas de configuración

---

## Problema

pm-workspace tiene `session-init.sh` que verifica PAT y perfil al arranque,
y `/health-dashboard` que verifica salud del proyecto. Pero no existe un
health check del propio workspace: settings.json valido, hooks activos,
CLIs disponibles, scripts con permisos, MCPs respondiendo.

Cuando algo falla, el PM no sabe si es un problema de configuración del
entorno o del proyecto. jato resuelve esto con `jato doctor` (8 checks).

## Solución

Crear `/workspace-doctor` que ejecute checks del entorno pm-workspace
y muestre resultado con acciones correctivas.

## Checks (14)

### Críticos (bloquean operación)

| # | Check | Verificacion | Fix sugerido |
|---|-------|-------------|-------------|
| 1 | Git repo | `git rev-parse --is-inside-work-tree` | `git init` |
| 2 | Rama != main | `git branch --show-current` != main | `git checkout -b feat/...` |
| 3 | settings.json válido | JSON parseable | Regenerar desde template |
| 4 | CLAUDE.md existe | Fichero presente | `cp CLAUDE.md.template CLAUDE.md` |
| 5 | CLAUDE.md <= 150 líneas | `wc -l CLAUDE.md` | Refactorizar con @imports |

### Importantes (degradan funcionalidad)

| # | Check | Verificacion | Fix sugerido |
|---|-------|-------------|-------------|
| 6 | PAT Azure DevOps | `test -f $HOME/.azure/devops-pat` | Crear PAT en dev.azure.com |
| 7 | CLI: gh instalado | `which gh` | `sudo apt install gh` |
| 8 | CLI: jq instalado | `which jq` | `sudo apt install jq` |
| 9 | Perfil activo | `active-user.md` tiene slug | `/profile-setup` |
| 10 | Hooks registrados | settings.json tiene hooks[] | Verificar `.claude/settings.json` |

### Recomendados (mejoran experiencia)

| # | Check | Verificacion | Fix sugerido |
|---|-------|-------------|-------------|
| 11 | Scripts ejecutables | `test -x scripts/*.sh` | `chmod +x scripts/*.sh` |
| 12 | Tests BATS pasan | `bash tests/run-all.sh` (rápido) | Corregir tests |
| 13 | CHANGELOG íntegro | Sin marcadores de conflicto | Resolver conflictos |
| 14 | Backup reciente | Último backup < 7 días | `/backup now` |

## Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /workspace-doctor — Health Check
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Críticos .............. 5/5 OK
  Importantes ........... 4/5 (1 warning)
  Recomendados .......... 3/4 (1 info)

  ── Warnings ──────────────────────────
  #8  CLI jq no instalado
      Fix: sudo apt install jq
      Impacto: /sprint-status y otros comandos degradados

  ── Info ──────────────────────────────
  #14 Último backup hace 12 días
      Fix: /backup now

  RESULTADO: 12/14 checks OK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Implementación

1. Crear `.claude/commands/workspace-doctor.md` con los 14 checks
2. Crear `scripts/workspace-doctor.sh` para checks deterministas (bash)
3. El comando orquesta: ejecuta script + interpreta + formatea
4. Opción `--fix` para aplicar fixes automáticos donde sea seguro
5. Opción `--quick` para solo checks críticos (5 checks, <2s)

## Integración

- `session-init.sh` puede sugerir `/workspace-doctor` si detecta anomalía
- `/help` menciona doctor como primer paso ante problemas
- Ejecutar automáticamente tras `/update` (actualización de pm-workspace)

## Esfuerzo estimado

Bajo — 1 día. La mayoría de checks son comandos bash triviales.
