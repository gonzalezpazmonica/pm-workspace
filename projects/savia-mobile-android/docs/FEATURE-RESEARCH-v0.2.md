# Savia Mobile — Investigación de Funciones v0.2+

> **Fecha**: 8 marzo 2026
> **Contexto**: PM-Workspace tiene 457+ comandos, 33 agentes y 43 skills. La app móvil (v0.1.0) tiene chat SSE, sesiones y ajustes básicos. Este documento analiza qué funciones del workspace tienen sentido en móvil sin saturar la experiencia.

---

## Principios de Diseño Móvil

1. **Complementario, no sustitutivo** — El móvil resuelve lo que el desktop no: movilidad, rapidez, voz, notificaciones push.
2. **Read-heavy, write-light** — En móvil se consulta mucho y se escribe poco. Priorizar dashboards y consultas rápidas.
3. **3 toques máximo** — Cualquier acción frecuente debe completarse en 3 interacciones o menos.
4. **Offline-first** — Los datos clave deben estar cacheados localmente para consulta sin conexión.
5. **No saturar** — Mejor 20 funciones bien hechas que 100 mediocres. Cada pantalla tiene un propósito claro.

---

## 1. Selector de Proyecto

### Problema
La app actual no tiene concepto de "proyecto". Todo va al workspace general. PM-Workspace gestiona múltiples proyectos con distintos equipos, iteraciones y backlogs.

### Propuesta

**Pantalla de selección de proyecto** como primer paso tras el login o accesible desde un dropdown en la barra superior.

| Elemento | Detalle |
|----------|---------|
| **Vista** | Lista de cards con nombre del proyecto, equipo asignado y estado del sprint actual |
| **Datos** | Se obtienen de `pm-config.md` (constantes Azure DevOps) vía Bridge |
| **Persistencia** | Último proyecto seleccionado se guarda en DataStore |
| **Impacto** | Toda la app se contextualiza al proyecto: dashboard, comandos, notificaciones |

### Nuevo endpoint Bridge
```
GET /projects → [{id, name, team, currentSprint, health}]
```

### Prioridad: **ALTA** (prerequisito para la mayoría de funciones)

---

## 2. Botonera de Comandos por Familias

### Problema
PM-Workspace tiene 457+ slash commands. Escribirlos en chat es tedioso en móvil. Necesitamos un acceso visual organizado.

### Propuesta

**Command Palette** con pestañas por familia + buscador integrado.

#### Familias propuestas (10 familias, ~40 comandos móvil-friendly)

| Familia | Icono | Comandos móvil-friendly | Tipo |
|---------|-------|------------------------|------|
| **Sprint** | 🏃 | sprint-status, sprint-forecast, velocity-trend, board-flow, kpi-dashboard | Solo lectura |
| **Mi Trabajo** | 👤 | my-sprint (nuevo), team-workload, pbi-assign | Lectura + acción |
| **Backlog** | 📋 | backlog-capture, pbi-decompose, pbi-jtbd | Escritura rápida |
| **Horas** | ⏱️ | report-hours, daily-log (nuevo) | Escritura rápida |
| **Calidad** | ✅ | pr-pending, testplan-status, security-alerts | Solo lectura |
| **Equipo** | 👥 | team-workload, report-capacity, team-onboarding | Solo lectura |
| **Repos** | 🔀 | repos-pr-list, pr-review (resumen), repos-branches | Lectura + links |
| **Pipelines** | 🚀 | pipeline-status, pipeline-run | Lectura + 1 acción |
| **Infra** | ☁️ | infra-status, infra-estimate | Solo lectura |
| **Conectores** | 🔗 | notify-slack, notify-whatsapp, slack-search | Acción rápida |

#### UX del Command Palette

```
┌──────────────────────────────┐
│ 🔍 Buscar comando...        │
├──────────────────────────────┤
│ Sprint │ Mi Trabajo │ Backlog│ ← Tabs scrollables
├──────────────────────────────┤
│ ┌────────┐ ┌────────┐       │
│ │ 🏃     │ │ 📊     │       │ ← Grid 2 columnas
│ │ Sprint │ │ Veloci- │       │
│ │ Status │ │ dad     │       │
│ └────────┘ └────────┘       │
│ ┌────────┐ ┌────────┐       │
│ │ 🎯     │ │ 📈     │       │
│ │ Board  │ │ KPI    │       │
│ │ Flow   │ │ Dash   │       │
│ └────────┘ └────────┘       │
└──────────────────────────────┘
```

