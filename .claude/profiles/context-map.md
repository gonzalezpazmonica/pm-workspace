# Context Map — Perfil x Comando

> **Principio** (del paper "Personalization Paradox"):
> Cargar solo los fragmentos de perfil necesarios para cada operación.
> Más contexto ≠ mejor respuesta. Solo contexto relevante = mejor respuesta.

---

## Mapa de carga

### Grupo: Sprint & Daily

**Comandos:** `/sprint-status`, `/sprint-plan`, `/sprint-review`,
`/sprint-retro`, `/velocity-trend`, `/sprint-forecast`, `/sprint-autoplan`, `/risk-predict`, `/my-sprint`, `/nl-query`

**Perfil necesario:**

- `identity.md` — nombre (para saludos y referencias)
- `workflow.md` — daily_time, planning_cadence (contextualizar)
- `projects.md` — qué proyectos gestiona y con qué rol
- `tone.md` — alert_style, celebrate (calibrar tono)

**NO cargar:**

- `tools.md` — irrelevante para estado del sprint
- `preferences.md` — solo útil para informes formales

---

### Grupo: Reporting

**Comandos:** `/report-hours`, `/report-capacity`,
`/kpi-dashboard`, `/kpi-dora`, `/dx-dashboard`,
`/ceo-report`, `/ceo-alerts`, `/portfolio-overview`, `/incident-postmortem`,
`/value-stream-map`, `/stakeholder-report`, `/portfolio-deps`, `/org-metrics`, `/meeting-summarize`, `/capacity-forecast`,
`/okr-define`, `/okr-track`, `/okr-align`, `/strategy-map`

**Perfil necesario:**

- `identity.md` — nombre, empresa (headers de informes)
- `preferences.md` — language, detail_level, report_format, date_format
- `projects.md` — qué proyectos incluir en multi-proyecto
- `tone.md` — formality (narrativa del informe)

**NO cargar:**

- `workflow.md` — irrelevante para generar un informe
- `tools.md` — irrelevante

---

### Grupo: PBI & Backlog

**Comandos:** `/pbi-decompose`, `/pbi-decompose-batch`,
`/pbi-assign`, `/pbi-plan-sprint`, `/epic-plan`, `/feature-impact`, `/backlog-patterns`

**Perfil necesario:**

- `identity.md` — rol (PM decide asignaciones, dev sugiere)
- `workflow.md` — planning_cadence, sdd_active
- `projects.md` — rol en el proyecto concreto
- `tools.md` — solo si azure_devops activo (crear items en AzDO)

**NO cargar:**

- `preferences.md` — no genera informes formales
- `tone.md` — la descomposición es técnica, no necesita tono

---

### Grupo: Backlog Intelligence

**Comandos:** `/backlog-groom` (--top, --duplicates, --incomplete),
`/backlog-prioritize` (--method, --strategy-aligned), `/outcome-track` (--release, --register), `/stakeholder-align` (--items, --scenario)

**Perfil necesario:**

- `identity.md` — rol (PM que gestiona backlog y conflictos)
- `workflow.md` — planning_cadence
- `projects.md` — proyecto target
- `tools.md` — si azure_devops activo (cargar backlog)

**NO cargar:**

- `preferences.md` — no genera informes formales
- `tone.md` — grooming es técnico, no narrativo

---

### Grupo: SDD & Agentes

**Comandos:** `/spec-generate`, `/spec-design`, `/spec-explore`,
`/spec-implement`, `/spec-review`, `/spec-verify`, `/spec-status`,
`/agent-run`, `/agent-cost`, `/agent-efficiency`, `/my-focus`

**Perfil necesario:**

- `identity.md` — rol (tech lead que hace review vs PM que lanza)
- `workflow.md` — reviews_agent_code, specs_per_sprint
- `projects.md` — sdd_enabled en el proyecto target

**NO cargar:**

- `tools.md` — el agente no necesita saber qué IDE usa el humano
- `preferences.md` — el agente trabaja con la spec, no preferencias
- `tone.md` — el output del agente es código, no conversación

---

### Grupo: Team & Workload

**Comandos:** `/team-workload`, `/board-flow`, `/team-onboarding`,
`/team-evaluate`, `/team-skills-matrix`

**Perfil necesario:**

- `identity.md` — nombre, rol
- `projects.md` — qué proyecto
- `tone.md` — alert_style (calibrar alertas de sobrecarga)

**NO cargar:**

- `workflow.md` — irrelevante
- `tools.md` — irrelevante
- `preferences.md` — irrelevante

---

### Grupo: Quality & PRs

**Comandos:** `/pr-pending`, `/pr-review`, `/perf-audit`, `/perf-fix`, `/qa-dashboard`, `/qa-regression-plan`, `/qa-bug-triage`, `/testplan-generate`, `/my-learning`, `/release-readiness`

**Perfil necesario:**

- `identity.md` — nombre, rol
- `workflow.md` — reviews_agent_code
- `tools.md` — ide, git_mode (relevante para sugerencias de fix)

**NO cargar:**

- `projects.md` — se infiere del PR
- `preferences.md` — irrelevante
- `tone.md` — feedback técnico usa tono estándar

---

### Grupo: Infrastructure & Pipelines

