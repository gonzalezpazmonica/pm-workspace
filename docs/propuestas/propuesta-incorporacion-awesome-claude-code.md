# Propuesta de Incorporación: Awesome Claude Code → pm-workspace

**Fecha:** 2026-02-26
**Fuente analizada:** [hesreallyhim/awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) v2.0.1
**Destino:** pm-workspace (github.com/gonzalezpazmonica/pm-workspace)

---

## Resumen ejecutivo

Tras un análisis exhaustivo del repositorio awesome-claude-code (209 recursos curados, 10 categorías, 50+ scripts, 11 workflows) y su cruce con la arquitectura actual de pm-workspace, se identifican **7 incorporaciones viables** que enriquecen el workspace sin generar conflictos con las reglas existentes, y **5 elementos descartados** por redundancia o incompatibilidad.

---

## Parte 1 — Incorporaciones propuestas

### 1. Comando `/evaluate-repo` — Auditoría de dependencias externas

**Origen:** `.claude/commands/evaluate-repository.md`
**Tipo:** Nuevo slash command
**Ubicación propuesta:** `.claude/commands/evaluate-repo.md`

**Qué hace:** Evaluación estática de seguridad y calidad de cualquier repositorio externo antes de incorporar herramientas, librerías o recursos al workspace. Asigna puntuación 1-10 en 5 categorías y tiene un checklist específico para Claude Code (hooks implícitos, ejecución sin confirmación, side effects no documentados).

**Por qué tiene sentido:** pm-workspace ya tiene `security-guardian` para auditoría pre-commit, pero no tiene un mecanismo para evaluar **herramientas externas antes de adoptarlas**. Este comando cierra ese gap. Cada vez que se considere agregar un MCP server, un skill externo, una librería NuGet o cualquier dependencia, este comando da un veredicto estructurado.

**Adaptación necesaria:**

- Traducir a español (consistencia con el workspace)
- Agregar criterios específicos para el ecosistema .NET/Azure DevOps:
  - ¿Usa NuGet packages con vulnerabilidades conocidas?
  - ¿Tiene dependencias de versiones EOL de .NET?
  - ¿Accede a Azure DevOps API sin PAT seguro?
- Integrar con la tabla de delegación del `commit-guardian`: si se añade una nueva dependencia en un `.csproj`, sugerir ejecutar `/evaluate-repo` primero
- Agregar categoría de evaluación: **Compatibilidad con Arquitectura Hexagonal/DDD**

**Conflictos:** Ninguno. Complementa a `security-guardian` sin solaparse (uno audita código propio, el otro audita código externo).

---

### 2. Comando `/pr-review` — Revisión multi-perspectiva de Pull Requests

**Origen:** `resources/slash-commands/pr-review/pr-review.md`
**Tipo:** Nuevo slash command
**Ubicación propuesta:** `.claude/commands/pr-review.md`

**Qué hace:** Estructura una revisión de PR desde 6 perspectivas diferentes: Product Manager, Developer Senior, QA Engineer, Security Engineer, DevOps y UI/UX. Cada perspectiva tiene su propio checklist y produce hallazgos categorizados.

**Por qué tiene sentido:** El `code-reviewer` actual cubre la perspectiva técnica (.NET, SOLID, seguridad de código), pero no evalúa un PR desde la óptica de producto, QA o DevOps. Para los proyectos gestionados en Azure DevOps, una revisión multi-perspectiva asegura que el PR no solo es código limpio, sino que cumple la historia de usuario, tiene tests de integración, y no rompe el pipeline CI/CD.

**Adaptación necesaria:**

- Eliminar la perspectiva UI/UX (los proyectos actuales son APIs/microservicios backend; agregar solo si se incorporan proyectos frontend)
- Reemplazar la perspectiva "Product Manager" por **"Business Analyst"** alineada con el agente existente `business-analyst`
- La perspectiva "Developer" debe delegar al `code-reviewer` existente en lugar de duplicar su lógica
- La perspectiva "DevOps" debe verificar contra los 9 stages del Jenkinsfile existente
- La perspectiva "QA" debe verificar cobertura ≥ 80% (constante `TEST_COVERAGE_MIN_PERCENT`)
- Agregar perspectiva **"Spec Compliance"**: verificar que el PR implementa exactamente lo que dice la spec SDD aprobada
- El resultado debe publicarse como comentario en el PR de Azure DevOps (via `az repos pr`)

