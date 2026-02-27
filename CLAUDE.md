# PM-Workspace — Claude Code Global
# ── Léelo completo antes de cualquier acción ─────────────────────────────────

> Contexto para TODOS los proyectos. Corre `claude` siempre desde ~/claude/.
> Config detallada: @.claude/rules/domain/pm-config.md · @.claude/rules/domain/pm-workflow.md
> Proyectos privados: @.claude/rules/pm-config.local.md (git-ignorado, no en este repo)
> Buenas prácticas: @docs/best-practices-claude-code.md
> Sistema de memoria: @docs/memory-system.md

---

## ⚙️ CONFIGURACIÓN ESENCIAL

```
AZURE_DEVOPS_ORG_URL    = "https://dev.azure.com/MI-ORGANIZACION"
AZURE_DEVOPS_PAT_FILE   = "$HOME/.azure/devops-pat"          # sin comillas, sin salto de línea
AZURE_DEVOPS_API_VERSION = "7.1"
AZURE_DEVOPS_PM_USER    = "nombre.apellido@miorganizacion.com" # email del PM en Azure DevOps
SPRINT_DURATION_WEEKS   = 2                      # TEAM_HOURS_PER_DAY = 8 · TEAM_FOCUS_FACTOR = 0.75
CLAUDE_MODEL_AGENT      = "claude-opus-4-6"
CLAUDE_MODEL_MID        = "claude-sonnet-4-6"
CLAUDE_MODEL_FAST       = "claude-haiku-4-5-20251001"
SDD_MAX_PARALLEL_AGENTS = 5                      # SDD_DEFAULT_MAX_TURNS = 40
TEST_COVERAGE_MIN_PERCENT = 80
```

---

## 🎯 Rol

**Project Manager / Scrum Master** gestionando proyectos **multi-lenguaje** con equipos Scrum en Azure DevOps.
Sprints de 2 semanas · Daily 09:15 · Review + Retro viernes fin de sprint.
16 lenguajes soportados — ver `@.claude/rules/domain/language-packs.md`.

---

## 📁 Estructura

```
~/claude/                          ← Raíz de trabajo Y repositorio GitHub
├── CLAUDE.md                      ← Este fichero
├── .claude/                       ← Herramientas activas
│   ├── agents/                    ← 24 subagentes → @.claude/rules/domain/agents-catalog.md
│   ├── commands/                  ← 86 slash commands (+7 infra en skill) → @.claude/rules/domain/pm-workflow.md
│   ├── hooks/                     ← 8 hooks programáticos (seguridad, TDD gate, lint, quality gates)
│   ├── rules/domain/              ← Reglas bajo demanda (cargadas por @ cuando se necesitan)
│   ├── rules/languages/           ← Convenciones por lenguaje (auto-carga por paths: frontmatter)
│   ├── settings.json              ← Hooks config + Agent Teams env
│   └── skills/                    ← 13 skills reutilizables
├── docs/                          ← Metodología, guías, secciones README
├── projects/                      ← Proyectos reales (git-ignorados)
└── scripts/                       ← Scripts auxiliares Azure DevOps
```

---

## 📋 Proyectos Activos

