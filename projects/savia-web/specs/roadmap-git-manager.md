# Roadmap savia-web — Priorizado por relevancia estrategica

## Context

savia-web es el cliente web de PM-Workspace. Ha completado Phases 1-3 del MVP (layout, pages, reports, backlog, i18n, multi-user, chat sessions). Este roadmap consolida todo lo pendiente + la nueva feature de Git Manager, priorizado por valor estrategico para el producto.

---

## Plan de implementacion — Desde jueves 20 marzo 2026

> la usuaria viaja hasta el miercoles 19. Programacion retoma jueves 20.
> Estimacion por sesion: ~3-4h de trabajo efectivo con Claude Code.
> Cada sesion tiene un entregable concreto y verificable.

### Semana 1: Jueves 20 — Domingo 23 marzo

| Dia | Sesion | Entregable | Dependencia |
|-----|--------|-----------|-------------|
| **Jue 20** | Specs formales | Crear `phase4-git-viewer.spec.md`, `phase4-git-staging.spec.md`, `phase4-git-advanced.spec.md` en `projects/savia-web/specs/`. Aprobar specs. | Roadmap (este fichero) |
| **Vie 21** | P1.a Bridge endpoints | 5 endpoints git read-only en `savia-bridge.py` + helper `_resolve_git_repo` + validadores. Tests en `test_bridge_endpoints.py`. | Specs aprobadas |
| **Sab 22** | P1.a Frontend core | `git.ts` types + `git.ts` store + `GitPage.vue` + ruta + sidebar entry + i18n keys | Bridge endpoints funcionando |
| **Dom 23** | P1.a Grafo + componentes | `GitCommitGraph.vue` (SVG) + `GitBranchList.vue` + `GitCommitList.vue` + `GitCommitDetail.vue` + `GitDiffViewer.vue` | Store + types listos |

**Milestone Semana 1**: Pagina `/git` funcional con grafo visual, lista de commits, branches y diff viewer read-only.

### Semana 2: Lunes 24 — Domingo 30 marzo

| Dia | Sesion | Entregable | Dependencia |
|-----|--------|-----------|-------------|
| **Lun 24** | P1.a E2E tests | Tests Playwright para GitPage: grafo renderiza, click commit muestra detalle, diff viewer funciona. Screenshots obligatorios. | P1.a completo |
| **Mar 25** | P2 Test regression | Revisar `regression-plan.md`, anadir screenshots a los 18 E2E existentes, cubrir gaps de cobertura | P1.a tests done |
| **Mie 26** | P1.b Bridge write endpoints | 6 endpoints: stage, unstage, commit, push, pull, branch CRUD. Tests Bridge. | P1.a estable |
| **Jue 27** | P1.b Frontend staging | `GitStagingArea.vue` + `GitCommitForm.vue` + `GitSyncBar.vue` + `GitBranchActions.vue` + ampliar store | Write endpoints listos |
| **Vie 28** | P1.b E2E + polish | E2E tests para staging/commit/push. Screenshots. Pulir UX del flujo completo. | P1.b componentes listos |
| **Sab 29** | P1.c Bridge advanced | 6 endpoints: merge, stash, blame, search, tags. Tests. | P1.b estable |
| **Dom 30** | P1.c Frontend advanced | `GitMergeDialog.vue` + `GitStashPanel.vue` + `GitBlameView.vue` + `GitSearchBar.vue` + `GitTagList.vue` | Advanced endpoints listos |

**Milestone Semana 2**: Git Manager completo (3 fases), test regression cubierto.

### Semana 3: Lunes 31 marzo — Viernes 4 abril

| Dia | Sesion | Entregable | Dependencia |
|-----|--------|-----------|-------------|
| **Lun 31** | P1.c E2E + conflict viewer | `GitConflictViewer.vue` + E2E tests avanzados + screenshots | P1.c componentes |
| **Mar 1** | P3 Notificaciones SSE | Ampliar SSE del Bridge a eventos genericos. Store de notificaciones. Toast en TopBar. | Git Manager estable |
| **Mie 2** | P3 Integracion git+SSE | Conectar git store con SSE events (refresh on push/pull). Polling fallback. | SSE generico |
| **Jue 3** | P4 Dashboard real | Conectar `/reports/*` con datos reales del Bridge. Widgets por rol. | SSE para refresh |
| **Vie 4** | P5 Approvals + review | Conectar approvals con diffs del Git Manager. Flujo approve/reject. | Git Manager + Dashboard |