- **Búsqueda**: Filtra por nombre y descripción en tiempo real
- **Favoritos**: El usuario puede marcar comandos como favoritos (aparecen primero)
- **Recientes**: Los últimos 5 comandos usados se muestran al abrir
- **Ejecución**: Al pulsar un comando, se pre-llena el chat con el slash command y el proyecto seleccionado

### Nuevo endpoint Bridge
```
GET /commands → [{name, family, description, params, mobileEnabled}]
POST /execute → {command, project, params} → SSE stream
```

### Prioridad: **ALTA** (diferenciador principal de la app)

---

## 3. Perfil de Usuario

### Problema
La app no muestra quién eres ni tu rol. PM-Workspace tiene datos del PM user configurado.

### Propuesta

**Pantalla de perfil** accesible desde Settings o avatar en la barra.

| Sección | Datos | Fuente |
|---------|-------|--------|
| **Identidad** | Nombre, email, foto Google | GoogleAuthManager (ya existe) |
| **Rol PM** | Display name, organización | `pm-config.md` → `AZURE_DEVOPS_PM_USER`, `PM_DISPLAY` |
| **Estadísticas** | Sprints gestionados, PBIs cerrados, horas logadas | Azure DevOps queries |
| **Proyectos activos** | Lista de proyectos asignados | `pm-config.md` |
| **Preferencias** | Tema, idioma, notificaciones | DataStore local |

### Nuevo endpoint Bridge
```
GET /profile → {name, email, role, org, stats: {sprints, pbis, hours}}
```

### Prioridad: **MEDIA** (mejora la personalización)

---

## 4. Datos de la Empresa / Organización

### Problema
No hay visibilidad del contexto organizacional desde la app.

### Propuesta

**Sección Organización** en Settings o como pantalla dedicada.

| Dato | Fuente |
|------|--------|
| Nombre org | `AZURE_DEVOPS_ORG_NAME` |
| URL Azure DevOps | `AZURE_DEVOPS_ORG_URL` |
| Proyectos activos | Conteo de proyectos configurados |
| Equipos | Lista de equipos por proyecto |
| Cadencia sprint | `SPRINT_DURATION_WEEKS`, días, horarios |
| Métricas DORA | Deployment frequency, lead time, MTTR, change failure rate |
| Conectores activos | Slack, GitHub, Sentry, etc. (cuáles están configurados) |

### Prioridad: **BAJA** (informativo, no accionable)

---

## 5. Dashboard Inteligente (Rediseño de la Home)

### Problema
La pantalla actual de Dashboard (Sessions) solo muestra conversaciones. Podría ser mucho más útil como centro de control.

### Propuesta

**Home redesignada** con widgets configurables:

```
┌──────────────────────────────┐
│ 👋 Buenos días, Mónica       │
│ Proyecto: Alpha · Sprint 24  │
├──────────────────────────────┤
│ ┌──────────────────────────┐ │
│ │ Sprint Progress    78%   │ │ ← Widget: barra de progreso
│ │ ████████████░░░░  12/15  │ │
│ └──────────────────────────┘ │
│ ┌────────────┐┌────────────┐ │
│ │ 🔴 3       ││ ⏱️ 6.5h    │ │ ← Widget doble
│ │ Bloqueados ││ Hoy logadas│ │
│ └────────────┘└────────────┘ │
│ ┌──────────────────────────┐ │
│ │ 📋 Mis tareas (5)       │ │ ← Widget: lista compacta
│ │ • Fix auth bug    [▓▓░]  │ │
│ │ • Update API docs [▓░░]  │ │
│ │ • Review PR #45   [░░░]  │ │
│ └──────────────────────────┘ │
│ ┌──────────────────────────┐ │
│ │ 🔔 Actividad reciente    │ │ ← Widget: feed
│ │ Juan completó PBI-234    │ │
│ │ PR #67 aprobado          │ │
│ │ Pipeline deploy OK       │ │
│ └──────────────────────────┘ │
├──────────────────────────────┤
│ 💬 Chat  │ 🏠 Home │ ⚡ Cmd │ ← Nav inferior rediseñada
└──────────────────────────────┘
```

### Widgets disponibles
1. **Sprint Progress** — Barra con SP completados / total
2. **Blockers** — Contador de items bloqueados (tappable)
3. **Mis Tareas** — Lista compacta de tareas asignadas al PM
4. **Horas Hoy** — Timer de horas logadas + botón de log rápido
5. **Activity Feed** — Últimos eventos del proyecto (PRs, deploys, PBIs)
6. **Velocity** — Mini-gráfico de velocidad últimos 5 sprints
7. **Health Score** — Radar compacto del workspace health

