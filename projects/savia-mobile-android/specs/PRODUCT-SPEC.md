# Savia Mobile — Especificación de Producto

## 1. Descripción General

**Nombre**: Savia Mobile
**Plataforma**: Android (nativo, Jetpack Compose)
**Versión**: 0.1.0
**Usuarios Objetivo**: Gestores de proyectos, líderes técnicos, desarrolladores
**Descripción**: Aplicación móvil nativa para Android que proporciona interfaz conversacional con Claude Code a través de la arquitectura de puente Savia. Permite gestionar conversaciones en tiempo real con streaming SSE, persistencia local de historial, y fallback automático a API directa de Anthropic.

## 2. Usuarios Objetivo

### Monica (PM/Technical Lead)
- **Rol**: Gestora técnica de proyectos
- **Necesidad**: Acceder a Claude desde el móvil para revisiones rápidas de decisiones arquitectónicas
- **Dolor**: Dependencia de laptop; necesita movilidad
- **Objetivo**: Chat con streaming, historial persistente, soporte para Bridge

### Carlos (Engineering Manager)
- **Rol**: Manager de ingeniería
- **Necesidad**: Consultar ayuda de Claude para arquitectura/diseño desde cualquier lugar
- **Dolor**: Sesiones largas sin contexto previo
- **Objetivo**: Conversaciones completamente independientes, cada una con su historial

## 3. Características Implementadas

### F1: Chat Conversacional ✅ Implementada
- **Interfaz de usuario**: Jetpack Compose, Material 3 (tema violeta/malva)
- **Streaming SSE**: Respuestas en tiempo real con visualización incremental
- **Historial persistente**: Room database con conversaciones y mensajes
- **Sistema dual**:
  - Primario: Savia Bridge (HTTPS/SSE, puerto 8922)
  - Fallback: API Anthropic directo (claude-3-5-sonnet)
- **Markdown rendering**: Markwon para formateo de respuestas
- **Selección automática**: Bridge si disponible; fallback a API si no configurado

### F2: Sesiones (Conversaciones) ✅ Implementada
- **Historial de conversaciones**: Lista de todas las sesiones activas
- **Auto-titulado**: Título generado automáticamente del primer mensaje
- **Persistencia de sesión**: Al cerrar la app, se restaura la última conversación al abrir
- **Gestión**: Crear nueva, cambiar de sesión, eliminar sesión
- **Preview**: Última línea de mensaje en la lista para contexto rápido

