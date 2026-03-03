# Era 21 — Savia Everywhere: School, Travel, Git-Native Flow

**Fecha:** 2026-03-03
**Autor:** Investigación automática + validación cruzada
**Workstreams:** 7 líneas paralelas
**Nota:** La otra instancia de Savia trabaja en puntos complementarios. Coordinación vía ROADMAP.md.

---

## Contexto

La Era 20 consolidó pm-workspace como sistema que aprende (agent memory, RPI, adaptive output, PR Guardian). La Era 21 lo convierte en **plataforma portable, educativa y autosuficiente**:

- **Vertical escolar** con seguridad infantil
- **Persistencia Git optimizada** sin bases de datos
- **Travel mode** para llevar Savia en un pendrive
- **SDD/tickets/tareas nativo en Git** para Savia Flow
- **Scripts robustos** multiplataforma e idempotentes
- **Ideas del artículo** "Se acabó el prompt engineering" (bounded autonomy, skills-as-contracts)

---

## WS1 — Savia School (Vertical Educativa)

### Visión
Los niños crean proyectos reales con Savia como tutora. Los profesores supervisan, evalúan y guían. Todo local-first, sin datos en la nube, sin bases de datos externas.

### Arquitectura de seguridad (CRÍTICO)

```
┌────────────────────────────────────────────────┐
│  Capa 1: Contenido seguro                      │
│  • Filtro de contenido edad-apropiado           │
│  • Vocabulario adaptado (Savia modo educativo) │
│  • Bloqueo de temas sensibles configurable     │
│  • Logs de sesión para revisión del profesor   │
├────────────────────────────────────────────────┤
│  Capa 2: Aislamiento de datos                  │
│  • Cada alumno: carpeta independiente          │
│  • Git local (NO remoto público)               │
│  • Profesor: acceso read a todos los alumnos   │
│  • Alumno: acceso SOLO a su carpeta            │
│  • Sin PII en nombres de carpeta (alias)       │
├────────────────────────────────────────────────┤
│  Capa 3: Confidencialidad                      │
│  • RGPD/LOPD infantil (Art. 8 GDPR, <16 años) │
│  • Consentimiento parental documentado          │
│  • Derecho al olvido: /school-forget {alumno}  │
│  • Exportación: /school-export (portabilidad)  │
│  • Cifrado local de evaluaciones               │
└────────────────────────────────────────────────┘
```

### Estructura de carpetas

```
school-savia/
├── .school-config.md          # Config escolar (centro, curso, asignatura)
├── classroom/
│   ├── {alias-alumno}/
│   │   ├── projects/          # Proyectos del alumno
│   │   │   └── {proyecto}/
│   │   │       ├── CLAUDE.md  # Contexto del proyecto (≤150 líneas)
│   │   │       ├── spec.md    # Especificación (si SDD simplificado)
│   │   │       ├── src/       # Código fuente
│   │   │       └── diary.md   # Diario de aprendizaje (auto-generado)
│   │   ├── portfolio.md       # Portfolio acumulativo
│   │   └── progress.md        # Progreso por competencias
│   └── shared/                # Recursos compartidos (templates, ejemplos)
├── teacher/
│   ├── evaluations/           # Evaluaciones (cifradas)
│   │   └── {alias-alumno}/
│   │       └── {fecha}-eval.md.enc
│   ├── rubrics/               # Rúbricas configurables
│   ├── lesson-plans/          # Planes de clase
│   └── analytics.md           # Métricas de clase
├── templates/
│   ├── project-template/      # Template para nuevo proyecto alumno
│   ├── rubric-template.md     # Rúbrica estándar
│   └── consent-form.md        # Formulario consentimiento parental
└── CODEOWNERS                 # teacher/* → @profesor
```

### Comandos propuestos

