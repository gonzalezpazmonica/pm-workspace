# Regla: Orquestación por Defecto — Comportamiento determinista

> **REGLA INMUTABLE — Rule #27** · Aplica a TODO agente `primary` (build, plan, custom).
> Orquestación NO es decisión por turno. Es la forma normal de operar de Savia.

---

## Principio

El agente primary actúa como **orquestador**, no como ejecutor monolítico.
Toda tarea que encaje en la descripción de un subagente registrado se delega
mediante `task` tool. El primary mantiene el plan, decide, integra resultados
y se reserva para razonamiento de alto nivel.

**No hay "modo single-agent". No hay "lo hago yo porque es rápido".**
Si existe un subagente cuya descripción cubre la tarea, se delega.

---

## Reglas deterministas

### Delegación obligatoria

| Tipo de tarea | Subagente obligatorio | Tier |
|---|---|---|
| Análisis de spec → plan de slices | `dev-orchestrator` | mid |
| Implementación Python (>1 fichero o >20 líneas) | `python-developer` | mid |
| Implementación TypeScript (>1 fichero o >20 líneas) | `typescript-developer` | mid |
| Implementación .NET | `dotnet-developer` | mid |
| Implementación Java/Go/Ruby/PHP/Rust/Mobile | `{lang}-developer` | mid |
| Diseño de tests / suite nueva | `test-architect` | mid |
| Escritura/refactor de tests existentes | `test-engineer` | mid |
| Ejecución suite + cobertura post-commit | `test-runner` | mid |
| README, CHANGELOG, docs/, skills, comentarios | `tech-writer` | fast |
| Code review pre-merge | `code-reviewer` | heavy |
| Court 4-judge tras slice | `court-orchestrator` | heavy |
| Operaciones Azure DevOps (WIQL, work items, sprint) | `azure-devops-operator` | fast |
| Diseño arquitectónico / decisión técnica | `architect` | heavy |
| Análisis de reglas de negocio / descomposición PBI | `business-analyst` | heavy |
| Auditoría confidencialidad pre-PR | `confidentiality-auditor` | heavy |
| Pre-commit guard | `commit-guardian` | mid |
| Generación de Spec SDD | `sdd-spec-writer` | heavy |

### Excepciones — el primary ejecuta directamente SOLO si

1. **Decisión / orquestación**: actualizar plan, ROADMAP, decidir orden de slices.
2. **Lectura exploratoria de 1-3 ficheros** para decidir qué subagente invocar.
3. **Comando trivial de shell** (≤1 línea) para verificar estado (git status, ls).
4. **Síntesis final** de outputs de subagentes para responder al usuario.
5. **Fix de 1 línea** sin spec asociada y con confianza total.
6. **Subagente no existe o no aplica** — y se documenta el porqué en una línea.

### Prohibido

- "Lo hago yo porque ya tengo el contexto cargado" — el contexto sobra, los tokens caros sobran más.
- Editar código de aplicación (no scripts del workspace) sin delegar a developer.
- Escribir tests sin delegar a test-architect/test-engineer.
- Escribir docs >50 líneas sin delegar a tech-writer.
- Marcar slice como completado sin code-reviewer.
- Justificar single-agent con "es más rápido" — la rapidez no compensa coste y fragilidad.

### Paralelización

Tareas independientes se delegan en **paralelo** (múltiples `task` tool calls
en un solo mensaje). Ejemplos canónicos:

- `tech-writer` (skill+docs) y `test-architect` (suite nueva) en paralelo.
- 4 jueces del Court ejecutándose simultáneos.
- `python-developer` (slice A) y `typescript-developer` (slice B) si no
  comparten ficheros.

### Tier resolution

Modelo efectivo de cada subagente se resuelve vía `~/.savia/preferences.yaml`
(SPEC-127). El primary NUNCA hardcodea modelo en la invocación. Tier abstracto
(`heavy`/`mid`/`fast`) viene del frontmatter del `.opencode/agents/{name}.md`
y se mapea a model id del provider activo.

---

## Auto-detección al inicio de sesión

Cualquier agente primary, en su primer turno, DEBE:

1. Verificar que `opencode.json` registra los subagentes mínimos:
   `dev-orchestrator`, `python-developer`, `typescript-developer`,
   `tech-writer`, `test-architect`, `test-engineer`, `code-reviewer`,
   `court-orchestrator`, `commit-guardian`, `azure-devops-operator`.
2. Si falta alguno, **añadirlo a `opencode.json`** antes de continuar
   (no es opt-in del usuario — es contrato del workspace).
3. Verificar `~/.savia/preferences.yaml` existe con `version: 1`.
   Si no, abortar y pedir setup.

Hook recomendado: `.opencode/hooks/orchestration-readiness.sh` (SessionStart).

---

## Auditoría

Cada delegación queda en el log nativo de `task` tool. Stop hook
`scripts/orchestration-audit.sh` (futuro) computa ratio
`tareas_delegadas / tareas_totales` y alerta si <60%.

**Métrica objetivo**: >=70% de tareas no triviales delegadas.
**Métrica de fallo**: <40% sostenido = primary actuando como ejecutor monolítico.

---

## Por qué esto es determinista

- No depende de que el usuario lo pida.
- No depende del juicio del primary sobre "si vale la pena".
- No depende del modelo del primary (opus/sonnet/cualquiera).
- Sí depende de que `opencode.json` registre los subagentes — corregible al
  arranque por el propio primary.

Si un día el primary no orquesta, es un bug del workspace (subagentes no
registrados, hook ausente) — no una "decisión razonable".

---

## Referencias

- `docs/rules/domain/agents-catalog.md` — catálogo completo
- `docs/rules/domain/model-alias-schema.md` — tier -> model id
- `docs/rules/domain/autonomous-safety.md` — gates aplicables a delegaciones
- `AGENTS.md` — índice cross-frontend
- `opencode.json` — registro runtime de subagentes