### F3: Configuración de Conexión ✅ Implementada
- **Bridge Configuration**:
  - Host/URL (ej: https://localhost:8922)
  - Token de autenticación
  - Encriptación Tink AES-256-GCM
  - Health check periódico
  - Desconexión manual desde Settings
- **API Key (fallback)**:
  - Autenticación con clave Anthropic
  - Almacenamiento encriptado
  - Uso transparente si Bridge no disponible
- **Indicador de estado**: Settings muestra estado de Bridge (conectado/desconectado)

### F4: Dashboard (Sesiones) ✅ Implementada
- **Listado de conversaciones**: Todas las sesiones con preview del último mensaje
- **Ordenamiento**: Por fecha de última actualización (más reciente primero)
- **Acciones**: Seleccionar para reanudar, eliminar, nuevo chat
- **Estado vacío**: Mensaje si no hay conversaciones

### F5: Persistencia Local ✅ Implementada
- **Base de datos**: Room con SQLCipher para encriptación de almacenamiento
- **Esquema**:
  - `conversations`: id, title, createdAt, updatedAt, isArchived
  - `messages`: id, conversationId, role (user/assistant/system), content, timestamp
- **Sincronización**: Flow reactivo para UI updates en tiempo real
- **Queries eficientes**: Índices en conversationId para búsqueda rápida

## 4. Navegación

### Bottom Navigation (4 tabs)
1. **Chat**: Interfaz principal de conversación
   - Entrada de texto
   - Visualización de historial
   - Indicador de streaming
2. **Sessions**: Historial de conversaciones
   - Lista con preview
   - Acciones (seleccionar, eliminar)
   - Nuevo chat
3. **Settings**: Configuración
   - Estado de Bridge (URL, conectado/desconectado)
   - API Key config
   - Tema, idioma, info de app
4. **Dashboard** (integrado en Sessions)

### Persistencia de Tab State
- `saveState/restoreState` en NavigationBar
- Último tab visitado se restaura
- Historial de navegación preservado

## 5. Seguridad

### Encriptación
- **Tink AEAD** (AES-256-GCM)
- **AndroidKeystore**: Clave maestra hardware-backed
- **SecureStorage**: SharedPreferences encriptadas para API key y Bridge token

### Autenticación
- **Bridge**: Bearer token (env variable o configuración manual)
- **API**: Clave de Anthropic encriptada
- **SSO**: Google Sign-In (Credential Manager) para futuro

### Almacenamiento
- **Room + SQLCipher**: Base de datos encriptada en reposo
- **Derivación de clave**: PBKDF2 para passphrases locales

## 6. Requisitos No Funcionales

### Performance
- App cold start: < 3 segundos
- Streaming SSE: visualización del primer chunk < 1 segundo
- Scroll de mensajes: 60fps (Compose optimization)
- Base de datos: queries <100ms incluso con 10k mensajes

### Compatibilidad
- **Android mínimo**: API 26 (8.0)
- **Android destino**: API 35 (15.0)
- **Kotlin**: 2.1.0
- **Java**: 17 (JVM target)

### Accesibilidad
- **Material 3**: Soporte WCAG 2.1 AA
- **TalkBack**: Descripción de contenido en componentes
- **Touch targets**: 48dp mínimo
- **Alto contraste**: Tema de alto contraste soportado

### Localización
- **Español**: Principal
- **Inglés**: Secundario (estructura preparada)
- **RTL**: Arquitectura lista para idiomas RTL

## 7. Stack Técnico

### Dependencias Clave
- **Kotlin**: 2.1.0
- **Jetpack Compose**: 2024.06.00 (Material 3)
- **Hilt**: 2.51 (DI)
- **Retrofit**: 2.11.0 (HTTP client)
- **OkHttp**: 4.12.0 (SSE streaming)
- **Room**: 2.7.0 + SQLCipher 4.6.0 (persistencia)
- **DataStore**: 1.1.1 (preferences encriptadas)
- **Tink**: 1.10.0 (crypto)
- **Markwon**: 4.6.2 (markdown)
- **Kotlinx Serialization**: 1.6.0 (JSON)
- **Google Credential Manager**: 1.2.0 (autenticación)

### Testing
- **JUnit 4**: Unit tests
- **Mockk**: Mocking
- **Turbine**: Flow testing
- **Truth**: Assertions
- **Robolectric**: Android simulation
- **MockWebServer**: API mock
- **TestContainers**: Futura integración

## 8. Arquitectura

### Capas (Clean Architecture)
```
Presentation (Compose UI)
    ↓
ViewModel (StateFlow)
    ↓
Use Cases (Domain)
    ↓
Repositories (Data)
    ↓
API/Database/Security
```

### Módulos
- **:app** — Aplicación (MainActivity, UI, DI, Auth)
- **:domain** — Modelos, interfaces repository, use cases
- **:data** — Implementaciones, API, BD, Security

### DI (Hilt)
- **NetworkModule**: OkHttpClient, Retrofit, JSON, SaviaBridgeService
- **RepositoryModule**: ChatRepository, SecurityRepository
- **DatabaseModule**: Room database, DAOs

## 9. Decisiones de Diseño

### Dual-Stack (Bridge + API)
**Razón**: Bridge es primario pero API proporciona fallback sin dependencias de infraestructura externa.
**Implementación**: SecurityRepository determina ruta en tiempo de ejecución.
**Beneficio**: Flexibilidad de despliegue.

### SSE Streaming en Mobile
**Razón**: Respuestas en tiempo real, visualización incremental, UX fluida.
**Implementación**: OkHttpClient + callbackFlow + BufferedSource.readUtf8Line().
**Desafío**: Manejo de conexiones persistentes en móvil (puede desconectarse); implementar reconnect en futuro.

### Room + SQLCipher
**Razón**: Persistencia nativa Android con encriptación estándar.
**Alternativa considerada**: Datastore (más simple pero menos flexible para queries).
**Beneficio**: Escalable a 10k+ mensajes sin degradación.

### Compose Multiplatform Ready
**Razón**: Arquitectura preparada para reutilización en iOS (Kotlin Multiplatform).
**Implementación**: Domain y Data totalmente independientes de Android; solo UI es específica.
**Futuro**: Migración a KMP para iOS con cambio mínimo de UI.

## 10. Restricciones y Limitaciones

- **Offline parcial**: Puedo leer historial offline pero no enviar nuevos mensajes sin red
- **Sync unidireccional**: No hay sync con servidor (Estado local es fuente de verdad)
- **Sin widgets**: Widgets son road map futuro
- **Sin notificaciones push**: Solo polling/manual en futuro
- **Sin soporte wear**: Wear OS es futuro

## 11. Roadmap

### v0.2.0 (Beta)
- [ ] Dashboards de proyecto/métricas (via Bridge)
- [ ] Búsqueda en historial
- [ ] Temas personalizados

### v0.5.0 (Beta+)
- [ ] Widgets de home screen
- [ ] Notificaciones push (Bridge)
- [ ] Voz input (speech-to-text)

### v1.0.0 (Release)
- [ ] Google Play Store launch
- [ ] Traducción completa (ES/EN)
- [ ] Support para tablets layout

### v1.5.0 (Post-release)
- [ ] Kotlin Multiplatform iOS companion
- [ ] Wear OS app

## 12. Métricas de Éxito

- App store rating: > 4.0 estrellas
- Session duration: > 5 minutos promedio
- Retention D7: > 40%
- Crash-free users: > 98%
- Stream latency (first chunk): < 1.5 segundos p99