| Comando | Rol | Descripción |
|---|---|---|
| `/school-setup` | Profesor | Configura aula (centro, curso, asignatura, rúbricas) |
| `/school-enroll` | Profesor | Alta alumno (alias, sin PII en repo) |
| `/school-project` | Alumno | Crear nuevo proyecto desde template |
| `/school-submit` | Alumno | Entregar proyecto para evaluación |
| `/school-evaluate` | Profesor | Evaluar entrega con rúbrica |
| `/school-progress` | Profesor | Ver progreso de un alumno o toda la clase |
| `/school-portfolio` | Alumno | Ver mi portfolio acumulativo |
| `/school-diary` | Alumno | Añadir entrada al diario de aprendizaje |
| `/school-export` | Profesor | Exportar datos de un alumno (portabilidad GDPR) |
| `/school-forget` | Profesor | Borrar todos los datos de un alumno (Art. 17 GDPR) |
| `/school-analytics` | Profesor | Métricas de clase (progreso medio, distribución) |
| `/school-rubric` | Profesor | Crear/editar rúbrica de evaluación |

### Adaptación de Savia para educación

- **Tono:** Savia educativa — más paciente, más explicativa, celebra logros
- **Idioma:** Configurable (castellano, catalán, euskera, gallego, inglés)
- **Nivel:** Adaptativo por curso (Primaria, ESO, Bachillerato, FP)
- **Restricciones:** Sin acceso a internet por defecto, sin ejecución de código arbitrario
- **Feedback:** Constructivo siempre, nunca negativo sin alternativa

### Seguridad — No subir hasta aprobar

**Protocolo de release:**
1. Diseño completo → revisión de seguridad
2. Implementación local → test suite completo
3. Auditoría GDPR/LOPD infantil → checklist firmado
4. Penetration testing de aislamiento entre alumnos
5. Solo tras aprobar los 4 pasos → merge a main

---

## WS2 — Git Persistence Engine (Persistencia optimizada)

### Problema
Cada operación de lectura/escritura sobre datos Git (perfiles, mensajes, proyectos) consume contexto innecesario. Necesitamos granularidad e indexación para que el agente acceda SOLO a lo que necesita.

### Diseño: índices ligeros + acceso quirúrgico

```
.savia-index/
├── profiles.idx       # handle → ruta, rol, último update
├── messages.idx       # thread_id → ruta, from, date, subject (1 línea/msg)
├── projects.idx       # nombre → ruta, estado, última actividad
├── evaluations.idx    # alumno → ruta, fecha, nota (school vertical)
└── tasks.idx          # task_id → ruta, estado, asignado, sprint
```

**Formato de índice:** TSV (Tab-Separated Values) — 1 línea por entrada, sin JSON overhead.

```
# profiles.idx
alice	team/alice/public/profile.md	Admin	2026-03-03
bob	team/bob/public/profile.md	Member	2026-03-02
```

### Operaciones optimizadas

| Operación | Antes (contexto) | Después (contexto) |
|---|---|---|
| Buscar mensaje por thread | Read todo el inbox (~50 archivos) | grep en messages.idx (1 línea) → read 1 archivo |
| Listar equipo | Read directory.md (~30 líneas) | Read profiles.idx (~30 líneas, pero sin prose) |
| Estado de proyecto | Read CLAUDE.md del proyecto (~150 líneas) | Read projects.idx (1 línea) → solo si necesita más |
| Buscar tarea | Read backlog completo | grep tasks.idx → read 1 archivo |

**Reducción estimada:** 60-80% menos tokens por operación de consulta.

### Comandos de mantenimiento de índices

| Comando | Descripción |
|---|---|
| `/index-rebuild` | Reconstruir todos los índices desde los archivos fuente |
| `/index-status` | Verificar integridad (entries vs archivos reales) |
| `/index-compact` | Eliminar entradas huérfanas |

### Hooks de sincronización

- **PostToolUse (Write/Edit):** Si el archivo modificado está en una ruta indexada → actualizar índice automáticamente
- **SessionStart:** Verificar integridad de índices (rápido, solo checksums)

### Principios

