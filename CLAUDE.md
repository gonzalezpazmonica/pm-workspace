# PM-Workspace — Claude Code Global
# ── Léelo completo antes de cualquier acción ─────────────────────────────────

> Contexto para TODOS los proyectos. Corre `claude` siempre desde ~/claude/.
> Config detallada: @.claude/rules/pm-config.md · @.claude/rules/pm-workflow.md
> Proyectos privados: @.claude/rules/pm-config.local.md (git-ignorado, no en este repo)
> Buenas prácticas: @docs/best-practices-claude-code.md

---

## ⚙️ CONFIGURACIÓN ESENCIAL

```
AZURE_DEVOPS_ORG_URL    = "https://dev.azure.com/MI-ORGANIZACION"
AZURE_DEVOPS_PAT_FILE   = "$HOME/.azure/devops-pat"          # sin comillas, sin salto de línea
AZURE_DEVOPS_API_VERSION = "7.1"

# Proyectos activos → ver pm-config.local.md (git-ignorado)

SPRINT_DURATION_WEEKS   = 2                      # TEAM_HOURS_PER_DAY = 8 · TEAM_FOCUS_FACTOR = 0.75
CLAUDE_MODEL_AGENT      = "claude-opus-4-6"
CLAUDE_MODEL_MID        = "claude-sonnet-4-6"
CLAUDE_MODEL_FAST       = "claude-haiku-4-5-20251001"
SDD_MAX_PARALLEL_AGENTS = 5                      # SDD_DEFAULT_MAX_TURNS = 40
TEST_COVERAGE_MIN_PERCENT = 80                   # Umbral mínimo de cobertura para test-runner
```

---

## 🎯 Rol

**Project Manager / Scrum Master** gestionando proyectos **multi-lenguaje** con equipos Scrum en Azure DevOps.
Sprints de 2 semanas · Daily 09:15 · Review + Retro viernes fin de sprint.
Lenguajes soportados: C#/.NET, TypeScript/Node.js, Angular, React, Java/Spring, Python, Go, Rust, PHP/Laravel, Swift/iOS, Kotlin/Android, Ruby/Rails, VB.NET, COBOL, Terraform/IaC, Flutter/Dart.

---

## 📁 Estructura

```
~/claude/                          ← Raíz de trabajo Y repositorio GitHub
├── CLAUDE.md                      ← Este fichero
├── .claude/                       ← Herramientas activas
│   ├── agents/                    ← Subagentes especializados (22 agentes)
│   ├── commands/                  ← Slash commands (27 comandos)
│   ├── rules/                     ← Reglas, convenciones y Language Packs (16 lenguajes)
│   └── skills/                    ← Skills reutilizables (9 skills)
├── docs/                          ← Metodología (reglas Scrum, KPIs, plantillas...)
├── projects/                      ← Proyectos reales (git-ignorados por .gitignore)
└── scripts/                       ← Scripts auxiliares Azure DevOps
```

---

## 📋 Proyectos Activos

> Los proyectos reales están en `CLAUDE.local.md` (git-ignorado).
> Aquí solo figuran los proyectos de ejemplo del repositorio público.

| Proyecto | Azure DevOps | CLAUDE.md específico |
|---|---|---|
| Alpha (ejemplo) | ProyectoAlpha | `projects/proyecto-alpha/CLAUDE.md` |
| Beta (ejemplo) | ProyectoBeta | `projects/proyecto-beta/CLAUDE.md` |
| Sala Reservas (test) | SalaReservas | `projects/sala-reservas/CLAUDE.md` |

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
| `architect` | Opus 4.6 | Diseño de capas, interfaces, patrones |
| `business-analyst` | Opus 4.6 | Reglas de negocio, criterios de aceptación, evaluación de competencias |
| `sdd-spec-writer` | Opus 4.6 | Specs ejecutables para agentes de código |
| `code-reviewer` | Opus 4.6 | Calidad, seguridad, SOLID |
| `security-guardian` | Opus 4.6 | Auditoría de seguridad y confidencialidad pre-commit |
| `dotnet-developer` | Sonnet 4.6 | Implementación C#/.NET |
| `typescript-developer` | Sonnet 4.6 | Implementación TypeScript/Node.js (NestJS, Express, Prisma) |
| `frontend-developer` | Sonnet 4.6 | Implementación Angular + React |
| `java-developer` | Sonnet 4.6 | Implementación Java/Spring Boot |
| `python-developer` | Sonnet 4.6 | Implementación Python (FastAPI, Django, SQLAlchemy) |
| `go-developer` | Sonnet 4.6 | Implementación Go |
| `rust-developer` | Sonnet 4.6 | Implementación Rust/Axum |
| `php-developer` | Sonnet 4.6 | Implementación PHP/Laravel |
| `mobile-developer` | Sonnet 4.6 | Implementación Swift/iOS, Kotlin/Android, Flutter |
| `ruby-developer` | Sonnet 4.6 | Implementación Ruby on Rails |
| `cobol-developer` | Opus 4.6 | Asistencia COBOL (documentación, copybooks, tests) |
| `terraform-developer` | Sonnet 4.6 | Terraform/IaC (NUNCA ejecuta apply) |
| `test-engineer` | Sonnet 4.6 | Testing multi-lenguaje, TestContainers, cobertura |
| `test-runner` | Sonnet 4.6 | Ejecución de tests, cobertura ≥ TEST_COVERAGE_MIN_PERCENT, orquestación de mejora |
| `commit-guardian` | Sonnet 4.6 | Pre-commit checks: rama, secrets, build, tests, code review, README |
| `tech-writer` | Haiku 4.5 | README, CHANGELOG, XML docs |
| `azure-devops-operator` | Haiku 4.5 | WIQL, work items, sprint, capacity |

