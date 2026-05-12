---
name: github-activity
description: >
  Analizar actividad de un repositorio GitHub: PRs, commits, contributors.
  Usa el conector GitHub de Claude para acceso enriquecido.
---

# Actividad GitHub

**Argumentos:** $ARGUMENTS

> Uso: `/github-activity {repo} [--since {fecha}] [--author {usuario}]`

## Parámetros

- `{repo}` — Repositorio en formato `org/repo` o solo `repo` (usa GITHUB_DEFAULT_ORG)
- `--since {fecha}` — Actividad desde esta fecha (default: inicio del sprint actual)
- `--author {usuario}` — Filtrar por contributor específico
- `--project {nombre}` — Usar el repo configurado en `projects/{p}/CLAUDE.md` (campo `GITHUB_REPO`)
- `--team` — Mostrar actividad de todos los miembros del equipo (cruza con `equipo.md`)

## Contexto requerido

1. `docs/rules/domain/connectors-config.md` — Verificar conector GitHub habilitado
2. `projects/{proyecto}/CLAUDE.md` — Repo del proyecto
3. `projects/{proyecto}/equipo.md` — Usernames GitHub del equipo (si `--team`)

## Pasos de ejecución

1. **Verificar conector** — Comprobar que el conector GitHub está disponible

2. **Resolver repo**:
   - Si se pasa `{repo}` → usar directamente
   - Si `--project` → buscar `GITHUB_REPO` en CLAUDE.md del proyecto
   - Si ninguno → preguntar

3. **Obtener datos** via conector MCP de GitHub:
   - PRs abiertas, mergeadas y cerradas en el periodo
   - Commits por autor
   - Reviews realizadas
   - Issues creados/cerrados

4. **Si `--team`** → cruzar con `equipo.md`:
   - Mapear nombres Azure DevOps ↔ usernames GitHub
   - Mostrar actividad por persona del equipo

5. **Presentar informe**:
   ```
   📊 Actividad GitHub — {repo}
   Periodo: {desde} → {hasta}

   PRs:     {N} abiertas · {N} mergeadas · {N} cerradas
   Commits: {N} total ({N} autores)
   Reviews: {N} aprobadas · {N} con cambios · {N} pendientes

   👥 Por contributor:
   ┌──────────────┬─────────┬────────┬─────────┬──────────┐
   │ Contributor   │ Commits │ PRs    │ Reviews │ +/- LOC  │
   ├──────────────┼─────────┼────────┼─────────┼──────────┤
   │ @maria        │ 12      │ 3 PR   │ 5 rev   │ +340/-120│
   │ @carlos       │ 8       │ 2 PR   │ 3 rev   │ +210/-80 │
   └──────────────┴─────────┴────────┴─────────┴──────────┘
   ```

## Integración con otros comandos

- `/team-workload` puede invocar este comando para añadir métricas de código
- `/team-evaluate` usa estos datos como input para evaluación técnica
- `/sprint-status` puede incluir sección "Actividad de código" con estos datos
- `/kpi-dashboard` puede mostrar métricas de PR lead time y review time

## Restricciones

- Solo lectura — no modifica repos, PRs ni issues
- No mostrar código fuente en el informe (solo métricas)
- Respetar repos privados — el conector gestiona permisos OAuth