**Milestone Semana 3**: Plataforma integrada con notificaciones, dashboard real y code review.

### Semana 4+ (backlog, sin fecha fija)

| Prioridad | Feature | Cuando |
|-----------|---------|--------|
| P6 | Mobile responsive + PWA | Cuando P1-P5 esten estables |
| P7 | Integraciones externas | Bajo demanda |

### Notas del plan

- **Cada sesion empieza con** `/context-load` + leer este roadmap + spec relevante
- **Cada sesion termina con** commit + E2E con screenshots + `/compact`
- **Si una sesion se complica**: partir en 2 sesiones, no acumular deuda
- **Bridge file size**: cuando supere 4000 lineas, extraer a `savia_bridge_git.py`
- **Specs se crean el jueves 20** como primera accion — son el contrato de implementacion

---

## Estado actual (completado)

| Fase | Contenido | Estado |
|------|-----------|--------|
| Phase 1 | Bridge reports, Vue scaffolding, layout | DONE |
| Phase 2 | 13 pages, backlog tree+kanban, pipelines, n8n, file browser, i18n, project selector | DONE |
| Phase 2.5 | Filters, persistence, markdown viewer/editor, context switch, create project | DONE |
| Phase 3 | Per-user tokens, user management, file access control, chat sessions | DONE |

**Infraestructura actual**: 13 pages, 8 stores, 28 components, 18 E2E test files, 42 unit test files.

---

## Roadmap priorizado

### P1 — Visual Git Manager (NUEVO)

**Relevancia estrategica: ALTA**
Razon: Git es el nucleo de cualquier equipo de desarrollo. Tener un gestor visual de Git integrado en savia-web elimina la dependencia de herramientas externas (GitKraken, Sourcetree, terminal) y posiciona a Savia como plataforma completa de desarrollo. Es la feature que mas diferencia a savia-web de un dashboard de reportes.

**Modelo de referencia**: Ungit (10.5K stars, MIT) — web UI + backend git ops.

**3 sub-fases incrementales:**

#### P1.a — Git Viewer (read-only)
- 5 endpoints Bridge: `/git/log`, `/git/branches`, `/git/show`, `/git/diff`, `/git/status`
- 8 componentes Vue: GitPage, GitBranchList, GitCommitGraph (SVG), GitCommitList, GitCommitDetail, GitDiffViewer
- Store: `git.ts` con paginacion cursor-based
- Grafo SVG custom: algoritmo de lanes inspirado en Ungit/@gitgraph/core
- ~200 lineas Bridge + 8 ficheros frontend

#### P1.b — Staging + acciones
- 6 endpoints Bridge: stage, unstage, commit, push, pull, branch CRUD
- 4 componentes: GitStagingArea, GitCommitForm, GitSyncBar, GitBranchActions
- ~150 lineas Bridge + 4 ficheros frontend

#### P1.c — Features avanzados
- 6 endpoints Bridge: merge, stash, blame, search, tags
- 6 componentes: GitMergeDialog, GitStashPanel, GitBlameView, GitSearchBar, GitTagList, GitConflictViewer
- ~200 lineas Bridge + 6 ficheros frontend

**Seguridad**: subprocess shell=False, SHA hex-only, branch name regex, path traversal protection, timeout 10-30s.

**Ficheros criticos**:
- `scripts/savia-bridge.py` — Endpoints git (patron existente en linea 2133)
- `src/stores/git.ts` — Nuevo Pinia store
- `src/components/git/GitCommitGraph.vue` — SVG graph renderer
- `src/pages/GitPage.vue` — Pagina principal
- `src/types/git.ts` — Interfaces TypeScript

---

### P2 — Regression Plan + test coverage gaps

**Relevancia estrategica: ALTA**
Razon: El fichero `specs/regression-plan.md` existe pero los tests E2E no cubren todas las paginas. Antes de anadir mas features, consolidar la base de tests previene regresiones. La nueva regla `e2e-screenshot-validation.md` exige capturas en cada test.

