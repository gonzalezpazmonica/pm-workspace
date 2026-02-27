---
name: retro-actions
description: >
  Seguimiento de action items de retrospectivas entre sprints.
  Ownership, estado y % de implementación.
---

# Retro Actions

**Argumentos:** $ARGUMENTS

> Uso: `/retro:actions --project {p}` o `/retro:actions --project {p} --add`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `--add` — Registrar nuevos action items desde la última retro
- `--update {id}` — Actualizar estado de un action item
- `--sprint {nombre}` — Ver actions de un sprint específico
- `--history` — Historial completo de actions y % implementación

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — Config del proyecto
2. `projects/{proyecto}/retro-actions.md` — Registro de actions (se crea si no existe)

## Pasos de ejecución

### Modo vista (por defecto)
1. **Leer registro** — `projects/{proyecto}/retro-actions.md`
2. **Filtrar actions pendientes** del sprint actual y anteriores
3. **Calcular métricas:**
   - % implementación sprint anterior
   - % implementación acumulado (últimos 5 sprints)
   - Actions más antiguas sin resolver
   - Actions recurrentes (mismo tema en múltiples retros)
4. **Presentar:**

```
## Retro Actions — {proyecto}

### Sprint actual: 3 pendientes, 2 completadas
| ID | Sprint origen | Action | Owner | Estado |
|---|---|---|---|---|
| RA-12 | Sprint 2026-03 | Añadir smoke tests al deploy PRE | Pedro | done |
| RA-13 | Sprint 2026-03 | Documentar API de pagos | Ana | done |
| RA-14 | Sprint 2026-03 | Reducir flaky tests > 5% | Pedro | in progress |
| RA-10 | Sprint 2026-02 | Mejorar onboarding de nuevos devs | María | pending |
| RA-08 | Sprint 2026-01 | Definir política de code review | — | overdue ⚠️ |

### Tendencia de implementación
Sprint 2026-01: 60% (3/5)
Sprint 2026-02: 75% (3/4)
Sprint 2026-03: 40% (2/5) ← en curso
Media: 58%

### Temas recurrentes
- "Testing" mencionado en 3 retros consecutivas → considerar initiative
```

### Modo `--add`
1. Solicitar por cada action: descripción, owner, fecha límite
2. Asignar ID auto-incremental (RA-XX)
3. Añadir al registro

### Modo `--history`
1. Mostrar evolución por sprint: % implementación, temas
2. Identificar patrones recurrentes
3. Sugerir elevación a initiative si un tema aparece 3+ veces

## Integración

- `/sprint:retro` → al final de la retro, invoca `/retro:actions --add`
- `/sprint:status` → muestra actions pendientes como recordatorio
- `/project:audit` → usa % implementación como indicador de mejora continua

## Restricciones

- El registro es markdown local, no Azure DevOps
- Con `--create-pbi` puede crear Tasks en DevOps para actions concretas
- Nunca eliminar actions antiguas, solo marcar como done/cancelled