1. **Índice es derivado** — siempre reconstruible desde los archivos fuente
2. **TSV sobre JSON** — menor overhead de parsing, grep-friendly
3. **1 línea = 1 entrada** — nunca multiline
4. **Lazy loading** — solo leer el archivo completo cuando el índice no basta
5. **Git-tracked** — los índices se versionan junto con los datos

---

## WS3 — Ideas del artículo "Se acabó el prompt engineering"

### Hallazgos relevantes

El artículo de Iñaki Aguirre describe el cambio de "prompt engineering" a "arquitectura de agentes". Puntos aplicables a pm-workspace:

**1. Skills como contratos versionados**
- Nuestros 22 skills son `.md` pero no tienen versionado explícito
- **Propuesta:** Añadir `version: 1.0.0` al frontmatter de cada skill + CHANGELOG por skill
- **Impacto:** Permite deprecar skills sin romper workflows existentes

**2. Bounded autonomy design**
- El artículo enfatiza: límites claros, escalamiento explícito, trazabilidad completa
- **Ya lo tenemos parcialmente:** Regla 8 (SDD: Code Review humano), Regla 10 (Infra: aprobación PRE/PRO)
- **Propuesta:** Crear mapa visual de "zonas de autonomía" por agente (qué puede hacer solo vs qué necesita aprobación)
- Documento: `docs/bounded-autonomy-map.md`

**3. Action spaces + feedback loops**
- **Action spaces:** Cada agente debería tener un `allowed-actions.md` explícito
- **Feedback loops:** Nuestro agent memory ya captura aprendizajes, pero no hay loop formal de mejora
- **Propuesta:** `/agent-feedback {agente}` que revise su MEMORY.md y proponga mejoras a su configuración

**4. 40% enterprise con agentes para fin de 2026**
- pm-workspace está bien posicionado — ya tenemos 24 agentes, SDD, marketplace
- **Propuesta:** Documentar pm-workspace como caso de referencia para enterprise adoption

---

## WS4 — Script Hardening (Idempotencia + Multiplataforma)

### Hallazgos de la auditoría

**6 issues CRÍTICOS encontrados:**

| # | Script | Issue | Fix |
|---|---|---|---|
| 1 | backup.sh:231 | Hash comparison bug (compara plaintext vs SHA256) | Comparar hash vs stored hash |
| 2 | backup.sh:160 | Race condition en rotación (while read en subshell) | Usar fichero temporal |
| 3 | contribute.sh:54 | Regex lookahead inválida en grep -E (privacy leak) | Reescribir sin lookahead |
| 4 | memory-store.sh:31 | grep sin -F permite regex injection en topic_key | Añadir -F flag |
| 5 | pre-commit-review.sh:20 | Cache invalidation incompleta | Usar find -delete |
| 6 | session-init.sh:69 | Error handling insuficiente en git branch | Fallback con variable vacía |

**7 issues MEDIUM:**

| # | Script | Issue | Fix |
|---|---|---|---|
| 7 | update.sh:60 | `sed -i` sin compatibilidad macOS | Usar `portable_sed_i` de savia-compat.sh |
| 8 | backup.sh:183 | `cp -r` sin preservar permisos | Añadir `-p` flag |
| 9 | context-aging.sh:25 | `date -d` no existe en macOS | Detectar OSTYPE, usar `date -f` |
| 10 | validate-bash-global.sh:52 | `\s` no es POSIX ERE | Usar `[[:space:]]` |
| 11 | block-force-push.sh | Pattern matching bypass con compound commands | Mejorar anchoring del regex |
| 12 | scope-guard.sh | Extracción de filenames demasiado loose | Restringir a líneas con bullets |
| 13 | memory-store.sh:45 | Newlines corrompen JSONL | Escapar newlines antes de insertar |

**Scripts que ya son robustos (no requieren cambios):**
- `post-edit-lint.sh` ✅
- `block-infra-destructive.sh` ✅
- `stop-quality-gate.sh` ✅
- `plan-gate.sh` ✅

### Plan de hardening