**Tareas**:
- Revisar `specs/regression-plan.md` y cubrir gaps
- Anadir screenshots obligatorios a todos los E2E existentes (17 ficheros)
- Asegurar cobertura unit tests >= 80%
- Output screenshots en `output/e2e-results/savia-web/`

---

### P3 — Notificaciones en tiempo real (WebSocket/SSE)

**Relevancia estrategica: MEDIA-ALTA**
Razon: Actualmente la UI depende de polling o recarga manual. Notificaciones push para eventos del Bridge (nuevo commit, PR, cambio de estado en backlog, mensaje de chat) mejoran la experiencia colaborativa. Es prerequisito para que el Git Manager muestre cambios en vivo.

**Tareas**:
- Ampliar SSE del Bridge (ya existe para chat) a eventos genericos
- Store de notificaciones en frontend
- Componente toast/badge en TopBar
- Integracion con git store (refresh on push/pull events)

---

### P4 — Dashboard mejorado con metricas reales

**Relevancia estrategica: MEDIA**
Razon: HomePage muestra datos mock/basicos. Conectar con datos reales de Azure DevOps y metricas del Bridge (velocity, burndown, DORA) convierte el dashboard en herramienta de decision diaria.

**Tareas**:
- Conectar `/reports/*` con datos reales del Bridge (actualmente mock con seed 42)
- Widgets configurables por rol (PM ve velocity, dev ve PRs pendientes)
- Refresh periodico o push via SSE

---

### P5 — Approvals + Code Review integrado

**Relevancia estrategica: MEDIA**
Razon: La pagina `/approvals` existe pero con funcionalidad basica. Integrar con el Git Manager (PRs, diffs, approve/reject) y con el backlog (spec approvals) cierra el ciclo de revision dentro de savia-web.

**Tareas**:
- Conectar approvals con PRs del Git Manager
- Diff viewer reutilizado de GitDiffViewer
- Flujo approve/reject con comentarios
- Enlace bidireccional approval <-> backlog item

---

### P6 — Mobile responsive + PWA

**Relevancia estrategica: MEDIA-BAJA**
Razon: savia-web funciona en desktop. Responsive + PWA permite acceso desde movil para consultas rapidas (sprint status, chat, aprobar PRs). No es critico pero amplifica el alcance.

**Tareas**:
- Responsive breakpoints para sidebar colapsable
- PWA manifest + service worker basico
- Touch-friendly en Git graph y kanban

---

### P7 — Integraciones externas (Slack, Teams, webhooks)

**Relevancia estrategica: BAJA**
Razon: El Bridge soporta conectores pero la UI no los expone. La pagina `/integrations` existe con funcionalidad basica. Completar las integraciones es util pero secundario frente a las features core.

**Tareas**:
- UI para configurar webhooks
- Panel de integraciones activas con health check
- Conectar con `connectors-config.md`

---

## Resumen de priorizacion

| # | Feature | Valor | Esfuerzo | Razon priorizacion |
|---|---------|-------|----------|-------------------|
| P1 | Git Manager | Alto | Alto (3 sub-fases) | Core differentiator, elimina dependencia de tools externos |
| P2 | Test coverage | Alto | Medio | Consolida base antes de crecer, previene regresiones |
| P3 | Notificaciones RT | Medio-Alto | Medio | Prerequisito para UX colaborativa, complementa Git Manager |
| P4 | Dashboard real | Medio | Medio | Convierte dashboard en herramienta de decision |
| P5 | Approvals + CR | Medio | Medio | Cierra ciclo de revision dentro de savia-web |
| P6 | Mobile + PWA | Medio-Bajo | Medio | Amplifica alcance, no critico |
| P7 | Integraciones | Bajo | Bajo | Secundario frente a features core |

---

## Verificacion (para P1 — Git Manager)

1. **Bridge tests**: Tests en `scripts/tests/test_bridge_endpoints.py` para cada endpoint git
2. **Unit tests**: Vitest para store git y componentes
3. **E2E tests**: Playwright con screenshots obligatorios en `output/e2e-results/savia-web/`
4. **Manual**: https://localhost:5173/git con Bridge corriendo, verificar grafo, branches, diff

---

