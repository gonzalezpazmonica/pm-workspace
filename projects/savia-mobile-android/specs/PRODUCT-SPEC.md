# Savia Mobile — Especificación de Producto

## 1. Descripción General

**Nombre**: Savia Mobile
**Plataforma**: Android (nativo, Jetpack Compose)
**Versión**: 0.2.x
**Usuarios Objetivo**: Gestores de proyectos, líderes técnicos, desarrolladores
**Descripción**: Aplicación móvil nativa para Android que proporciona interfaz de gestión de proyectos y conversacional con Claude Code a través de la arquitectura Savia Bridge. Dashboard con métricas de sprint, selección de proyecto/sprint, perfil de usuario, gestión de equipo/empresa, y chat con streaming SSE.

## 2. Usuarios Objetivo

### Monica (PM/Technical Lead)
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

### 3.1 Home (Dashboard) ✅ v0.2
- **Saludo**: "Good morning/afternoon/evening, {nombre}"
- **Selector de proyecto**: Desplegable con buscador (filtra por nombre/id)
- **Selector de sprint**: Desplegable con buscador (filtra por nombre)
- **Sprint Progress**: Barra de progreso lineal + SP completados/total
- **Métricas**: Cards de items bloqueados + horas de hoy
- **My Tasks**: Lista de las 3 primeras tareas del usuario (columna Active)
- **Recent Activity**: Últimos 5 items del sprint
- **Quick Actions**: Botones "See Board" y "Approvals"
- **FAB**: Botón flotante de captura rápida
- **Refresh**: Botón en TopAppBar para refrescar datos

### 3.2 Chat ✅ v0.1
- **Interfaz de usuario**: Jetpack Compose, Material 3 (tema violeta/malva)
- **Streaming SSE**: Respuestas en tiempo real con visualización incremental
- **Historial persistente**: Room database con conversaciones y mensajes
- **Sistema dual**:
  - Primario: Savia Bridge (HTTPS/SSE, puerto 8922)
  - Fallback: API Anthropic directo (claude-3-5-sonnet)
- **Markdown rendering**: Markwon para formateo de respuestas

### 3.3 Commands ✅ v0.2
- **Familias de comandos**: 10 categorías organizadas
- **Ejecución directa**: Comandos read-only desde el móvil
- **Feedback visual**: Indicador de ejecución y resultado

### 3.4 Profile ✅ v0.2
- **Cabecera de usuario**: Avatar (iniciales), nombre, email, rol, organización
- **Stats**: Sprints gestionados, PBIs completados, horas loggeadas
- **Proyectos activos**: Lista de proyectos con selector
- **Check Updates**: Comprobación de actualizaciones vía Bridge `/update/check`
- **Download Update**: Descarga de APK vía Bridge `/update/download`
- **Versión de app**: Footer con número de versión dinámica (BuildConfig)
- **Navegación a Settings**: Botón de engranaje en TopAppBar
- **Estado sin Bridge**: Muestra "Configure Bridge" con botones "Go to Settings" y "Retry"
- **Carga paralela**: getUserProfile() y getProjects() se ejecutan en paralelo
- **Timeout**: 20 segundos máximo de espera para carga completa

### 3.5 Settings ✅ v0.2
- **Bridge status**: Card verde (conectado) o roja (desconectado) con host:port
- **Perfil de usuario**: Nombre y email si cargado; tap para cargar si no
- **Git Configuration**: Navega a pantalla de configuración Git (nombre, email, PAT)
- **Team**: Navega a gestión de equipo (añadir/editar/eliminar miembros)
- **Company**: Navega a perfil de empresa (secciones: identidad, estructura, etc.)
- **Theme**: Selector: SYSTEM, LIGHT, DARK
- **Language**: Selector: SYSTEM, ES, EN
- **About**: Versión de app y Bridge
- **Disconnect**: Diálogo de confirmación para desconectar Bridge

### 3.6 Bridge Setup Dialog ✅ v0.2
- **Campos**: Host (IP address), Port (default 8922), Token (con toggle visibilidad)
- **Validación**: Host no vacío, port 1-65535, token no vacío
- **Health check**: POST a `/health` con Bearer token
- **Loading**: Spinner + "Connecting..." durante health check
- **Error**: Mensaje de error con detalle de la excepción
- **Auto-dismiss**: Se cierra al conectar exitosamente
- **Ejecuta en Dispatchers.IO**: No bloquea el hilo principal

### 3.7 Onboarding ✅ v0.2
- **AppStartupViewModel**: Detecta si Bridge está configurado al arrancar
- **Detección de idioma**: Lee Locale.getDefault().language
- **Flujo**: Si no hay Bridge → muestra BridgeSetupDialog; si hay → va directo a Home

## 4. Navegación

### Bottom Navigation (4 tabs)
1. **Home**: Dashboard con métricas de sprint y proyecto
2. **Chat**: Interfaz de conversación con Claude
3. **Commands**: Comandos slash organizados por familia
4. **Profile**: Perfil de usuario, proyectos, actualizaciones

### Navegación secundaria (desde Settings)
- **Settings**: Accesible desde Home y Profile (icono engranaje)
- **Git Config**: Desde Settings
- **Team Management**: Desde Settings
- **Company Profile**: Desde Settings

### Comportamiento de navegación
- Bottom tabs: `popUpTo(startDestination)` con `launchSingleTop = true`
- Sin `saveState/restoreState` (causaba bug de Settings "pillada")
- Settings→Profile: navegación directa con callback

## 5. Bridge Integration

### Endpoints utilizados por la app
| Endpoint | Método | Auth | Uso |
|----------|--------|------|-----|
| `/health` | GET | Bearer | Health check al configurar Bridge |
| `/profile` | GET | No | Carga de perfil de usuario |
| `/profile` | PUT | Bearer | Guardar preferencias de usuario |
| `/git-config` | GET | No | Leer config Git |
| `/git-config` | PUT | Bearer | Actualizar config Git |
| `/team` | GET | No | Listar miembros del equipo |
| `/team` | PUT | Bearer | CRUD miembros del equipo |
| `/company` | GET | No | Perfil de empresa |
| `/company` | PUT | Bearer | Actualizar secciones empresa |
| `/chat` | POST | Bearer | Chat con SSE streaming |
| `/update/check` | GET | No | Comprobar actualizaciones |
| `/update/download` | GET | No | Descargar APK |
| `/openapi.json` | GET | No | Especificación OpenAPI 3.0 |

### Timeouts y resiliencia
- `sendChatCommand()`: timeout de 15 segundos
- ProfileViewModel: timeout global de 20 segundos
- Fallback a datos mock si la respuesta del Bridge falla
- Todas las llamadas HTTP se ejecutan en `Dispatchers.IO`

### URL dinámica
- `bridgeRequest()` helper construye URL desde `SecurityRepository.getBridgeUrl()`
- Incluye header `Authorization: Bearer {token}` automáticamente
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

### Tests funcionales contra specs
- Verifican que componentes UI contienen los elementos especificados
- Validan que estados de UI (loading, error, loaded) funcionan correctamente
- Ubicación: `app/src/test/kotlin/com/savia/mobile/ui/`

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
- `assembleDebug` auto-incrementa versionCode y patch
- BuildConfig expone VERSION_NAME y VERSION_CODE

## 11. Nombre oficial

El nombre del producto es **Savia Mobile** (no "Savia App").
Todas las referencias en UI, Bridge, documentación y código deben usar "Savia Mobile".