**Comandos:** `/pipeline-create`, `/pipeline-run`, `/pipeline-status`,
`/pipeline-logs`, `/pipeline-artifacts`, `/devops-validate`, `/mcp-server`, `/webhook-config`, `/integration-status`,
`/company-setup`, `/company-edit`, `/company-show`, `/company-vertical`

**Perfil necesario:**

- `identity.md` — nombre, rol
- `tools.md` — cicd, docker (qué herramientas de infra usa)
- `projects.md` — proyecto target

**NO cargar:**

- `workflow.md` — irrelevante
- `preferences.md` — irrelevante
- `tone.md` — irrelevante

---

### Grupo: Governance & Compliance

**Comandos:** `/compliance-scan`, `/compliance-fix`,
`/compliance-report`, `/security-review`, `/security-audit`

**Perfil necesario:**

- `identity.md` — nombre, rol, empresa
- `projects.md` — proyecto target
- `preferences.md` — language, detail_level (informes de compliance)

**NO cargar:**

- `workflow.md` — irrelevante
- `tools.md` — irrelevante
- `tone.md` — compliance usa tono formal estándar

---

### Grupo: Memory & Context

**Comandos:** `/memory-sync`, `/memory-save`, `/memory-search`, `/memory-context`,
`/context-load`, `/session-save`, `/context-optimize`, `/context-age`,
`/context-benchmark`, `/hub-audit`, `/cross-project-search`

**Perfil necesario:**

- `identity.md` — nombre
- `projects.md` — proyectos del usuario
- `preferences.md` — language (para output de búsquedas)

**NO cargar:**

- `workflow.md` — irrelevante
- `tools.md` — irrelevante
- `tone.md` — irrelevante

---

### Grupo: Messaging & Notifications

**Comandos:** `/notify-slack`, `/notify-whatsapp`, `/notify-nctalk`,
`/slack-search`, `/whatsapp-search`, `/nctalk-search`

**Perfil necesario:**

- `identity.md` — nombre
- `preferences.md` — language
- `tone.md` — formality, alert_style (calibrar mensajes)

**NO cargar:**

- `workflow.md` — irrelevante
- `tools.md` — la config de messaging ya está en rules/domain
- `projects.md` — irrelevante

---

### Grupo: Connectors & Sync

**Comandos:** `/confluence-publish`, `/gdrive-upload`, `/jira-sync`,
`/jira-connect`, `/github-projects`, `/linear-sync`, `/notion-sync`, `/wiki-sync`, `/wiki-publish`, `/platform-migrate`

**Perfil necesario:**

- `identity.md` — nombre, empresa
- `preferences.md` — language, report_format
- `projects.md` — proyecto fuente

**NO cargar:**

- `workflow.md` — irrelevante
- `tools.md` — irrelevante
- `tone.md` — irrelevante

---

### Grupo: Diagramas

**Comandos:** `/diagram-generate`, `/diagram-import`,
`/diagram-config`, `/diagram-status`

**Perfil necesario:**

- `identity.md` — nombre
- `projects.md` — proyecto target
- `preferences.md` — language (etiquetas en diagramas)

**NO cargar:**

- `workflow.md` — irrelevante
- `tools.md` — irrelevante
- `tone.md` — irrelevante

---

### Grupo: Architecture & Debt

**Comandos:** `/arch-detect`, `/arch-suggest`, `/arch-compare`,
`/arch-fitness`, `/arch-recommend`, `/tech-radar`, `/arch-health`, `/debt-track`, `/debt-analyze`,
`/debt-prioritize`, `/debt-budget`, `/code-patterns`

**Perfil necesario:**

- `identity.md` — nombre, rol
- `projects.md` — proyecto target
- `preferences.md` — detail_level (profundidad del análisis)

**NO cargar:**

- `workflow.md` — irrelevante
- `tools.md` — irrelevante
- `tone.md` — análisis técnico usa tono estándar

---

### Grupo: Daily Routine & Health

**Comandos:** `/daily-routine`, `/health-dashboard`

**Perfil necesario:**

- `identity.md` — nombre, rol (determina qué rutina y qué vista del dashboard)
- `workflow.md` — primary_mode, daily_time (contextualizar rutina)
- `projects.md` — qué proyectos gestiona
- `tone.md` — alert_style, celebrate (calibrar tono de alertas)

**NO cargar:**

- `tools.md` — irrelevante para rutinas y dashboards
- `preferences.md` — solo útil si `/health-dashboard` genera informe formal

---

## Regla especial: Agentes (role: "Agent")

Cuando el perfil activo tiene `role: "Agent"`, las reglas de carga
cambian:

- **Siempre cargar** `identity.md` (para confirmar modo agente)
- **Siempre cargar** `preferences.md` (para output_format: yaml/json)
- **Cargar `projects.md`** solo si la operación es sobre un proyecto
- **NO cargar** `tone.md` — los agentes no necesitan calibración de tono
- **NO cargar** `workflow.md` — los agentes no tienen rutina diaria
- **NO cargar** `tools.md` — irrelevante para agentes externos

El output de TODOS los comandos se devuelve en formato estructurado
(YAML por defecto, JSON si `output_format: "json"` en preferences.md).
Sin narrativa, sin emojis, sin saludos. Solo datos y status codes.

---

## Regla general

Si un comando no aparece en este mapa, cargar solo `identity.md`.
Ante la duda: **menos es más**. Mejor cargar de menos que de más.
