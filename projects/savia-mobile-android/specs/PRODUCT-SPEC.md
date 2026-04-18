# Savia Mobile — Especificación de Producto

## 1. Descripción General

**Nombre**: Savia Mobile
**Plataforma**: Android (nativo, Jetpack Compose)
**Versión**: 0.3.34
**Usuarios Objetivo**: Gestores de proyectos, líderes técnicos, desarrolladores
**Descripción**: Aplicación móvil nativa para Android que proporciona interfaz de gestión de proyectos y conversacional con Claude Code a través de la arquitectura Savia Bridge. Dashboard con métricas de sprint, selección de proyecto/sprint, perfil de usuario, gestión de equipo/empresa, y chat con streaming SSE.

## 2. Usuarios Objetivo

### la usuaria (PM/Technical Lead)
- **Rol**: Gestora técnica de proyectos
- **Necesidad**: Gestión de proyectos y acceso a Claude desde el móvil
- **Dolor**: Dependencia de laptop; necesita movilidad
- **Objetivo**: Dashboard de sprints, chat con streaming, perfil, gestión de equipo

### Carlos (Engineering Manager)
- **Rol**: Manager de ingeniería
- **Necesidad**: Consultar métricas y ayuda de Claude para arquitectura/diseño
- **Dolor**: No ver estado de sprints en tiempo real
- **Objetivo**: Dashboard de métricas, selección de proyecto/sprint, seguimiento

## 3. Pantallas y Funcionalidades

### 3.1 Home (Dashboard)

**Estado: ✅ FUNCIONAL (via REST /dashboard)**

La pantalla Home obtiene todos sus datos en una sola llamada REST al endpoint Bridge `GET /dashboard`. El Bridge lee los datos directamente del disco (CLAUDE.md, mock JSON files), sin depender de Claude CLI. Esto hace que la carga sea rapida (~5ms) y fiable.

| Funcionalidad | UI | Datos | Estado |
|---|---|---|---|
| Saludo personalizado ("Good morning, {nombre}") | ✅ greeting del dashboard | ✅ `GET /dashboard` → user.greeting | **OK** |
| Selector de proyecto (dropdown con buscador) | ✅ DropdownMenu con OutlinedTextField | ✅ `GET /dashboard` → projects[] | **OK** |
| Selector de sprint (dropdown con buscador) | ✅ DropdownMenu con OutlinedTextField | ✅ `GET /dashboard` → sprint.name | **OK** |
| Sprint Progress (barra + SP completados/total) | ✅ LinearProgressIndicator + texto | ✅ `GET /dashboard` → sprint.progress/completedPoints/totalPoints | **OK** |
| Métricas: items bloqueados | ✅ MetricCard | ✅ `GET /dashboard` → blockedItems | **OK** |
| Métricas: horas de hoy | ✅ MetricCard | ✅ `GET /dashboard` → hoursToday | **OK** |
| My Tasks (tareas Active) | ✅ MyTasksSection | ✅ `GET /dashboard` → myTasks[] | **OK** |
| Recent Activity (últimos items) | ✅ ActivityItem lista | ✅ `GET /dashboard` → recentActivity[] | **OK** |
| Quick Actions: "See Board" | ✅ Navega a KanbanScreen | N/A | **OK** |
| Quick Actions: "Approvals" | ✅ Navega a ApprovalsScreen | N/A | **OK** |
| FAB: captura rápida | ✅ FloatingActionButton | N/A | **OK** |
| Refresh en TopAppBar | ✅ Botón con icono | Refresca todo (loadDashboardData) | **OK** |
| Logo de Savia en TopAppBar | ✅ SaviaLogo component | Identificación visual | **OK** |
| Versión visible en TopAppBar | ✅ VersionBadge component | BuildConfig.VERSION_NAME | **OK** |

**Arquitectura**: HomeViewModel llama a `projectRepository.getDashboard()` que hace `GET /dashboard` al Bridge. El Bridge lee los datos del workspace (CLAUDE.md para metadata de proyectos, mock-sprint.json para datos de sprint, mock-workitems.json para tareas). Auto-selecciona el primer proyecto que tenga datos de sprint.

**TopAppBar adicionales**: Todas las pantallas (Home, Chat, Commands, Profile, Settings, etc.) incluyen Logo Savia + VersionBadge en TopAppBar para consistencia visual y identificación del producto.

### 3.2 Chat

**Estado: ✅ FUNCIONAL**