## Anexo A — Investigacion de proyectos open-source (Git visualization)

### Tier 1: Modelos principales para la implementacion

| Proyecto | Stars | Licencia | URL | Lenguaje | Relevancia para savia-web |
|----------|-------|----------|-----|----------|--------------------------|
| **Ungit** | 10,569 | MIT | https://github.com/FredrikNoren/ungit | JS/Node.js | **Modelo principal**. Web-based git client con grafo visual interactivo. Arquitectura web UI -> backend git ops via subprocess. Drag-and-drop merge/rebase. Clean UI. Activo (actualizado 2026-03-14) |
| **isomorphic-git** | 8,110 | MIT | https://github.com/isomorphic-git/isomorphic-git | JS | Implementacion pura JS de git para Node y browsers. API: clone, commit, push, pull, branch, merge, log, diff, status. No usable directamente (Bridge es Python) pero referencia para API design y operaciones soportadas |
| **Gitea** | 54,297 | MIT | https://github.com/go-gitea/gitea | Go+TS | Forge completa self-hosted. Patrones UI excelentes: diff viewer con side-by-side, commit list con grafo, branch management, PR flow. Referencia para el diseno de GitDiffViewer y GitCommitList |
| **lazygit** | 74,278 | MIT | https://github.com/jesseduffield/lazygit | Go | TUI (no web), pero el mejor UX de git existente. Referencia para: flujo de staging, keyboard shortcuts, workflow de commit+push. Inspiracion para GitStagingArea y flujo de acciones |

### Tier 2: Librerias de visualizacion de grafos

| Proyecto | Stars | Licencia | URL | Estado | Relevancia |
|----------|-------|----------|-----|--------|-----------|
| **@gitgraph/js** | 3,064 | MIT | https://github.com/nicoespeon/gitgraph.js | ARCHIVADO (Jul 2024) | Libreria JS para dibujar grafos git. El paquete `@gitgraph/core` contiene el algoritmo de lane assignment que usaremos como referencia. No usar la libreria directamente (archivada), pero el algoritmo es valido |
| **Mermaid gitgraph** | (parte de mermaid) | MIT | https://mermaid.ai/open-source/syntax/gitgraph.html | Activo | Diagramas git en markdown. Bueno para documentacion estatica, NO para visualizacion interactiva de repos reales. Descartado para este uso |
| **visualizing-git** | 1,375 | MIT | https://github.com/git-school/visualizing-git | Activo | Tool educativo con D3.js. Util como referencia de rendering SVG basico de grafos git, pero demasiado simple para produccion |
| **git-graph-drawing** | 40 | Unlicense | https://github.com/indigane/git-graph-drawing | Activo | React component para commit log graphs con paginacion. Referencia menor |

### Tier 3: Forjas completas (referencia de UI patterns)

| Proyecto | Stars | Licencia | URL | Relevancia |
|----------|-------|----------|-----|-----------|
| **Forgejo** | fork de Gitea | GPLv3+ | https://forgejo.org/ | Fork comunitario de Gitea. Mismos patrones UI. Licencia copyleft (no copiar codigo, solo inspiracion) |
| **GitHub Desktop** | ~open source | MIT | Desktop app. Patrones de diff viewer y branch management como referencia visual |
| **LithiumGit** | Open source | - | https://lithiumgit.com/ | Interactive graph view con operaciones directas desde el grafo. Inspiracion para interactividad |

### Decision: por que SVG custom y no una libreria

1. **@gitgraph/js archivado** — Mantenedor recomienda Mermaid, que no es interactivo
2. **No existe libreria Vue activa** — Busqueda exhaustiva: no hay `vue-git-graph` ni equivalente
3. **SVG es nativo de Vue** — Cada nodo/path es un componente Vue con eventos click/hover
4. **Canvas descartado** — Requiere hit-testing manual, rompe accesibilidad, no reactivo
5. **HTML/CSS descartado** — Curvas de ramas son complejas en CSS puro (Ungit lo hace pero es fragil)

---

## Anexo B — Diseno tecnico detallado del Git Manager

### B.1 — Endpoints Bridge detallados

#### GET `/git/log?project={id}&limit=50&cursor={sha}&branch={name}`

