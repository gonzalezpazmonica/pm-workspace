# Changelog — Savia Mobile Android

Todos los cambios notables de este proyecto se documentan en este archivo.
El formato está basado en [Keep a Changelog](https://keepachangelog.com/es/1.1.0/),
y este proyecto adhiere a [Versionado Semántico](https://semver.org/lang/es/).

---

## [0.3.35] — 2026-03-09

### Security — Hardening completo desde auditoría de seguridad

Remediación de todos los hallazgos de seguridad que afectan a Savia Mobile y Bridge.

### Seguridad

- SQLCipher activado en Room Database con passphrase Tink AES-256-GCM (C2)
- Logging HTTP condicionado a `BuildConfig.DEBUG` — sin Bearer tokens en logcat producción (C6)
- Encoding passphrase corregido: `Base64.decode()` en vez de `toByteArray(UTF_8)` (A11)
- Documentación de cleartext traffic en `network_security_config.xml` (M4)

### Bridge (v1.6.0)

- Input validation regex en PUT /git-config (C3)
- PAT cifrado con Fernet en vez de Base64 (C4)
- Auth obligatoria en todos los endpoints sensibles (C5)
- Path traversal prevention en descarga de APK (A1)
- SSE connection limit: MAX_CONCURRENT_STREAMS=10 (A2)
- Rate limiting: 5 intentos fallidos / 60s por IP (A3)
- Security headers: X-Content-Type-Options, X-Frame-Options, HSTS (A4)
- CORS restringido a orígenes de red local (A5)
- Body size limit 1MB en POST (A6)
- Log sanitization: Bearer tokens enmascarados (A7)
- Systemd hardening: PrivateTmp, ProtectSystem, NoNewPrivileges (A10)
- YAML frontmatter injection prevention (M1)
- Session ID validation UUID/alfanumérico (M2)
- TLS cipher suite mínima v1.2 (M3)

### Stack técnico actualizado

| Componente | Versión |
|-----------|---------|
| Bridge | 1.6.0 |
| version.properties | CODE=38, PATCH=35 |
| Tests | 48 unit + integration |

---

## [0.3.34] — 2026-03-09

### Segunda release — Full Dashboard + Bridge REST (Sprint 2026-04)

Release completa con dashboard funcional, chat corregido, auto-actualización
robusta, y pipeline de tests integrada en el build.

### Añadido

**Dashboard (Home)**
- Selector de proyecto con búsqueda filtrada (bordered card + dropdown)
- Selector de sprint con búsqueda filtrada
- Sprint progress bar con story points (completados/total)
- Métricas: items bloqueados + horas del día
- My Tasks (primeras 3 tareas asignadas)
- Recent Activity feed
- Quick Actions: "See Board" y "Approvals"
- FAB para captura rápida
- Selección de proyecto persiste entre recargas (almacenamiento local)

**Pantallas secundarias (REST)**
- Kanban board via `GET /kanban?project=X`
- Time log via `GET /timelog` + `POST /timelog`
- Approvals via `GET /approvals?project=X`
- Capture via `POST /capture`
- Git Config (lectura/escritura)
- Team Management (CRUD miembros)
- Company Profile (lectura/escritura)

**Chat**
- Eliminado bug de mensajes duplicados (Room como única fuente de verdad)
- Fix de error CLAUDECODE en sesiones anidadas (Bridge limpia env var)
- Slash command autocomplete (8 comandos)

**Perfil y actualizaciones**
- Barra de progreso de descarga de APK (LinearProgressIndicator + %)
- Botón "Buscar actualizaciones" tras encontrar versión disponible
- Progreso de descarga también en Settings (SettingsViewModel ahora rastrea progreso)
- Reset de estado al buscar actualizaciones (ambas pantallas)

**Build & CI**
- Auto-incremento de versión en fase de configuración de Gradle (fix de desfase)
- Unit tests como gate obligatorio antes de publicar APK al Bridge
- `assembleDebug` ejecuta `testDebugUnitTest` automáticamente
- `publishToBridge` + `publishToDist` solo si tests pasan

**Tests**
- HomeViewModelTest: 5 tests (carga dashboard, selección de proyecto, persistencia, errores)
- Total: 48 unit tests pasando
- Spec coverage: Chat, Home, Settings, Profile, Navigation

**Documentación**
- CLAUDE.md creado para savia-mobile-android (constantes proyecto, sprint, métricas)
- Proyecto visible en dashboard de pm-workspace

### Corregido

- Settings > Perfil no navegaba (onClick condicionado → siempre navega)
- Chat duplicaba mensajes (ViewModel + Room emitían ambos → Room como SSoT)
- Chat no respondía por variable CLAUDECODE heredada en subprocess
- Versión del APK siempre iba una por detrás (incremento en ejecución → configuración)
- Selector de proyecto no persistía selección (usaba Bridge default → selección local)
- Bridge endpoints 404 por proceso desactualizado (requería reinicio)

### Bridge (v1.5.0)

- `POST /timelog` endpoint para imputación de horas
- Fix env CLAUDECODE eliminada del subprocess de Claude CLI
- Endpoints verificados: `/kanban`, `/timelog`, `/approvals`, `/capture`, `/profile`, `/dashboard`

### Stack técnico actualizado

| Componente | Versión |
|-----------|---------|
| Bridge | 1.5.0 |
| version.properties | CODE=37, PATCH=34 |
| Tests | 48 unit + integration |

---

## [0.1.0] — 2026-03-08

### Primera release — MVP Foundation (Fase 0)

Release inicial de Savia Mobile: app Android nativa que conecta con pm-workspace
vía Savia Bridge, un servidor HTTPS/SSE que envuelve Claude Code CLI.

### Añadido

**App Android**
- Chat conversacional con streaming SSE en tiempo real
- Arquitectura limpia (Clean Architecture) con 3 módulos: `:app`, `:domain`, `:data`
- Jetpack Compose + Material 3 con tema violeta/malva personalizado (#6B4C9A)
- Navegación inferior: Chat, Sesiones, Ajustes
- Persistencia de conversaciones con Room Database
- Cifrado AES-256-GCM con Google Tink + Android Keystore
- Dual-backend: Savia Bridge (primario) + API Anthropic (fallback)
- Auto-titulado de conversaciones (primeros 50 caracteres del mensaje)
- Restauración de última sesión activa al iniciar la app
- Dashboard con acciones rápidas y estado del workspace
- Pantalla de ajustes con estado de conexión al Bridge
- Autenticación con Google vía Credential Manager
- Soporte bilingüe (español e inglés)
- Inyección de dependencias con Hilt 2.56.2
- Splash screen con logo de Savia
- Iconos adaptativos (mdpi a xxxhdpi)

**Savia Bridge (Python)**
- Servidor HTTPS en puerto 8922 con TLS autofirmado
- Streaming SSE (Server-Sent Events) desde Claude Code CLI
- Gestión de sesiones con `--session-id` y `--resume`
- Autenticación por Bearer token (generación automática)
- Health check: `GET /health`
- Listado de sesiones: `GET /sessions`
- Servidor HTTP de instalación en puerto 8080
- Página de descarga de APK con logo, versión e instrucciones
- Servicio systemd (`savia-bridge.service`)
- Logging a fichero (`bridge.log`, `chat.log`)
- Versión 1.2.0

**Documentación**
- KDoc completo en los 39 archivos Kotlin fuente
- Docstrings Python en todas las clases/funciones del bridge
- 8 especificaciones reescritas (PRODUCT-SPEC, TECHNICAL-DESIGN, BACKLOG, IMPLEMENTATION-PLAN, ARCHITECTURE-DECISIONS, STACK-ANALYSIS, CI-CD-PIPELINES, MARKET-ANALYSIS)
- 3 guías nuevas: ARCHITECTURE.md, SETUP.md, BRIDGE-GUIDE.md
- API Reference con todos los endpoints del bridge
- README completo con stack, setup, CI/CD y troubleshooting

**Infraestructura**
- CI/CD con GitHub Actions (`android-ci.yml`)
- Instaladores actualizados (`install.sh`, `install.ps1`) con setup del Bridge
- ProGuard/R8 para release builds
- Gradle con Version Catalog (`libs.versions.toml`)

### Stack técnico

| Componente | Versión |
|-----------|---------|
| Kotlin | 2.1.0 |
| AGP | 8.13.2 |
| Compose BOM | 2024.12.01 |
| Material 3 | 1.3.1 |
| Hilt | 2.56.2 |
| Room | 2.7.0 |
| OkHttp | 4.12.0 |
| Retrofit | 2.11.0 |
| Tink | 1.10.0 |
| KSP | 2.1.0-1.0.29 |
| Coroutines | 1.9.0 |
| Python | 3.x (stdlib) |

### Estadísticas

- **88 archivos** en el commit
- **12,954 líneas** añadidas
- **39 archivos Kotlin** documentados con KDoc
- **8 especificaciones** reescritas
- **3 guías** de arquitectura creadas
- **157 tests** pasando
- **Target**: Android 15 (API 35), **Min**: Android 8.0 (API 26)

---

## Roadmap

- **v0.4.0** — Widgets, notificaciones inteligentes
- **v1.0.0** — Beta pública en Google Play

---

[0.3.35]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.3.34-savia-mobile...v0.3.35-savia-mobile
[0.3.34]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.1.0-savia-mobile...v0.3.34-savia-mobile
[0.1.0]: https://github.com/gonzalezpazmonica/pm-workspace/releases/tag/v0.1.0-savia-mobile