| Funcionalidad | Estado | Notas |
|---|---|---|
| Interfaz Compose + Material 3 | ✅ | Tema violeta/malva correcto |
| SSE Streaming | ✅ | Flow<StreamDelta> con Text/Done/Error |
| Historial persistente (Room DB) | ✅ | ChatRepository.getMessages() Flow |
| Sistema dual (Bridge + API fallback) | ✅ | Chequea hasBridgeConfig() primero |
| Markdown rendering (Markwon) | ✅ | StrikethroughPlugin + TablePlugin |
| Autocompletado de slash commands | ✅ | 6 comandos predefinidos en ChatInput |
| Error handling con snackbar | ✅ | SnackbarHostState en error |
| Auto-scroll al final | ✅ | animateScrollToItem en LaunchedEffect |
| session_id | ✅ | UUID dinámico generado por ChatViewModel |

**Nota**: El Chat funciona correctamente cuando el Bridge está activo. Usa un session_id UUID generado dinámicamente por ChatViewModel. El Bridge convierte automaticamente session_ids no-UUID a UUID v5 deterministas. Room Database es la única fuente de verdad (SSoT) para mensajes — el ViewModel se suscribe a un Flow de Room vía `subscribeToMessages()` y no añade mensajes manualmente al estado, evitando duplicados.

### 3.3 Commands

**Estado: ✅ FUNCIONAL (UI only)**

- 10 familias de comandos organizadas (hardcoded)
- Ejecución directa para comandos read-only
- Feedback visual con indicador de ejecución
- Los comandos se envían al Chat para ejecución

### 3.4 Profile

**Estado: ✅ FUNCIONAL**

| Funcionalidad | Estado | Fuente de datos |
|---|---|---|
| Cabecera: avatar, nombre, email, rol, org | ✅ | GET `/profile` (REST directo) |
| Stats: sprints, PBIs, horas | ✅ | GET `/profile` → campo `stats` |
| Proyectos activos con selector | ✅ | `getProjects()` → GET `/dashboard` (REST, fiable) |
| Check Updates (siempre visible) | ✅ | GET `/update/check` (REST directo) |
| Download Update | ✅ | GET `/update/download` → FileProvider → install intent |
| Progreso de descarga | ✅ | LinearProgressIndicator en UI |
| Instalación automática post-descarga | ✅ | ACTION_VIEW intent via FileProvider |
| Versión de app (siempre visible) | ✅ | BuildConfig.VERSION_NAME |
| Navegación a Settings | ✅ | TopAppBar engranaje |
| Estado sin Bridge: "Configure Bridge" + Retry | ✅ | Fallback UI |
| Carga paralela (profile + projects) | ✅ | async(Dispatchers.IO) |
| Timeout 20s | ✅ | withTimeout(20_000) |

### 3.4.1 TopAppBar — Logo + Versión (Todas las pantallas)

**Estado: ✅ FUNCIONAL**

| Elemento | Componentes | Pantallas | Estado |
|---|---|---|---|
| Logo Savia + Versión | SaviaLogo + VersionBadge | Home, Chat, Commands, Profile, Settings, GitConfig, TeamManagement, Company, Kanban, Approvals, Capture | ✅ |

**Descripción**: Todas las 13 pantallas principales incluyen en su TopAppBar el logo de Savia (identificación visual del producto) y un badge con la versión actual de la app (BuildConfig.VERSION_NAME). Esto proporciona consistencia visual y permite al usuario verificar la versión instalada en cualquier momento.

### 3.5 Settings

**Estado: ✅ FUNCIONAL**

| Funcionalidad | Estado | Fuente de datos |
|---|---|---|
| Bridge status card (verde/roja) | ✅ | SecurityRepository.hasBridgeConfig() |
| Perfil de usuario (nombre + email) | ✅ | GET `/profile` |
| Git Configuration | ✅ | GET/PUT `/git-config` |
| Team management | ✅ | GET/PUT `/team` |
| Company profile | ✅ | GET/PUT `/company` |
| Theme selector (SYSTEM/LIGHT/DARK) | ✅ | Local (SecureStorage) |
| Language selector (SYSTEM/ES/EN) | ✅ | Local (SecureStorage) |
| About (versión app + Bridge) | ✅ | BuildConfig + /health |
| Check Updates (duplicado) | ✅ | GET `/update/check` |
| Disconnect con confirmación | ✅ | AlertDialog → deleteBridgeConfig() |

### 3.6 Bridge Setup Dialog

**Estado: ✅ FUNCIONAL**