```
Git command: git log --format="%H%x00%h%x00%s%x00%an%x00%ae%x00%aI%x00%P%x00%D" --max-count=51 [--all | branch] [cursor..]
```

Formato custom usa `%x00` (null byte) como separador para evitar ambiguedad con contenido de commits.

Respuesta:
```json
{
  "commits": [{
    "sha": "abc123...",
    "short_sha": "abc123",
    "message": "feat: add login page",
    "author_name": "Alice",
    "author_email": "alice@example.com",
    "date": "2026-03-15T10:30:00Z",
    "parents": ["def456..."],
    "refs": [{ "name": "main", "type": "branch" }, { "name": "v1.0", "type": "tag" }]
  }],
  "has_more": true
}
```

Paginacion: `limit=50` pide 51 resultados. Si llegan 51, `has_more=true` y se descarta el 51. `cursor` es el SHA del ultimo commit visible.

#### GET `/git/branches?project={id}`

```
Git command: git branch -a --format='%(refname:short)%00%(objectname:short)%00%(upstream:short)%00%(HEAD)'
```

Respuesta:
```json
{
  "branches": [{
    "name": "main",
    "sha": "abc123",
    "upstream": "origin/main",
    "is_current": true,
    "is_remote": false
  }]
}
```

#### GET `/git/show?project={id}&sha={sha}`

```
Git command: git show --stat --format="%H%x00%B%x00%an%x00%ae%x00%aI%x00%P" {sha}
```

Respuesta: `{ sha, message, author_name, author_email, date, parents, files: [{ path, additions, deletions, status }] }`

#### GET `/git/diff?project={id}&sha={sha}&file={path}`

```
Git command: git diff {sha}~1..{sha} -- {file}
```

Respuesta:
```json
{
  "hunks": [{
    "header": "@@ -10,5 +10,8 @@",
    "lines": [
      { "type": "context", "content": "  existing line", "old_line": 10, "new_line": 10 },
      { "type": "deletion", "content": "- removed line", "old_line": 11, "new_line": null },
      { "type": "addition", "content": "+ added line", "old_line": null, "new_line": 11 }
    ]
  }]
}
```

#### GET `/git/status?project={id}`

```
Git command: git status --porcelain=v2 --branch
```

Respuesta: `{ branch, ahead, behind, files: [{ path, status, staged }] }`

### B.2 — Interfaces TypeScript (`src/types/git.ts`)

```typescript
export interface GitCommit {
  sha: string
  short_sha: string
  message: string
  author_name: string
  author_email: string
  date: string
  parents: string[]
  refs: GitRef[]
}

export interface GitRef {
  name: string
  type: 'branch' | 'tag' | 'remote'
}

export interface GitBranch {
  name: string
  sha: string
  upstream: string | null
  is_current: boolean
  is_remote: boolean
}

export interface GitFileChange {
  path: string
  additions: number
  deletions: number
  status: 'A' | 'M' | 'D' | 'R' | 'C'
}

export interface GitDiffHunk {
  header: string
  lines: GitDiffLine[]
}

export interface GitDiffLine {
  type: 'context' | 'addition' | 'deletion'
  content: string
  old_line: number | null
  new_line: number | null
}

export interface GitStatus {
  branch: string
  ahead: number
  behind: number
  files: GitStatusFile[]
}

export interface GitStatusFile {
  path: string
  status: string
  staged: boolean
}
```

### B.3 — Algoritmo del grafo SVG

```
Input: commits[] ordenados topologicamente (git log ya lo da)

1. lanes = Map<string, number>  // branchName -> laneIndex
2. nextLane = 0
3. commitLanes = Map<string, number>  // sha -> lane

Para cada commit en orden:
  a. Si commit tiene refs con tipo 'branch':
     - Usar lane de esa rama (o asignar nextLane++ si nueva)
  b. Si no tiene refs pero tiene un solo padre:
     - Heredar lane del padre
  c. Si es merge commit (2+ padres):
     - Mantener lane del primer padre
     - El segundo padre dibuja linea diagonal desde su lane

Renderizado SVG:
  - Row height: 32px, Lane width: 16px
  - Commit circle: cx = lane * 16 + 8, cy = row * 32 + 16, r = 5
  - Parent-child path: SVG <path> con curva bezier entre circulos
  - Colores: hash(branchName) % palette.length (paleta de 10 colores Savia)
  - Virtual scroll: solo renderizar filas visibles (IntersectionObserver)
```