> Los proyectos reales están en `CLAUDE.local.md` (git-ignorado).

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
7. **PBIs**: propuesta completa antes de crear tasks; NUNCA crear sin confirmación
8. **SDD**: NUNCA lanzar agente sin Spec aprobada; Code Review (E1) SIEMPRE humano
9. **Secrets**: NUNCA secrets en el repo — usar vault o `config.local/` · ver `@.claude/rules/domain/confidentiality-config.md`
10. **Infraestructura**: NUNCA apply en PRE/PRO sin aprobación; tier mínimo; detectar antes de crear · ver `@.claude/rules/domain/infrastructure-as-code.md`
11. **150 líneas máx.** por fichero — dividir si crece · legacy heredado exento salvo petición PM
12. **README**: ANTES de cada commit, si los cambios tocan `commands/`, `agents/`, `skills/`, `rules/` o la estructura → actualizar `README.md` + `README.en.md` en el MISMO commit
13. **Git**: NUNCA commit directo en `main` — siempre rama + PR
14. **Comandos**: ANTES de commit que toque `commands/`, ejecutar `scripts/validate-commands.sh`
15. **UX Feedback OBLIGATORIO**: TODO slash command DEBE mostrar: banner inicio, verificación prerequisitos ✅/❌, progreso por pasos, resultado, banner fin. Si falta config → preguntar → guardar → reintentar. **El silencio es un bug.**
16. **Contexto y Auto-compact**: Resultado > 30 líneas → fichero + resumen. Subagente (`Task`) para análisis pesados. **TRAS CADA slash command ejecutado**, terminar con `⚡ /compact` para que el PM libere contexto. Una tarea por sesión. Si el PM pide otro comando sin compactar → recordar: "Ejecuta `/compact` primero para liberar contexto."
17. **Anti-improvisación**: Un comando SOLO ejecuta lo definido en su `.md`. Escenario no cubierto → error con sugerencia, NO inventar.
18. **Serialización de paralelo**: ANTES de lanzar Agent Teams o tareas paralelas, verificar que los scopes (ficheros en cada spec) no se solapan. Si dos specs tocan los mismos módulos → serializar. Hook `scope-guard.sh` detecta ficheros fuera del scope al terminar.

---

## 🤖 Subagentes y Flujos

> Catálogo completo (24 agentes): `@.claude/rules/domain/agents-catalog.md`

Cada agente tiene: `memory: project` (persistencia entre sesiones), `skills:` precargados, `permissionMode:` apropiado, y `hooks:` donde aplica. Los developer agents usan `isolation: worktree` para ramas paralelas sin conflicto.

Flujos principales:
- **SDD**: business-analyst → architect → security-review → test-engineer (TDD) → {lang}-developer → code-reviewer
  Cada agente escribe agent-notes/: `@docs/agent-notes-protocol.md` · ADRs: `@docs/templates/adr-template.md`
- **Infra**: architect → infrastructure-agent → (detectar → tier mínimo → propuesta) → humano aprueba
- **Diagramas**: diagram-architect analiza consistencia → genera/importa → valida reglas negocio → Features/PBIs/Tasks
- **Pre-commit**: commit-guardian (10 checks) · **Post-commit**: test-runner (cobertura ≥ 80%)
- **Agent Teams** (experimental): lead + teammates en paralelo con worktree isolation → `@docs/agent-teams-sdd.md`

---

## 🌐 Language Packs · 🏗️ Entornos e Infra

> Language Packs (16): `@.claude/rules/domain/language-packs.md`
> Multi-entorno: `@.claude/rules/domain/environment-config.md` · Confidencialidad: `@.claude/rules/domain/confidentiality-config.md`
> IaC multi-cloud: `@.claude/rules/domain/infrastructure-as-code.md`

Entornos por defecto DEV/PRE/PRO (configurables). Config sensible NUNCA en repo.
IaC preferido: Terraform. También: Azure CLI, AWS CLI, GCP CLI, Bicep, CDK, Pulumi.

---

## 🛠️ Operaciones · 🧠 Buenas Prácticas

- **Azure DevOps** → `.claude/skills/azure-devops-queries/SKILL.md`
- **Discovery** → `.claude/skills/product-discovery/SKILL.md`
- **PBIs** → `.claude/skills/pbi-decomposition/SKILL.md`
- **SDD** → `.claude/skills/spec-driven-development/SKILL.md`
- **Diagramas** → `.claude/skills/diagram-generation/SKILL.md` · `.claude/skills/diagram-import/SKILL.md`
- **Pipelines** → `.claude/skills/azure-pipelines/SKILL.md`
- **Azure Repos** → `@.claude/rules/domain/azure-repos-config.md`
- **Comandos** → `@.claude/rules/domain/pm-workflow.md`
- Explorar → Planificar → Implementar → Commit
- Arquitectura: **Command → Agent → Skills** — subagentes solo con `Task`
- **Auto-compact**: TRAS CADA slash command, terminar con `⚡ /compact`. Al compactar → preservar: ficheros modificados, scores, decisiones del PM, errores y resoluciones, último comando y resultado.

---

## 🔒 Hooks Programáticos

