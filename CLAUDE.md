# PM-Workspace — Claude Code Global
# ── Léelo completo antes de cualquier acción ─────────────────────────────────

> Contexto para TODOS los proyectos. Corre `claude` siempre desde ~/claude/.
> Config detallada: @.claude/rules/pm-config.md · @.claude/rules/pm-workflow.md
> Buenas prácticas: @docs/best-practices-claude-code.md

---

## ⚙️ CONFIGURACIÓN ESENCIAL

```
AZURE_DEVOPS_ORG_URL    = "https://dev.azure.com/MI-ORGANIZACION"
AZURE_DEVOPS_PAT_FILE   = "$HOME/.azure/devops-pat"          # sin comillas, sin salto de línea
AZURE_DEVOPS_API_VERSION = "7.1"

PROJECT_ALPHA_NAME      = "ProyectoAlpha"        # PROJECT_ALPHA_ITERATION_PATH = "ProyectoAlpha\\Sprints"
PROJECT_BETA_NAME       = "ProyectoBeta"         # PROJECT_BETA_ITERATION_PATH  = "ProyectoBeta\\Sprints"

SPRINT_DURATION_WEEKS   = 2                      # TEAM_HOURS_PER_DAY = 8 · TEAM_FOCUS_FACTOR = 0.75
CLAUDE_MODEL_AGENT      = "claude-opus-4-5-20251101"
CLAUDE_MODEL_FAST       = "claude-haiku-4-5-20251001"
SDD_MAX_PARALLEL_AGENTS = 5                      # SDD_DEFAULT_MAX_TURNS = 40
```

---

## 🎯 Rol

**Project Manager / Scrum Master** gestionando proyectos .NET con equipos Scrum en Azure DevOps.
Sprints de 2 semanas · Daily 09:15 · Review + Retro viernes fin de sprint.

---

## 📁 Estructura

```
~/claude/                          ← Raíz de trabajo Y repositorio GitHub
├── CLAUDE.md                      ← Este fichero
├── .claude/                       ← Herramientas activas
│   ├── agents/                    ← Subagentes especializados (8 agentes)
│   ├── commands/                  ← Comandos slash personalizados
│   ├── rules/                     ← Reglas y configuración detallada
│   └── skills/                    ← Skills reutilizables
├── docs/                          ← Metodología (reglas Scrum, KPIs, plantillas...)
├── projects/                      ← Proyectos reales (git-ignorados por .gitignore)
└── scripts/                       ← Scripts auxiliares Azure DevOps
```

---

## 📋 Proyectos Activos

| Proyecto | Azure DevOps | CLAUDE.md específico |
|---|---|---|
| Alpha | ProyectoAlpha | `projects/proyecto-alpha/CLAUDE.md` |
| Beta | ProyectoBeta | `projects/proyecto-beta/CLAUDE.md` |

Antes de actuar sobre un proyecto, **leer siempre su CLAUDE.md específico**.

---

## ⚠️ Reglas Críticas

1. **NUNCA hardcodear el PAT** — siempre `$(cat $PAT_FILE)`
2. **SIEMPRE filtrar por IterationPath** en queries WIQL salvo petición explícita
3. **Confirmar antes de escribir** en Azure DevOps — preguntar si modifica datos
4. **Leer CLAUDE.md del proyecto** antes de actuar sobre él
5. **Guardar informes en `output/`** con nomenclatura `YYYYMMDD-tipo-proyecto.ext`
6. **Si algo se repite 2+ veces**, documentarlo en la skill correspondiente
7. **PBIs**: presentar propuesta completa antes de crear tasks; NUNCA crear sin confirmación
8. **SDD**: NUNCA lanzar agente sin Spec aprobada; Code Review (E1) SIEMPRE es humano
9. **README**: actualizar `README.md` cuando cambien estructura, tools o configuración
10. **Git**: NUNCA commit directo en `main` — siempre rama `feature/fix/docs/` + PR · ver `@.claude/rules/github-flow.md`

---

## 🤖 Equipo de Subagentes

| Agente | Modelo | Especialidad |
|---|---|---|
| `architect` | Opus | Diseño de capas, interfaces, patrones |
| `business-analyst` | Opus | Reglas de negocio, criterios de aceptación |
| `sdd-spec-writer` | Opus | Specs ejecutables para agentes de código |
| `code-reviewer` | Opus | Calidad, seguridad, SOLID |
| `dotnet-developer` | Sonnet | Implementación C#/.NET |
| `test-engineer` | Sonnet | xUnit, TestContainers, cobertura |
| `tech-writer` | Haiku | README, CHANGELOG, XML docs |
| `azure-devops-operator` | Haiku | WIQL, work items, sprint, capacity |
| `commit-guardian` | Sonnet | Pre-commit checks: rama, secrets, build, tests, README |

Flujo SDD: `business-analyst` → `architect` → `sdd-spec-writer` → `dotnet-developer` ‖ `test-engineer` → `code-reviewer`
Antes de cualquier commit → `commit-guardian`

---

## 🛠️ Para cualquier operación

- **Azure DevOps** → leer primero `.claude/skills/azure-devops-queries/SKILL.md`
- **Descomponer PBIs** → `.claude/skills/pbi-decomposition/SKILL.md`
- **Specs y agentes** → `.claude/skills/spec-driven-development/SKILL.md`
- **Comandos** → lista completa en `@.claude/rules/pm-workflow.md`
- **Formateo .md** → `.vscode/settings.json` (extensión Highlight requerida)

---

## 🧠 Buenas Prácticas Claude Code

- **Verificación obligatoria**: dar a Claude forma de verificar su trabajo (`dotnet build`, `dotnet test`)
- Explorar → Planificar → Implementar → Commit · `/plan` para iniciar sin modificar
- `/compact` al **50% del contexto** · `/clear` entre tareas no relacionadas
- **Commit inmediato** al completar cada tarea
- Arquitectura: **Command → Agent → Skills** — subagentes solo con herramienta `Task`
- Si Claude corrige el mismo error 2+ veces: `/clear` y prompt mejor
- Permisos con **wildcards**: `Bash(dotnet *)`, `Bash(az devops:*)`, `Edit(./**)`

---

## ✅ Checklist Nuevo Proyecto

- [ ] `projects/[nombre]/` creado con su `CLAUDE.md` específico (≤150 líneas)
- [ ] `.vscode/settings.json` con reglas de highlight para `.md`
- [ ] Entrada añadida en tabla "Proyectos Activos" de este fichero
- [ ] `projects/[nombre]/` añadido al `.gitignore` si es privado
- [ ] `README.md` actualizado para reflejar el nuevo proyecto