**Conflictos:** Parcial con `code-reviewer`. Solución: `/pr-review` **orquesta** las perspectivas, y una de ellas delega al `code-reviewer` como subagente. No se duplica lógica.

---

### 3. Workflow de Producto — JTBD + PRD antes de descomponer PBIs

**Origen:** `resources/slash-commands/create-jtbd/` y `resources/slash-commands/create-prd/`
**Tipo:** Nuevo skill + 2 nuevos slash commands
**Ubicación propuesta:**
- `.claude/skills/product-discovery/SKILL.md`
- `.claude/commands/pbi-jtbd.md`
- `.claude/commands/pbi-prd.md`

**Qué hace:** Antes de descomponer un PBI en tareas técnicas, documenta el *por qué* del usuario (Jobs to be Done) y el *qué* del producto (Product Requirements Document). Esto enriquece la cadena: JTBD → PRD → PBI → Tasks.

**Por qué tiene sentido:** Actualmente, `/pbi:decompose` toma un PBI de Azure DevOps y lo descompone directamente en tareas técnicas. Pero los PBIs a veces llegan sin contexto suficiente sobre la necesidad del usuario. Agregar una fase de discovery formaliza lo que el `business-analyst` debería hacer antes de que el `architect` diseñe la solución.

**Adaptación necesaria:**

- Adaptar las plantillas JTBD/PRD al contexto de Azure DevOps:
  - El JTBD se almacena como attachment del PBI o en `docs/jtbd/PBI-{id}.md`
  - El PRD se almacena como attachment del PBI o en `docs/prd/PBI-{id}.md`
- Integrar en el flujo SDD existente:
  ```
  ANTES:  PBI → architect → spec-writer → developer → ...
  AHORA:  PBI → business-analyst (JTBD+PRD) → architect → spec-writer → developer → ...
  ```
- El agente `business-analyst` lee el PBI, genera JTBD, luego genera PRD, y solo entonces pasa al `architect`
- No generar PRDs para PBIs tipo "bug" o "chore" — solo para "feature" y "user story"

**Conflictos:** Ninguno. Extiende la cadena SDD sin modificar nada existente. El `business-analyst` ya existe pero no tiene un workflow formalizado de discovery.

---

### 4. Comando `/context-load` — Carga de contexto al inicio de sesión

**Origen:** `resources/slash-commands/context-prime/context-prime.md`
**Tipo:** Nuevo slash command
**Ubicación propuesta:** `.claude/commands/context-load.md`

**Qué hace:** Al iniciar una nueva sesión de Claude Code, carga automáticamente el contexto necesario: lee el README, la estructura del proyecto activo, el estado del sprint actual, y las reglas relevantes.

**Por qué tiene sentido:** Cada sesión de Claude Code empieza sin contexto previo. Hoy, el usuario tiene que recordar qué proyecto está activo y qué sprint está en curso. Un comando de carga de contexto reduce la fricción y evita que Claude opere con información incompleta.

**Adaptación necesaria:**

- Leer `CLAUDE.md` raíz + `CLAUDE.md` del proyecto activo
- Ejecutar `/sprint:status` para obtener el estado actual del sprint
- Listar las ramas activas (`git branch -a | grep -v main`)
- Resumir los últimos 5 commits para entender en qué se estuvo trabajando
- Verificar si hay PBIs asignados sin empezar en el sprint actual
- NO ejecutar queries pesadas a Azure DevOps — solo contexto local + resumen de sprint
- Output: un resumen de ~20 líneas que el usuario puede leer en 30 segundos

**Conflictos:** Ninguno. Es un comando de lectura que no modifica nada.

---

### 5. Automatización de CHANGELOG — Actualización por release

**Origen:** `resources/slash-commands/release/release.md` y `resources/slash-commands/add-to-changelog/`
**Tipo:** Nuevo slash command
**Ubicación propuesta:** `.claude/commands/changelog-update.md`

**Qué hace:** Analiza los commits desde la última versión, clasifica los cambios por tipo (feat, fix, docs, etc.), actualiza `CHANGELOG.md` siguiendo el formato "Keep a Changelog", y opcionalmente sugiere bump de versión semántica.

