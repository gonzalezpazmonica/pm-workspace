# Changelog — Savia Mobile Android

Todos los cambios notables de este proyecto se documentan en este archivo.
El formato está basado en [Keep a Changelog](https://keepachangelog.com/es/1.1.0/),
y este proyecto adhiere a [Versionado Semántico](https://semver.org/lang/es/).

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

- **v0.2.0** — Sincronización offline, plantillas rápidas
- **v0.3.0** — Integración nativa Jira/Azure DevOps
- **v0.4.0** — Widgets, notificaciones inteligentes
- **v1.0.0** — Beta pública en Google Play