1. **Fase 1 (críticos):** Fix los 6 issues críticos — 0 bugs de seguridad/datos
2. **Fase 2 (portabilidad):** Fix los 7 issues medium — funcional en macOS/Linux/WSL
3. **Fase 3 (tooling):** Añadir ShellCheck CI + test de portabilidad mensual
4. **Fase 4 (documentación):** Marcar cada script como `# Platform: linux|macos|wsl|all`

---

## WS5 — Travel Mode (Savia en USB)

### Visión
Un pendrive con TODO lo necesario para trabajar con Savia en cualquier equipo. `savia-init` y a producir.

### Estructura del pendrive

```
SAVIA-USB/
├── savia-init.sh              # Script de arranque (detecta OS, instala deps)
├── savia-init.ps1             # Versión Windows (PowerShell)
├── savia-init.command         # Versión macOS (doble-click)
├── config/
│   ├── .pm-workspace/         # Config personal (keys, handle, preferences)
│   ├── claude-settings/       # settings.json, settings.local.json
│   └── profiles/              # Perfiles de usuario
├── workspace/
│   └── claude/                # Clone completo de pm-workspace
├── deps/
│   ├── node/                  # Node.js portable (LTS)
│   ├── git/                   # Git portable
│   └── claude-cli/            # Claude Code CLI
├── projects/                  # Proyectos activos (opcionales)
├── backups/                   # Backups cifrados
└── README.md                  # Instrucciones de uso
```

### savia-init.sh — Flujo de instalación

```
1. Detectar OS (Linux/macOS/Windows WSL)
2. Verificar dependencias (node, git, claude)
   ├── Si faltan → instalar desde deps/ (offline) o descargar
   └── Si existen → verificar versiones mínimas
3. Configurar Claude Code
   ├── Copiar settings.json → ~/.claude/
   ├── Copiar profiles → destino configurado
   └── Symlink o copiar workspace → ~/claude/
4. Importar claves (si existen en config/)
5. Configurar git (remote, branch, fetch)
6. Verificar: claude --version, git status, savia saluda
7. Listo ✅
```

### Comandos propuestos

| Comando | Descripción |
|---|---|
| `/travel-pack` | Empaquetar Savia actual en USB (workspace + config + keys) |
| `/travel-unpack` | Desempaquetar y configurar en nuevo equipo |
| `/travel-sync` | Sincronizar cambios USB ↔ equipo (bidireccional) |
| `/travel-verify` | Verificar integridad del pendrive (checksums) |
| `/travel-encrypt` | Cifrar datos sensibles del USB (keys, profiles) |

### Seguridad del pendrive

- **Cifrado:** Datos sensibles (keys, PATs) cifrados con passphrase (AES-256)
- **Verificación:** SHA256 checksums de todos los archivos críticos
- **Limpieza:** `/travel-clean` para borrar rastros del equipo temporal
- **Política:** NUNCA almacenar PATs en claro en el USB

---

## WS6 — Resultados de Tests contra Company Repo

### Resultados

| Suite | Resultado | Detalle |
|---|---|---|
| test-company-repo.sh | ✅ 12/12 | Repo init, folders, git ops |
| test-savia-messaging.sh | ✅ 17/17 | Send, reply, announce, broadcast, privacy |
| test-savia-crypto.sh | ✅ 13/13 | Keygen, encrypt, decrypt, wrong key rejection, idempotency |
| test-company-profile.sh | 30/35 | 5 fallos en CLAUDE.md (contadores desalineados por otra instancia) |
| Smoke Tests (company repo) | 1/9 | El repo no tiene estructura Company Savia inicializada |

### Diagnóstico Smoke Tests

