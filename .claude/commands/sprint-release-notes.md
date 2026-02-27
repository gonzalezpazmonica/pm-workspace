---
name: sprint-release-notes
description: >
  Generar release notes automáticas combinando work items completados,
  commits convencionales y PRs mergeados del sprint.
---

# Sprint Release Notes

**Argumentos:** $ARGUMENTS

> Uso: `/sprint:release-notes --project {p}` o `/sprint:release-notes --project {p} --sprint {s}`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `--sprint {nombre}` — Sprint específico (defecto: sprint actual/último cerrado)
- `--format {md|html|slack}` — Formato de salida (defecto: md)
- `--audience {tech|stakeholder|public}` — Nivel de detalle
- `--include-breaking` — Destacar breaking changes
- `--include-metrics` — Añadir métricas del sprint (velocity, etc.)

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — Config del proyecto
2. `.claude/skills/azure-devops-queries/SKILL.md` — Work items completados
3. Acceso al repositorio (GitHub o Azure Repos)

## Pasos de ejecución

### 1. Recopilar datos

**Desde Azure DevOps:**
- PBIs completados (Done) en el sprint → WIQL query
- Bugs resueltos en el sprint
- Tasks completadas (para detalle técnico)

**Desde repositorio:**
- Commits del periodo del sprint (por fecha o tag-to-tag)
- PRs mergeados al main/develop durante el sprint
- Conventional commits parsing: `feat:`, `fix:`, `docs:`, `perf:`, `breaking:`

### 2. Categorizar cambios

| Categoría | Fuente | Icono |
|---|---|---|
| New Features | PBIs tipo Story + commits `feat:` | ✨ |
| Bug Fixes | PBIs tipo Bug + commits `fix:` | 🐛 |
| Improvements | commits `perf:`, `refactor:` | ⚡ |
| Documentation | commits `docs:` | 📚 |
| Breaking Changes | commits `breaking:` + flag manual | ⚠️ |

### 3. Adaptar por audiencia

- **tech**: todos los detalles, PRs, commits, IDs de work items
- **stakeholder**: features y bugs en lenguaje de negocio, sin IDs técnicos
- **public**: solo features visibles al usuario, lenguaje marketing

### 4. Generar documento

```
## Release Notes — {proyecto} — Sprint {n}
Fecha: {fecha fin sprint} | Version: {tag si existe}

### ✨ Nuevas funcionalidades
- **Login con SSO** — Los usuarios pueden iniciar sesión con su cuenta corporativa (#1234)
- **Dashboard de métricas** — Nuevo panel con KPIs en tiempo real (#1240)

### 🐛 Correcciones
- Corregido error 500 al exportar informes en PDF (#1238)
- Solucionado timeout en búsqueda con filtros complejos (#1235)

### ⚡ Mejoras
- Tiempo de carga del dashboard reducido un 40%
- Actualizada librería de componentes UI a v3.2

### ⚠️ Breaking Changes
- API v1 deprecada — migrar a v2 antes del próximo sprint

### 📊 Métricas del sprint (si --include-metrics)
Velocity: 34 SP | Items completados: 8/10 | Bugs resueltos: 3
```

### 5. Guardar y distribuir
- Guardar en `output/release-notes/YYYYMMDD-release-{proyecto}.{ext}`
- Si `--format slack` → enviar via `/notify:slack`
- Si `--format html` → generar HTML con estilos para email

## Integración

- `/sprint:review` → puede invocar release-notes como parte del review
- `/changelog:update` → complementario (changelog = técnico, release notes = negocio)
- `/notify:slack` → distribuir release notes al equipo/stakeholders
- `/confluence:publish` → publicar en Confluence como página de release

## Restricciones

- No publica sin confirmación del PM
- Audiencia `public` omite detalles internos y IDs de Azure DevOps
- Si no hay conventional commits, se basa solo en work items
