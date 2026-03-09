# Savia Mobile Android — App Android del PM-Workspace

> Aplicación Android nativa (Kotlin + Jetpack Compose) que se conecta al Savia Bridge
> para proporcionar acceso móvil al PM-Workspace de Savia.

---

## ⚙️ CONSTANTES DEL PROYECTO

```
# ── Identidad ──────────────────────────────────────────────────────────────────
PROJECT_AZDO_NAME         = "SaviaMobile"
TEAM_NAME                 = "Savia Mobile Team"
ITERATION_PATH_ROOT       = "SaviaMobile\\Sprints"
BOARD_NAME                = "Stories"
AREA_PATH                 = "SaviaMobile"

# ── Sprint Actual ──────────────────────────────────────────────────────────────
SPRINT_ACTUAL             = "Sprint 2026-04"
SPRINT_START              = "2026-03-02"
SPRINT_END                = "2026-03-13"
SPRINT_GOAL               = "Conectividad Bridge estable, dashboard con datos reales, actualización OTA"

# ── Métricas históricas ───────────────────────────────────────────────────────
VELOCITY_MEDIA_SP         = 18
VELOCITY_ULTIMA_SP        = 20
SP_RATIO_HORAS            = 6.0
CYCLE_TIME_MEDIA_DIAS     = 2.0
CYCLE_TIME_P75_DIAS       = 3.5
```

## 🏗️ Arquitectura

- **Módulos**: `:app` (UI + DI), `:domain` (modelos + interfaces), `:data` (repositorios + red)
- **Stack**: Kotlin 2.1.0, Jetpack Compose Material 3, Hilt, OkHttp, KSP
- **Conexión**: HTTPS al Savia Bridge (puerto 8922, TLS self-signed, auth token)
- **Endpoints clave**: GET `/dashboard`, POST `/chat`, GET `/update/check`, GET `/update/download`

## 📱 Pantallas

Home (dashboard), Chat (IA conversacional), Commands (paleta de comandos), Profile (perfil + actualizaciones), Kanban, Approvals, Capture, TimeLog, Dashboard, Settings, TeamManagement, GitConfig, CompanyProfile

## 🔄 Auto-actualización

El Bridge sirve APKs via `/update/check` y `/update/download`. La app compara versiones y ofrece descarga + instalación desde las pantallas Profile y Settings, con barra de progreso de descarga (LinearProgressIndicator + %).

## 🧪 Tests & Build

- **48 unit tests** pasando (Chat, Home, Settings, Profile, Navigation)
- `assembleDebug` ejecuta `testDebugUnitTest` automáticamente — si fallan, no se genera APK
- Tras compilar, APK se publica a `~/.savia/bridge/apk/` y `scripts/dist/`
- Versión se auto-incrementa en fase de configuración de Gradle (no ejecución)

## 🐛 Fixes importantes (v0.3.34)

- **Chat SSoT**: Room Database es única fuente de verdad para mensajes (evita duplicados)
- **CLAUDECODE env**: Bridge limpia variable de entorno para evitar error de sesiones anidadas
- **Selector de proyecto**: Selección local persiste entre recargas (no depende del Bridge default)
- **Versión APK**: Incremento en fase de configuración (el APK siempre tiene la versión correcta)