**Por qué tiene sentido:** pm-workspace ya tiene un `CHANGELOG.md` pero se actualiza manualmente. Con los commits convencionales que ya enforce el `commit-guardian`, el CHANGELOG puede generarse automáticamente. Esto es especialmente útil antes de un release o al final de un sprint.

**Adaptación necesaria:**

- Respetar el formato existente del CHANGELOG.md de pm-workspace
- Clasificar commits usando los tipos ya definidos en `github-flow.md`: feat, fix, docs, refactor, chore, test, ci
- Agregar contexto de sprint: cada sección del CHANGELOG puede agruparse por sprint si se desea
- Delegar a `tech-writer` la redacción final (consistencia de tono y estilo)
- NO hacer bump de versión automáticamente — solo proponer y que el humano confirme

**Conflictos:** Ninguno. `tech-writer` ya es responsable de documentación; este comando le da un workflow específico.

---

### 6. Patrones regex para detección de secrets

**Origen:** `.pre-commit-config.yaml` — hooks `detect-private-key` y `check-merge-conflict`
**Tipo:** Mejora a agente existente
**Ubicación propuesta:** Actualización de `.claude/agents/security-guardian.md`

**Qué hace:** Agrega patrones de detección adicionales al `security-guardian`: claves privadas (RSA, ECDSA, ed25519), tokens de API (formatos conocidos de Azure, GitHub, AWS), archivos de configuración sensibles (.env, appsettings.Development.json con datos reales), y marcadores de merge conflict.

**Por qué tiene sentido:** El `security-guardian` actual busca credenciales y datos privados, pero no tiene una lista explícita de patrones regex para detectar formatos específicos de secrets. Los hooks de pre-commit-config del repo fuente tienen patrones probados y maduros.

**Adaptación necesaria:**

- Agregar al `security-guardian` una sección de patrones regex:
  ```
  PRIVATE_KEY:    -----BEGIN (RSA|EC|DSA|OPENSSH) PRIVATE KEY-----
  AZURE_PAT:      [a-z2-7]{52}
  GITHUB_TOKEN:   ghp_[A-Za-z0-9]{36}
  AWS_KEY:        AKIA[0-9A-Z]{16}
  CONNECTION_STR: (Server|Data Source)=.*Password=
  MERGE_CONFLICT: ^[<>=]{7}
  ```
- Verificar contra staged files, no contra todo el repo (rendimiento)
- Mantener la escalación existente: BLOQUEADO → escalar al humano

**Conflictos:** Ninguno. Enriquece un agente existente sin cambiar su comportamiento ni su flujo de delegación.

---

### 7. Check de atomicidad de commits

**Origen:** `resources/slash-commands/commit/commit.md`
**Tipo:** Mejora al agente `commit-guardian`
**Ubicación propuesta:** Actualización de `.claude/agents/commit-guardian.md` (nuevo CHECK entre 8 y 9)

**Qué hace:** Antes de construir el mensaje de commit, analiza el diff para detectar si los cambios staged contienen múltiples cambios lógicos no relacionados. Si es así, sugiere dividir en commits atómicos separados.

**Por qué tiene sentido:** La regla actual de `github-flow.md` dice "Cada commit = un cambio aislado y completo (puede revertirse solo)", pero no hay un check automatizado que lo verifique. Este patrón agrega esa verificación.

**Adaptación necesaria:**

- Agregar como **CHECK 8.5** (entre README y mensaje de commit)
- Analizar `git diff --cached --stat` para detectar:
  - Cambios en más de 3 directorios no relacionados
  - Mezcla de tipos de archivos dispares (ej: `.cs` + `.md` + `.yaml` en el mismo commit sin relación obvia)
  - Más de 300 líneas de diff (umbral configurable en `pm-config.md`)
- Si se detectan múltiples cambios lógicos:
  - Sugerir la división al humano (NO dividir automáticamente)
  - Proponer qué archivos van en cada commit
  - Esperar confirmación antes de proceder
- NO adoptar emojis del repo fuente en los mensajes de commit (conflicto con el formato convencional existente)
- El `commit-guardian` ya controla el mensaje en CHECK 9; este check complementa validando la **atomicidad** antes del mensaje