Flujo SDD: `business-analyst` → `architect` → `sdd-spec-writer` → `{lang}-developer` ‖ `test-engineer` → `code-reviewer`
El agente developer se selecciona según el Language Pack del proyecto (ver tabla abajo).
Antes de cualquier commit → `commit-guardian` (10 checks: rama, security, build, tests, format, code review, README, CLAUDE.md, atomicidad, mensaje)
Tras commit → `test-runner` (tests completos + cobertura ≥ `TEST_COVERAGE_MIN_PERCENT`)

---

## 🌐 Language Packs (Multi-lenguaje)

> Guía completa de incorporación: `docs/guia-incorporacion-lenguajes.md`

| Lenguaje | Conventions | Rules | Agent | Layer Matrix |
|---|---|---|---|---|
| C#/.NET | `dotnet-conventions.md` | `csharp-rules.md` | `dotnet-developer` | `layer-assignment-matrix.md` |
| TypeScript/Node.js | `typescript-conventions.md` | `typescript-rules.md` | `typescript-developer` | `layer-assignment-matrix-typescript.md` |
| Angular | `angular-conventions.md` | (usa typescript-rules) | `frontend-developer` | `layer-assignment-matrix-angular.md` |
| React | `react-conventions.md` | (usa typescript-rules) | `frontend-developer` | `layer-assignment-matrix-react.md` |
| Java/Spring Boot | `java-conventions.md` | `java-rules.md` | `java-developer` | `layer-assignment-matrix-java.md` |
| Python | `python-conventions.md` | `python-rules.md` | `python-developer` | `layer-assignment-matrix-python.md` |
| Go | `go-conventions.md` | `go-rules.md` | `go-developer` | `layer-assignment-matrix-go.md` |
| Rust | `rust-conventions.md` | `rust-rules.md` | `rust-developer` | `layer-assignment-matrix-rust.md` |
| PHP/Laravel | `php-conventions.md` | `php-rules.md` | `php-developer` | `layer-assignment-matrix-php.md` |
| Swift/iOS | `swift-conventions.md` | `swift-rules.md` | `mobile-developer` | — |
| Kotlin/Android | `kotlin-conventions.md` | `kotlin-rules.md` | `mobile-developer` | — |
| Ruby/Rails | `ruby-conventions.md` | `ruby-rules.md` | `ruby-developer` | — |
| VB.NET | `vbnet-conventions.md` | (usa csharp-rules) | `dotnet-developer` | (usa .NET matrix) |
| COBOL | `cobol-conventions.md` | `cobol-rules.md` | `cobol-developer` | — |
| Terraform/IaC | `terraform-conventions.md` | `terraform-rules.md` | `terraform-developer` | — |
| Flutter/Dart | `flutter-conventions.md` | `flutter-rules.md` | `mobile-developer` | — |

Al cargar un proyecto (`/context:load`), detectar el Language Pack por archivos presentes (package.json, pom.xml, go.mod, Cargo.toml, etc.) y cargar las reglas y agente correspondiente.

---

## 🛠️ Para cualquier operación

- **Azure DevOps** → leer primero `.claude/skills/azure-devops-queries/SKILL.md`
- **Discovery (JTBD/PRD)** → `.claude/skills/product-discovery/SKILL.md`
- **Descomponer PBIs** → `.claude/skills/pbi-decomposition/SKILL.md`
- **Specs y agentes** → `.claude/skills/spec-driven-development/SKILL.md`
- **Evaluar repos externos** → `/evaluate-repo`
- **Comandos** → lista completa en `@.claude/rules/pm-workflow.md`
- **Formateo .md** → `.vscode/settings.json` (extensión Highlight requerida)

---

## 🧠 Buenas Prácticas Claude Code

- **Verificación obligatoria**: dar a Claude forma de verificar su trabajo (build + test del lenguaje del proyecto)
- Explorar → Planificar → Implementar → Commit · `/plan` para iniciar sin modificar
- `/compact` al **50% del contexto** · `/clear` entre tareas no relacionadas
- **Commit inmediato** al completar cada tarea
- Arquitectura: **Command → Agent → Skills** — subagentes solo con herramienta `Task`
- Si Claude corrige el mismo error 2+ veces: `/clear` y prompt mejor
- Permisos con **wildcards**: `Bash(dotnet *|npm *|mvn *|pytest *|go *|cargo *)`, `Bash(az devops:*)`, `Edit(./**)`

---

## ✅ Checklist Nuevo Proyecto

- [ ] `projects/[nombre]/` creado con su `CLAUDE.md` específico (≤150 líneas)
- [ ] `.vscode/settings.json` con reglas de highlight para `.md`
- [ ] Entrada añadida en tabla "Proyectos Activos" de este fichero
- [ ] `projects/[nombre]/` añadido al `.gitignore` si es privado
- [ ] Constantes del proyecto añadidas a `pm-config.local.md` si es privado
- [ ] Entrada añadida en `CLAUDE.local.md` en tabla "Proyectos Activos" si es privado
- [ ] `README.md` actualizado para reflejar el nuevo proyecto