### Prioridad: **ALTA** (transforma la app de "chat client" a "PM companion")

---

## 6. Captura Rápida (Voice-to-PBI)

### Problema
Las ideas surgen en movimiento. Capturar un PBI desde el desktop requiere abrir Azure DevOps, rellenar formularios, etc.

### Propuesta

**Botón flotante de captura rápida** (FAB) presente en todas las pantallas:

1. **Texto**: Campo de texto libre → se envía como `/backlog-capture {texto}`
2. **Voz**: Usa `SpeechRecognizer` de Android → transcripción → `/backlog-capture`
3. **Foto**: Cámara o galería → adjunto al PBI (futuro)

El Bridge procesa la captura y devuelve confirmación con ID del Work Item creado.

### Nuevo endpoint Bridge
```
POST /capture → {type: "pbi"|"bug"|"note", content, project} → {workItemId, url}
```

### Prioridad: **ALTA** (ventaja exclusiva del móvil)

---

## 7. Log Rápido de Horas

### Problema
La imputación de horas es una tarea diaria obligatoria en muchas empresas. Hacerla desde el desktop es tedioso.

### Propuesta

**Widget de timer + log manual**:

```
┌──────────────────────────────┐
│ ⏱️ Tiempo Hoy: 6h 30m       │
├──────────────────────────────┤
│ Task     │ Horas │ Estado    │
│──────────│───────│──────────│
│ PBI-234  │ 3.0h  │ ✅       │
│ PBI-456  │ 2.5h  │ ✅       │
│ PBI-789  │ 1.0h  │ 🔄       │
├──────────────────────────────┤
│ [+ Añadir entrada]          │
└──────────────────────────────┘
```

- **Log rápido**: Seleccionar tarea → horas → guardar (3 toques)
- **Timer activo**: Iniciar/parar cronómetro por tarea
- **Resumen semanal**: Vista de horas por día de la semana
- **Sincronización**: Se persiste en Room + sync a Azure DevOps vía Bridge

### Nuevo endpoint Bridge
```
POST /time-log → {taskId, hours, date, note}
GET /time-log/today → [{taskId, hours, note}]
GET /time-log/week → [{date, entries: [...]}]
```

### Prioridad: **MEDIA-ALTA** (necesidad diaria, encaja perfecto en móvil)

---

## 8. Notificaciones Push Inteligentes

### Problema
El PM se entera tarde de bloqueos, PRs pendientes, fallos de pipeline.

### Propuesta

**Firebase Cloud Messaging** con categorías configurables:

| Categoría | Trigger | Prioridad |
|-----------|---------|-----------|
| **Blocker** | Work item marcado como Blocked | Alta (sonido) |
| **PR pendiente** | PR asignado al PM sin review > 4h | Media |
| **Pipeline fallo** | Build o deploy fallido | Alta |
| **Sprint** | Planning/Review/Retro a punto de empezar | Media (15min antes) |
| **Capacity** | Equipo por encima del WIP limit | Baja |
| **Deploy** | Deploy exitoso a PRO | Baja (informativa) |

### Implementación
- Bridge expone `/notifications/subscribe` con FCM token
- Un cron job en el Bridge (o tarea programada) consulta Azure DevOps periódicamente
- Envía push vía Firebase Admin SDK cuando detecta eventos relevantes

### Prioridad: **MEDIA** (requiere Firebase setup + cron en Bridge)

---

## 9. Aprobaciones Rápidas

### Problema
Ciertas acciones en PM-Workspace requieren aprobación humana (infra, deploys a PRO, PRs).

### Propuesta

**Panel de aprobaciones** en la Home con acción directa:

```
┌──────────────────────────────┐
│ ⚡ Pendiente de tu aprobación │
├──────────────────────────────┤
│ 🔀 PR #67: Fix auth cache   │
│ Juan García · hace 2h        │
│ [✅ Aprobar] [❌ Rechazar]    │
├──────────────────────────────┤
│ ☁️ Infra: Scale API to 4 pods│
│ Coste: +€45/mes              │
│ [✅ Aprobar] [❌ Rechazar]    │
└──────────────────────────────┘
```

- **PRs**: Ver resumen + aprobar/rechazar (link a GitHub/DevOps para diff completo)
- **Infra**: Ver propuesta + coste estimado → aprobar/rechazar
- **Deploys**: Aprobar promoción PRE→PRO

### Prioridad: **MEDIA** (alto valor, complejidad moderada)