### B.4 — Seguridad (detalle)

```python
# Validadores (anadir en savia-bridge.py junto a los existentes de git-config)
_SAFE_SHA = re.compile(r'^[0-9a-f]{4,40}$')
_SAFE_BRANCH = re.compile(r'^[a-zA-Z0-9._/\-]{1,200}$')
_SAFE_COMMIT_MSG = re.compile(r'^[^\x00-\x08\x0b\x0c\x0e-\x1f]{1,5000}$')

# Resolver repo path con proteccion anti-traversal
def _resolve_git_repo(project_id: str) -> Path | None:
    repo = (WORKSPACE / "projects" / project_id).resolve()
    if not str(repo).startswith(str(WORKSPACE.resolve())):
        return None  # path traversal
    if not (repo / ".git").is_dir():
        return None  # no es repo git
    return repo

# Todos los subprocess:
subprocess.run(
    ['git', 'log', ...],  # SIEMPRE lista, NUNCA string
    cwd=str(repo),        # SIEMPRE en el repo
    capture_output=True,
    text=True,
    timeout=10,           # 10s lectura, 30s push/pull
    # shell=False es default, NUNCA poner shell=True
)
```

### B.5 — Patrones existentes a reutilizar

| Patron | Donde existe | Reutilizar en |
|--------|-------------|---------------|
| `useBridge().get<T>()` | `src/composables/useBridge.ts` | Todos los fetch del git store |
| `projectStore.selectedId` watch | `src/stores/backlog.ts` (linea 1) | `src/stores/git.ts` — reload on project switch |
| Path traversal check | `savia-bridge.py` linea 2542 (`/files` endpoint) | `_resolve_git_repo()` |
| Input regex validation | `savia-bridge.py` linea 3175 (`_SAFE_GIT_VALUE`) | `_SAFE_SHA`, `_SAFE_BRANCH` |
| `Bearer` auth check | `savia-bridge.py` `_check_auth()` | Todos los endpoints git write |
| Three-panel layout | `BacklogPage.vue` (sidebar + list + detail) | `GitPage.vue` (branches + graph + detail) |
| Monospace code rendering | `src/components/files/` | `GitDiffViewer.vue` |
| i18n pattern | Todas las pages usan `useI18n()` | GitPage y componentes |
| `marked` markdown rendering | `src/components/files/MarkdownViewer.vue` | Render de commit messages con markdown |

### B.6 — Layout de la pagina Git

```
+---------------------------------------------------+
| TopBar (existing)                                  |
+----------+------------------------+----------------+
| Branch   | Commit Graph + List    | Commit Detail  |
| List     |                        |                |
|          | [o]---[o]---[o] main   | SHA: abc123    |
| > main   |       \              | Author: Alice  |
|   develop |        [o]---[o] dev  | Date: 2026-03  |
|   feature |                        |                |
|          | [scroll loads more]    | Files changed: |
|          |                        | - src/foo.ts   |
|          |                        | - src/bar.ts   |
+----------+                        +----------------+
| Staging  |                        | Diff Viewer    |
| Area     |                        | (on file click)|
| (Phase2) |                        |                |
+----------+------------------------+----------------+
```

### B.7 — Desafios conocidos y mitigaciones

| Desafio | Mitigacion |
|---------|-----------|
| Repos con 10K+ commits: grafo lento | Paginacion cursor-based (50 commits/pagina), virtual scroll SVG |
| Muchas ramas: grafo ancho | Filtrar por rama, colapsar ramas mergeadas, max 10 lanes visibles |
| Ficheros binarios en diffs | Detectar en `--stat` output, mostrar "Binary file changed" |
| Merge conflicts en Phase 2/3 | Phase 2 solo muestra status; Phase 3 anade side-by-side basico |
| Bridge file size (ya 3680 lineas) | Extraer funciones git a `scripts/savia_bridge_git.py` importado por el bridge |
| Push/pull lentos en repos grandes | Timeout 30s, feedback de progreso via SSE (futuro P3) |