- **Campos**: Host, Port (default 8922), Token (texto plano, falta toggle visibilidad)
- **Validación**: Host no vacío, port 1-65535, token no vacío
- **Health check**: GET a `/health` con Bearer token (spec decía POST pero Bridge usa GET)
- **Loading**: Spinner + "Connecting..." durante health check
- **Error**: Mensaje de error con detalle
- **Auto-dismiss**: Se cierra al conectar
- **Dispatchers.IO**: Sí

### 3.7 Onboarding

**Estado: ✅ FUNCIONAL**

- AppStartupViewModel detecta Bridge configurado
- Detección de idioma (Locale.getDefault().language)
- Flujo correcto: sin Bridge → BridgeSetupDialog; con Bridge → Home

## 4. Navegación

### Bottom Navigation (4 tabs) ✅
1. **Home** (Forum icon) — Dashboard
2. **Chat** (Chat icon) — Conversación con Claude
3. **Commands** (Bolt icon) — Comandos slash
4. **Profile** (Person icon) — Perfil y proyectos

### Pantallas secundarias ✅
- **Settings**: Desde Home (TopAppBar) y Profile (TopAppBar)
- **Git Config**: Desde Settings
- **Team Management**: Desde Settings
- **Company Profile**: Desde Settings
- **Kanban Board**: Desde Home → "See Board"
- **Approvals**: Desde Home → "Approvals"
- **Capture**: Desde Home → FAB
- **Time Log**: Desde Home (futuro)

### Comportamiento ✅
- `popUpTo(startDestination)` con `launchSingleTop = true`
- Sin `saveState/restoreState`
- Start destination: Home

## 5. Bridge Integration

### Endpoints REST directos (FIABLES)
| Endpoint | Método | Auth | Uso | Estado |
|----------|--------|------|-----|--------|
| `/health` | GET | No | Health check | ✅ Funciona |
| `/profile` | GET | Bearer | Perfil de usuario | ✅ Funciona |
| `/profile` | PUT | Bearer | Guardar preferencias | ✅ Funciona |
| `/git-config` | GET | Bearer | Leer config Git | ✅ Funciona |
| `/git-config` | PUT | Bearer | Actualizar config Git | ✅ Funciona |
| `/team` | GET | Bearer | Listar equipo | ✅ Funciona |
| `/team` | PUT | Bearer | CRUD equipo | ✅ Funciona |
| `/company` | GET | Bearer | Perfil empresa | ✅ Funciona |
| `/company` | PUT | Bearer | Actualizar empresa | ✅ Funciona |
| `/update/check` | GET | No | Comprobar actualizaciones | ✅ Funciona |
| `/update/download` | GET | No | Descargar APK | ✅ Funciona |
| `/openapi.json` | GET | No | Spec OpenAPI | ✅ Funciona |
| `/sessions` | GET | Bearer | Listar sesiones Claude | ✅ Funciona |
| `/connectors` | GET | Bearer | Estado conectores | ✅ Funciona |
| `/logs` | GET | Bearer | Logs del Bridge | ✅ Funciona |

| `/dashboard` | GET | Bearer | Dashboard completo (projects, sprint, tasks) | ✅ Funciona |

### Endpoint Chat (FRÁGIL para datos estructurados)
| Endpoint | Método | Auth | Uso | Estado | Nota |
|----------|--------|------|-----|--------|------|
| `/chat` | POST | Bearer | Chat conversacional SSE | ✅ Para chat funciona | — |
| `/chat` | POST | Bearer | Obtener projects vía slash command | ⚠️ FRÁGIL — depende de Claude CLI | Migrado a `/dashboard` REST |
| `/chat` | POST | Bearer | Sprint status vía slash command | ⚠️ FRÁGIL — depende de Claude CLI | Considera usar `/dashboard` |
| `/chat` | POST | Bearer | Board flow vía slash command | ⚠️ FRÁGIL — depende de Claude CLI | Considera usar `/dashboard` |
| `/chat` | POST | Bearer | Time entries vía slash command | ⚠️ FRÁGIL — depende de Claude CLI | Considera usar `/dashboard` |

### Timeouts y resiliencia
- `sendChatCommand()`: timeout de 15 segundos (para comandos slash)
- ProfileViewModel: timeout global de 20 segundos
- Bridge auto-convierte session_id no-UUID a UUID determinístico (uuid5)
- Fallback a mock data para getProjects(), empty para el resto
- Todas las llamadas HTTP en `Dispatchers.IO`