---

## 10. Kanban Compacto

### Problema
Ver el tablero del sprint requiere abrir Azure DevOps en el navegador.

### Propuesta

**Vista Kanban horizontal scrollable** con las columnas del sprint:

```
┌──────────┬──────────┬──────────┬──────────┐
│ New (3)  │ Active(5)│ Review(2)│ Done(12) │
├──────────┼──────────┼──────────┼──────────┤
│ ┌──────┐ │ ┌──────┐ │ ┌──────┐ │ ┌──────┐ │
│ │PBI-45│ │ │PBI-23│ │ │PBI-12│ │ │PBI-01│ │
│ │Fix.. │ │ │API.. │ │ │Auth..│ │ │Setup │ │
│ │👤Juan│ │ │👤Ana │ │ │👤PM  │ │ │👤All │ │
│ │3 SP  │ │ │5 SP  │ │ │2 SP  │ │ │1 SP  │ │
│ └──────┘ │ └──────┘ │ └──────┘ │ └──────┘ │
└──────────┴──────────┴──────────┴──────────┘
```

- **Solo lectura** en v1 (mover cards es complejo en móvil)
- **Filtros**: Por persona, por estado, por prioridad
- **Tap en card**: Expande detalle con descripción, acceptance criteria, tasks

### Prioridad: **MEDIA** (visual, pero Azure DevOps web ya lo tiene)

---

## Navegación Propuesta (v0.2)

### Barra inferior (4 tabs)

| Tab | Pantalla | Contenido |
|-----|----------|-----------|
| 🏠 **Home** | Dashboard inteligente | Widgets, actividad, resumen sprint |
| 💬 **Chat** | Chat conversacional | Chat SSE actual + slash commands |
| ⚡ **Comandos** | Command Palette | Familias, buscador, favoritos, recientes |
| 👤 **Perfil** | Perfil + Settings | Datos usuario, proyecto, ajustes |

### Flujos principales

```
Home → Ver sprint → Tap blocker → Detalle PBI → Chat para resolver
Home → FAB captura → Voz/texto → PBI creado
Comandos → Sprint Status → Dashboard sprint
Comandos → Report Hours → Log rápido
Chat → Escribir /sprint-status → Respuesta streaming
Perfil → Cambiar proyecto → Home se actualiza
```

---

## Resumen de Prioridades

| # | Función | Prioridad | Complejidad | Dependencias |
|---|---------|-----------|-------------|-------------|
| 1 | Selector de proyecto | **Alta** | Baja | Bridge endpoint |
| 2 | Command Palette por familias | **Alta** | Media | Bridge endpoint + catálogo |
| 5 | Dashboard inteligente (Home) | **Alta** | Alta | Proyecto seleccionado + Bridge queries |
| 6 | Captura rápida (voz/texto) | **Alta** | Media | SpeechRecognizer + Bridge |
| 7 | Log rápido de horas | **Media-Alta** | Media | Bridge + Azure DevOps |
| 3 | Perfil de usuario | **Media** | Baja | Google Auth + pm-config |
| 8 | Notificaciones push | **Media** | Alta | Firebase + Bridge cron |
| 9 | Aprobaciones rápidas | **Media** | Media | Bridge + Azure DevOps |
| 10 | Kanban compacto | **Media** | Media | Bridge + Azure DevOps |
| 4 | Datos organización | **Baja** | Baja | pm-config |

---

## Funciones que NO llevar al móvil

Estas funciones deben quedarse exclusivamente en desktop:

- **Edición de código** y diffs de PR (pantalla demasiado pequeña)
- **Generación de specs** (SDD) — documentos técnicos extensos
- **Orquestación de agentes** — ejecuciones de 10-40 minutos
- **Diagramas de arquitectura** — requieren lienzo grande
- **Infraestructura provisioning** — complejidad y riesgo
- **Informes ejecutivos complejos** — PPT/Word de múltiples páginas
- **COBOL migration** — contexto masivo
- **Security audit completo** — resultados extensos

Para estas funciones, el móvil puede **notificar** cuando se completan y mostrar un **resumen**, pero la ejecución y revisión se hace en desktop.

---

## Próximos Pasos

1. Diseñar wireframes de las 4 pantallas principales (Home, Chat, Comandos, Perfil)
2. Definir los endpoints del Bridge necesarios para v0.2
3. Crear PBIs en el backlog para cada función priorizada
4. Implementar selector de proyecto + Command Palette como primera iteración
5. Iterar el dashboard con widgets incrementales