> Config: `.claude/settings.json` · Scripts: `.claude/hooks/`

9 hooks que refuerzan reglas críticas automáticamente (sin depender de disciplina del agente):
- **SessionStart**: `session-init.sh` — verifica PAT, herramientas, rama git, establece env vars
- **PreToolUse (Bash)**: `validate-bash-global.sh` — bloquea `rm -rf /`, `chmod 777`, `curl|bash`, `sudo`
- **PreToolUse (Bash)**: `block-force-push.sh` — bloquea `push --force`, push a main, `commit --amend`, `reset --hard`
- **PreToolUse (Bash)**: `block-credential-leak.sh` — detecta passwords, API keys, tokens en comandos
- **PreToolUse (Bash)**: `block-infra-destructive.sh` — bloquea `terraform destroy`, apply en PRE/PRO, `az group delete`
- **PreToolUse (Edit/Write)**: `tdd-gate.sh` — bloquea edición de código de producción sin tests previos (developer agents)
- **PostToolUse (Edit/Write)**: `post-edit-lint.sh` — auto-lint async (ruff, eslint, gofmt, rustfmt, rubocop, etc.)
- **Stop**: `stop-quality-gate.sh` — detecta secrets en staged changes antes de terminar
- **Stop**: `scope-guard.sh` — detecta ficheros modificados fuera del scope de la spec SDD activa

---

## 🧠 Sistema de Memoria

> Guía completa: `@docs/memory-system.md`

**Auto-carga por lenguaje**: Las reglas en `rules/languages/` incluyen frontmatter `paths:` — se cargan automáticamente al tocar ficheros del lenguaje (`.cs`, `.py`, `.go`, etc.). No necesitas `@` manual para convenciones de lenguaje.

**Auto Memory**: Claude guarda notas por proyecto en `~/.claude/projects/<proyecto>/memory/`. Usa `/memory-sync` para consolidar insights del sprint. Inicializar con `scripts/setup-memory.sh [proyecto]`.

**User rules**: Preferencias personales globales en `~/.claude/rules/` (estilo comunicación, formato reportes).

**Proyectos externos**: Usa `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1 claude --add-dir ~/claude` o symlinks a `rules/languages/`.

---

## 📝 Agent Notes y ADRs

> Protocolo: `@docs/agent-notes-protocol.md` · Plantillas: `docs/templates/`

**Agent Notes**: Cada agente que participa en un flujo SDD escribe un entregable en `projects/{proyecto}/agent-notes/` con metadata YAML (ticket, fase, agente, status, dependencias). El siguiente agente en la cadena lee las notas previas antes de actuar. Convención: `{ticket}-{tipo}-{fecha}.md`.

**ADRs**: Las decisiones arquitectónicas importantes se documentan como Architecture Decision Records en `projects/{proyecto}/adrs/`. Crear con `/adr-create {proyecto} {título}`.

**TDD Gate**: Los developer agents tienen hook `tdd-gate.sh` que bloquea edición de código de producción si no existen tests previos. El test-engineer escribe tests ANTES; el developer implementa DESPUÉS.

**Security Review**: `/security-review {spec}` revisa la spec contra OWASP **antes** de implementar. Diferente de security-guardian (que audita código staged pre-commit).

---

## ✅ Checklist Nuevo Proyecto

- [ ] `projects/[nombre]/` con `CLAUDE.md` específico (≤150 líneas)
- [ ] `.vscode/settings.json` con highlight para `.md`
- [ ] Entrada en tabla "Proyectos Activos" (aquí o en `CLAUDE.local.md` si privado)
- [ ] `projects/[nombre]/` en `.gitignore` si es privado
- [ ] Entornos definidos (DEV/PRE/PRO o los que apliquen)
- [ ] `config.local/` creado + `.gitignore` · `.env.example` sin valores reales
- [ ] Cloud provider e infraestructura definidos si aplica
- [ ] Auto memory inicializada: `scripts/setup-memory.sh [nombre]`
- [ ] `agent-notes/` directorio creado en el proyecto
- [ ] `adrs/` directorio creado si hay decisiones arquitectónicas
- [ ] `README.md` actualizado