### URL dinámica
- `bridgeRequest()` helper construye URL desde `SecurityRepository.getBridgeUrl()`
- Header `Authorization: Bearer {token}` automático
- **Nunca hardcodear** URLs de localhost

## 6. Seguridad

### Encriptación
- **Tink AEAD** (AES-256-GCM) para almacenamiento local
- **AndroidKeystore**: Clave maestra hardware-backed
- **SecureStorage**: SharedPreferences encriptadas para Bridge host/port/token

### Autenticación
- **Bridge**: Bearer token en header Authorization
- **SSO**: Google Sign-In (Credential Manager) para futuro

### Almacenamiento
- **Room + SQLCipher**: Base de datos encriptada en reposo

## 7. Localización

- **Español (es)**: Idioma principal — 48+ strings en `values-es/strings.xml`
- **Inglés (en)**: Idioma base — 48+ strings en `values/strings.xml`
- Todas las strings UI deben usar `stringResource(R.string.xxx)`
- **Nunca hardcodear** texto visible al usuario en Composables

## 8. Testing

### Unit Tests (JUnit + Robolectric)
- Tests de lógica de ViewModel
- Tests de Repository con MockWebServer
- Tests de navegación (rutas, configuración de tabs)

### Screenshot Tests (Roborazzi 1.59.0)
- Tests en JVM sin dispositivo
- Capturan estado visual de componentes individuales
- Comandos:
  - `./gradlew recordRoborazziDebug` — Generar baselines
  - `./gradlew verifyRoborazziDebug` — Verificar sin cambios
  - `./gradlew compareRoborazziDebug` — Comparar diffs

### Integration Tests (Bridge)
- `scripts/tests/test_bridge_endpoints.py` — 19 tests contra Bridge en localhost
- Prueba todos los endpoints REST: health, profile, sessions, team, company, etc.
- Prueba chat con JSON response y conversión de non-UUID session_id
- Prueba install server: page, update/check, openapi

### APK Integration Tests (✅ FUNCIONAL)
- **16+ tests ADB black-box contra Bridge en localhost**
- Valida: emulador, Bridge reachable, API contract, port forwarding, APK install, Bridge config via UI, Home content, dashboard data, selectors, config persistence, navegación Chat/Commands/Profile/Home, logcat errors, update check
- **Ubicación**: `scripts/tests/test_apk_integration.py`

## 9. Stack Técnico

### Dependencias Clave
- **Kotlin**: 2.1.0
- **Jetpack Compose**: 2024.12.01 (Material 3)
- **Hilt**: 2.56.2 (DI)
- **OkHttp**: 4.12.0 (HTTP client + SSE streaming)
- **Room**: 2.7.0 + SQLCipher 4.6.1 (persistencia)
- **Tink**: 1.10.0 (crypto)
- **Markwon**: 4.6.2 (markdown)
- **Kotlinx Serialization**: 1.7.3 (JSON)
- **Navigation Compose**: 2.8.5
- **Lifecycle**: 2.8.7
- **Roborazzi**: 1.59.0 (screenshot testing)
- **Robolectric**: 4.14.1 (JVM Android testing)
- **AGP**: 8.13.2, **KSP**: 2.1.0-1.0.29

## 10. Arquitectura

### Capas (Clean Architecture)
```
Presentation (Compose UI + ViewModel)
    ↓
Domain (models, repository interfaces)
    ↓
Data (repository implementations, API, DB, Security)
```

### Módulos
- **:app** — UI (Screens, ViewModels, Navigation, DI, Theme)
- **:domain** — Modelos de datos, interfaces de Repository
- **:data** — Implementaciones de Repository, SecureStorage, Room, OkHttp

### Auto-versioning
- `version.properties` gestiona VERSION_CODE, VERSION_MAJOR/MINOR/PATCH
- `assembleDebug` auto-incrementa versionCode y patch **en fase de configuración** (no ejecución), garantizando que el APK siempre embebe la versión correcta
- BuildConfig expone VERSION_NAME y VERSION_CODE
- `assembleDebug` ejecuta `testDebugUnitTest` automáticamente antes de compilar — si los tests fallan, el APK no se genera
- `assembleDebug` auto-publica APK a `~/.savia/bridge/apk/` y `scripts/dist/` via tasks Gradle `publishToBridge` y `publishToDist`

## 11. Nombre oficial

El nombre del producto es **Savia Mobile** (no "Savia App").
Todas las referencias en UI, Bridge, documentación y código deben usar "Savia Mobile".