**Conflictos:** Parcial con CHECK 9. Solución: CHECK 8.5 valida atomicidad del *contenido*, CHECK 9 valida formato del *mensaje*. Son complementarios.

---

## Parte 2 — Elementos descartados

### Descartado 1: Emojis en commits (Gitmoji)

**Razón:** El workspace usa formato convencional `tipo(scope): descripción` sin emojis. Agregar emojis contradiría `github-flow.md` y rompería la consistencia del historial de commits. El mapeo gitmoji → tipo convencional del repo fuente es interesante pero innecesario cuando ya se tiene la convención funcionando.

### Descartado 2: Ralph Wiggum Technique (iteraciones autónomas)

**Razón:** Esta técnica permite que Claude itere autónomamente sin supervisión humana. Contradice directamente la regla SDD de pm-workspace: "Code Review es SIEMPRE humano" y el principio de que ciertos pasos nunca se automatizan. El riesgo de iteraciones sin control es alto en un workspace de producción.

### Descartado 3: Infraestructura de curación (CSV, generadores, workflows de submission)

**Razón:** Toda esta infraestructura (el 80% del repo) sirve para gestionar una lista curada de recursos. No es aplicable a un workspace de gestión de proyectos. Es la plomería interna del repo, no un recurso transferible.

### Descartado 4: Assets SVG y sistema multi-estilo de README

**Razón:** Visualmente impresionante pero no relevante para pm-workspace. El README del workspace es funcional y documentativo, no una vitrina visual.

### Descartado 5: Comando `/todo` local (gestión de tareas en markdown)

**Razón:** pm-workspace gestiona tareas en Azure DevOps con work items, no en archivos markdown locales. Agregar un sistema paralelo de todos crearía duplicidad y confusión sobre cuál es la fuente de verdad. Las tareas siempre deben vivir en Azure DevOps.

---

## Parte 3 — Plan de implementación sugerido

### Fase 1 — Quick wins (no requieren cambios estructurales)

| # | Incorporación | Esfuerzo | Impacto |
|---|---|---|---|
| 1 | `/evaluate-repo` | Bajo | Alto — cierra gap de seguridad en adopción de herramientas |
| 6 | Patrones regex en `security-guardian` | Bajo | Medio — mejora detección de secrets |
| 4 | `/context-load` | Bajo | Alto — reduce fricción al iniciar sesiones |

### Fase 2 — Mejoras al flujo existente

| # | Incorporación | Esfuerzo | Impacto |
|---|---|---|---|
| 7 | Check de atomicidad en `commit-guardian` | Medio | Medio — mejora calidad del historial git |
| 5 | `/changelog-update` | Medio | Medio — automatiza mantenimiento de CHANGELOG |

### Fase 3 — Extensiones del workflow SDD

| # | Incorporación | Esfuerzo | Impacto |
|---|---|---|---|
| 3 | JTBD + PRD workflow | Alto | Alto — formaliza discovery antes de implementación |
| 2 | `/pr-review` multi-perspectiva | Alto | Alto — eleva la calidad de las revisiones de PR |

---

## Parte 4 — Compatibilidad verificada

Cada propuesta fue cruzada con las siguientes reglas existentes:

| Regla | Estado |
|---|---|
| `CLAUDE.md` — Restricciones absolutas (PAT, IterationPath, main) | Sin conflicto |
| `github-flow.md` — Branching y commits convencionales | Sin conflicto (check 7 refuerza atomicidad) |
| `pm-workflow.md` — Cadencia Scrum y operaciones | Sin conflicto (JTBD/PRD extiende, no reemplaza) |
| `csharp-rules.md` — Análisis estático SonarQube-equivalent | Sin conflicto |
| `dotnet-conventions.md` — Estándares de codificación | Sin conflicto |
| `readme-update.md` — Triggers de actualización de README | Compatible (nuevos commands/skills requieren actualizar README) |
| SDD — Spec-Driven Development flow | Sin conflicto (JTBD/PRD precede al flujo, /pr-review lo cierra) |
| Tabla de delegación del `commit-guardian` | Compatible (nuevos checks se integran en la secuencia) |

---

*Propuesta generada a partir del análisis cruzado de awesome-claude-code v2.0.1 y pm-workspace.*