Los 8 fallos del smoke test son porque el repo company repo **no tiene la estructura company/** inicializada. Necesitamos ejecutar `/company-repo create` contra el repo real para crear:
- `company/identity.md`
- `company/org-chart.md`
- `team/` estructura
- `directory.md`
- `CODEOWNERS`
- `company-inbox/`

### Diagnóstico Profile Tests

Los 5 fallos en profile tests son:
1. CLAUDE.md dice 288 comandos pero el test espera 295 → la otra instancia añadió comandos
2. CLAUDE.md no referencia /company-setup, /company-edit, /company-show, /company-vertical → necesitan añadirse

### Acciones pendientes

1. **Ejecutar** `/company-repo create` contra company repo para inicializar estructura
2. **Alinear** contadores de CLAUDE.md con el count real de comandos
3. **Añadir** referencias a comandos company-* en CLAUDE.md
4. **Re-ejecutar** tests tras las correcciones

---

## WS7 — SDD/Tickets/Tasks Git-Native (Savia Flow en Git)

### Visión
Todo lo que Savia Flow necesita (specs, tickets, tareas, imputaciones, sprints) vive en carpetas Git. Sin base de datos. Cada equipo tiene su espacio.

### Estructura de carpetas

```
savia-flow-data/
├── .flow-config.md                 # Config global de Savia Flow
├── .savia-index/
│   ├── tasks.idx                   # Índice de todas las tareas
│   ├── specs.idx                   # Índice de specs SDD
│   ├── sprints.idx                 # Índice de sprints
│   └── timesheets.idx              # Índice de imputaciones
├── backlog/
│   ├── features/
│   │   └── {feature-id}.md         # Feature (PBI) con estado en frontmatter
│   ├── bugs/
│   │   └── {bug-id}.md
│   └── tech-debt/
│       └── {debt-id}.md
├── sprints/
│   ├── current/                    # Sprint activo (symlink)
│   └── {sprint-id}/
│       ├── sprint.md               # Meta: objetivo, capacidad, fechas
│       ├── board/
│       │   ├── todo/               # Tareas por hacer
│       │   │   └── {task-id}.md
│       │   ├── in-progress/        # En progreso
│       │   │   └── {task-id}.md
│       │   ├── review/             # En revisión
│       │   │   └── {task-id}.md
│       │   └── done/               # Completadas
│       │       └── {task-id}.md
│       ├── daily/
│       │   └── {YYYY-MM-DD}.md     # Notas de daily
│       └── retro.md                # Retrospectiva
├── specs/
│   └── {spec-id}/
│       ├── spec.md                 # Especificación SDD
│       ├── review.md               # Code review notes
│       └── status.md               # Estado del flujo SDD
├── timesheets/
│   └── {handle}/
│       └── {YYYY-MM}/
│           └── {YYYY-MM-DD}.md     # Imputaciones del día
├── team/
│   └── {handle}/
│       ├── capacity.md             # Capacidad del miembro
│       ├── skills.md               # Skills del miembro
│       └── workload.md             # Carga actual
└── reports/
    └── {sprint-id}/
        ├── burndown.md             # Datos de burndown
        ├── velocity.md             # Velocidad del sprint
        └── summary.md              # Resumen ejecutivo
```

### Formato de tarea (task-id.md)

```yaml
---
id: TASK-2026-0042
type: task          # task | bug | spike | subtask
parent: FEAT-2026-007
title: Implementar endpoint de login
assigned: @alice
status: in-progress  # todo | in-progress | review | done | blocked
priority: high       # critical | high | medium | low
estimate_h: 4
spent_h: 2.5
sprint: SPR-2026-05
tags: [auth, backend, api]
created: 2026-03-01
updated: 2026-03-03
---

## Descripción
[Contenido de la tarea]

## Criterios de aceptación
- [ ] Endpoint POST /api/login funcional
- [ ] Tests unitarios con cobertura >80%
- [ ] Documentación en OpenAPI

## Notas
- 2026-03-03: Avanzado en validación de JWT
```

### Movimiento de tareas = git mv

```bash
# Mover tarea de todo a in-progress
git mv sprints/SPR-2026-05/board/todo/TASK-2026-0042.md \
       sprints/SPR-2026-05/board/in-progress/TASK-2026-0042.md
# Actualizar índice
# Auto-actualizar status en frontmatter
```

### Imputación de horas (timesheet)

```yaml
---
handle: @alice
date: 2026-03-03
total_h: 7.5
---

| Tarea | Horas | Notas |
|---|---|---|
| TASK-2026-0042 | 4.0 | Login endpoint + tests |
| TASK-2026-0038 | 2.5 | Code review de API gateway |
| meeting | 1.0 | Daily + refinement |
```

### Comandos propuestos

| Comando | Descripción |
|---|---|
| `/flow-task-create` | Crear tarea con frontmatter completo |
| `/flow-task-move` | Mover tarea entre columnas (git mv + index update) |
| `/flow-task-assign` | Asignar tarea a @handle |
| `/flow-sprint-create` | Crear sprint con objetivo y capacidad |
| `/flow-sprint-close` | Cerrar sprint, generar reporte, mover pendientes |
| `/flow-timesheet` | Registrar imputación del día |
| `/flow-timesheet-report` | Generar reporte de horas (semanal/mensual) |
| `/flow-board` | Ver estado del board actual (sin Azure DevOps) |
| `/flow-burndown` | Calcular y mostrar burndown del sprint |
| `/flow-velocity` | Calcular velocidad histórica |
| `/flow-spec-create` | Crear spec SDD en carpeta specs/ |
| `/flow-spec-status` | Ver estado del pipeline SDD |
| `/flow-backlog-groom` | Priorizar backlog por valor/esfuerzo |

### Integración con sistema de índices (WS2)

Cada operación actualiza automáticamente los `.idx` correspondientes:
- `flow-task-create` → actualiza `tasks.idx`
- `flow-task-move` → actualiza `tasks.idx` (nuevo status) + `sprints.idx`
- `flow-timesheet` → actualiza `timesheets.idx`

### Perfiles por equipo

Cada equipo trabaja en su propio repo (o branch) de savia-flow-data. La config en `.flow-config.md` define:
- Nombre del equipo, miembros (@handles)
- Duración del sprint (1-4 semanas)
- Calendario laboral (festivos)
- Capacidad por defecto del equipo (horas/sprint)
- Integración con Company Savia (si existe)

---

## Roadmap propuesto — Era 21

| Versión | Workstream | Milestone | Dependencias |
|---|---|---|---|
| v0.99.0 | WS4 | Script Hardening (6 críticos + 7 medium) | Ninguna |
| v0.100.0 | WS2 | Git Persistence Engine (índices + lazy loading) | Ninguna |
| v0.101.0 | WS7 | SDD/Tickets/Tasks Git-native (estructura + 12 comandos) | WS2 (índices) |
| v0.102.0 | WS5 | Travel Mode (pack/unpack/sync/verify) | WS4 (scripts robustos) |
| v0.103.0 | WS1 | Savia School v1 (setup, enroll, project, submit, evaluate) | WS2 (índices), WS4 (scripts) |
| v0.104.0 | WS1 | Savia School v2 (security audit, GDPR, penetration test) | v0.103.0 |
| v0.105.0 | WS3+WS6 | Skills versionados + bounded autonomy map + company repo validation | Todo lo anterior |

**Ruta crítica:** v0.99.0 → v0.100.0 → v0.101.0 → v0.103.0 → v0.104.0
**Ruta paralela:** v0.102.0 puede desarrollarse tras v0.99.0

---

## Principios transversales

1. **Git es la base de datos** — No PostgreSQL, no SQLite, no Firebase. Solo Git.
2. **Índices son derivados** — Siempre reconstruibles. Nunca fuente de verdad.
3. **150 líneas máx por fichero** — Aplica a tasks, specs, timesheets, evaluaciones.
4. **Cifrado local** — Evaluaciones escolares, claves, PATs. AES-256.
5. **Idempotencia** — Todo script ejecutable N veces sin efectos secundarios.
6. **Multiplataforma** — macOS + Linux + Windows WSL. Probado en los tres.
7. **Privacy by design** — Datos de menores: máxima protección, mínima retención.
8. **No subir School hasta auditoría completa** — Merge a main solo tras 4 gates de seguridad.
