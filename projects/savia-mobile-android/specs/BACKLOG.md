# Savia Mobile Android — Backlog Post-Implementación

Historial de Product Backlog Items (PBIs) implementados en Savia Mobile Android v0.1.0.
El proyecto completó la **Fase 0** (Foundation) con éxito. Las fases 1-4 (Chat, Dashboard, SSH, Launch) quedan para futuras versiones.

---

## Fase 0: Foundation — ✅ COMPLETADA

### PBI-001: Configuración del Proyecto ✅ DONE
**Historia:** Como desarrollador, quiero un proyecto Android con arquitectura limpia para construir sobre base sólida.

**Aceptación:**
- ✅ Kotlin + Jetpack Compose (Material 3)
- ✅ Módulos Clean Architecture: `:app`, `:domain`, `:data`
- ✅ Hilt para inyección de dependencias (todos los módulos)
- ✅ Gradle con Kotlin DSL (`build.gradle.kts`)
- ✅ minSdk 26 (Android 8.0)
- ✅ Compilación sin errores: `./gradlew assembleDebug`

**Implementación:** Estructura modular completa con separación clara entre capas.

---

### PBI-002: Cliente HTTP y Serialización ✅ DONE
**Historia:** Como usuario, quiero que la app se conecte a Claude API para chatear con Savia.

**Aceptación:**
- ✅ Retrofit 2.11.0 + OkHttp 4.12.0 (no Ktor)
- ✅ Kotlinx Serialization para JSON (type-safe)
- ✅ SSE (Server-Sent Events) streaming implementado
- ✅ Timeouts configurados (lectura 120s para streaming)
- ✅ Error handling: red errors, auth errors
- ✅ Interceptor HTTP para logging (HEADERS level)

**Decisión:** Retrofit elegido por ecosistema Android maduro. Ktor es multiplataforma pero menos común en Android.

---

### PBI-003: Cifrado de Credenciales ✅ DONE
**Historia:** Como PM, quiero que mis credenciales se almacenen seguros en el dispositivo.

**Aceptación:**
- ✅ Google Tink 1.10.0 (no EncryptedSharedPreferences deprecated)
- ✅ AES-256-GCM para AEAD encryption
- ✅ Android Keystore (hardware-backed en dispositivos modernos)
- ✅ TinkKeyManager con lazy initialization
- ✅ Master key persistente en SharedPreferences
- ✅ Contexto (AAD) para verificación de autenticidad

**Implementación:** TinkKeyManager.kt con métodos `encryptString()`, `decryptString()`. Master key automático en primer uso.

---

### PBI-004: Servicios de API ✅ DONE
**Historia:** Como usuario, quiero comunicarme con Claude API directamente.

**Aceptación:**
- ✅ ClaudeApiService (Retrofit interface)
- ✅ Streaming de respuestas via OkHttp EventSource
- ✅ Manejo de deltas de texto (StreamDelta.Text, .Error, .Done)
- ✅ API key almacenada con Tink (cifrada)
- ✅ Reintentos con backoff exponencial (OkHttp interceptor)

**Implementación:** ClaudeApiService implementa protocol Anthropic Messages API v1.

---

### PBI-005: Servicio Bridge (local HTTP) ✅ DONE
**Historia:** Como power user, quiero conectar a un bridge local para contexto enriquecido.

**Aceptación:**
- ✅ SaviaBridgeService (OkHttp, no Retrofit)
- ✅ Endpoints: POST `/chat`, GET `/health`
- ✅ SSE streaming desde bridge
- ✅ Autenticación Bearer token
- ✅ Aceptación de certificados self-signed (VPN)
- ✅ Timeout extendido 300s (streaming largo)
- ✅ Enrutamiento transparente: Bridge si existe, fallback API

**Implementación:** SaviaBridgeService.kt con `sendMessageStream()` y `healthCheck()`. Routing en ChatRepositoryImpl.

---

### PBI-006: Tema Violet/Mauve ✅ DONE
**Historia:** Como usuario, quiero una interfaz visual coherente con identidad Savia.

**Aceptación:**
- ✅ Paleta violet/mauve (#6B4C9A primario)
- ✅ Material 3 color system (light + dark mode)
- ✅ Colores burbujas chat: violet usuario, lavanda asistente
- ✅ Accesibilidad: contraste WCAG AA mínimo
- ✅ Colors.kt completamente documentado

**Decisión:** Violet elegido por asociación con sabiduría y claridad. Mauve para tonos secundarios suaves.

---

### PBI-007: Módulo de Inyección de Dependencias ✅ DONE
**Historia:** Como desarrollador, quiero DI centralizado para singletons y factories.

**Aceptación:**
- ✅ NetworkModule para OkHttpClient (2 variantes: API + Bridge)
- ✅ Retrofit singleton
- ✅ ClaudeApiService singleton
- ✅ SaviaBridgeService singleton
- ✅ Json (Kotlinx Serialization) singleton
- ✅ Hilt @Module + @Provides

**Implementación:** NetworkModule.kt con providers para ambos clientes HTTP. Bridge client con TLS permisivo (seguridad por VPN + token).

---

### PBI-008: Seguridad: Gestión de Secretos ✅ DONE
**Historia:** Como admin, quiero garantizar que los secrets nunca expongan en logs ni memoria.

**Aceptación:**
- ✅ API keys solo en KeyStore (nunca en SharedPrefs sin cifrar)
- ✅ Tokens bearer no loggueados
- ✅ HttpLoggingInterceptor a nivel HEADERS (nunca BODY)
- ✅ SecureStorage wrapper sobre Tink
- ✅ Protección contra memory dumps

**Implementación:** TinkKeyManager + SecurityRepository cifran todo. Tokens borrados de memoria post-uso.

---

## Fase 1: Chat MVP — 📋 BACKLOG (Futuro)

### PBI-009: Pantalla de Chat
**Historia:** Como usuario, quiero conversar con Savia en una interfaz limpia.

**Scope:** Compose screen con burbujas de chat, input de texto, indicador de escritura, scroll automático.

---

### PBI-010: Historial de Mensajes
**Historia:** Como usuario, quiero recuperar conversaciones anteriores.

**Scope:** Room database con entidades Conversation + Message. Caché de últimas 50 conversaciones.

---

### PBI-011: Markdown Rendering
**Historia:** Como PM, quiero leer respuestas formateadas (títulos, código, listas).

**Scope:** Markwon library en Compose. Soporte para bloques de código, tablas.

---

### PBI-012: Entrada por Voz
**Historia:** Como usuario, quiero dictado por voz sin escribir.

**Scope:** Android SpeechRecognizer. Botón micrófono en chat. Transcripción → envío automático.

---

## Fase 2: Dashboard — 📋 BACKLOG (Futuro)

### PBI-013: Dashboard de Salud
**Historia:** Como PM, quiero ver métricas de workspace en un vistazo.

**Scope:** Radar chart 6 dimensiones. Score global. Indicadores de tendencia. Pull-to-refresh.

---

### PBI-014: Acciones Rápidas
**Historia:** Como PM, quiero botones one-tap para queries frecuentes.

**Scope:** Grid de tarjetas (Sprint Status, Risk Score, Health). Pre-fill chat con query. Badges con valores.

---

### PBI-015: Caché Offline
**Historia:** Como usuario, quiero acceder datos sin internet.

**Scope:** Room persistence. Indicador online/offline. Auto-refresh en reconexión.

---

## Fase 3: Conexiones SSH — 📋 BACKLOG (Futuro)

### PBI-016: Generación de Keypair
**Historia:** Como power user, quiero generar mi keypair SSH para conectar.

**Scope:** Ed25519 key generation. Display public key. Storage en KeyStore.

---

### PBI-017: Gestor de Conexiones
**Historia:** Como usuario, quiero guardar múltiples perfiles SSH.

**Scope:** CRUD de ConnectionProfile. Test de conexión. Fallback automático a API.

---

### PBI-018: Modo Híbrido
**Historia:** Como usuario, quiero que la app elija automáticamente conexión óptima.

**Scope:** HybridRepository. Intenta SSH primero. Fallback a API. Indicador de modo actual.

---

## Fase 4: Polish & Launch — 📋 BACKLOG (Futuro)

### PBI-019: Onboarding
**Historia:** Como nuevo usuario, quiero flujo guiado de setup.

**Scope:** 3 pantallas (bienvenida, conexión, primer mensaje). Skip option.

---

### PBI-020: Settings Screen
**Historia:** Como usuario, quiero configurar tema, idioma, conexión.

**Scope:** Theme (light/dark/system). Language (ES/EN). Notificaciones. Clear cache. About.

---

### PBI-021: Notificaciones Push
**Historia:** Como PM, quiero alertas de eventos importantes.

**Scope:** Firebase Cloud Messaging. Sprint deadlines. Health degradation. CI failures.

---

### PBI-022: Home Screen Widget
**Historia:** Como PM, quiero widget con métricas en home.

**Scope:** Glance widget. Health score + sprint progress. Auto-refresh 30min. Responsive (2x2, 4x2, 4x4).

---

### PBI-023: Release a Play Store
**Historia:** Como PM, quiero app disponible en Play Store.

**Scope:** Signing config. Privacy policy. Beta testing. Crash rate < 1%. Staged rollout.

---

## Resumen de Progreso

| Fase | Estado | PBIs | Completados |
|------|--------|------|------------|
| Fase 0: Foundation | ✅ DONE | 8 | 8/8 (100%) |
| Fase 1: Chat MVP | 📋 BACKLOG | 4 | 0/4 (0%) |
| Fase 2: Dashboard | 📋 BACKLOG | 3 | 0/3 (0%) |
| Fase 3: SSH | 📋 BACKLOG | 3 | 0/3 (0%) |
| Fase 4: Launch | 📋 BACKLOG | 6 | 0/6 (0%) |
| **Total** | | **24** | **8/24 (33%)** |

**Velocidad:** Fase 0 completada en tiempo estimado con calidad de producción.
**Próximo paso:** Iniciar Fase 1 (Chat MVP) con Sprint Planning para user stories PBI-009, PBI-010 (chat screen + historial).

---

## Dependencias Inter-Fase

```
Fase 0 Foundation
    ↓
Fase 1 Chat MVP ────────→ Fase 2 Dashboard
    ↓                          ↓
Fase 3 SSH (Chat enrichment)   ↓
    ↓                          ↓
Fase 4 Launch ◄────────────────┘
```

- Fase 1 desbloquea Fase 2 (dashboard lee Chat repository)
- Fase 1 + 3 desbloquean Fase 4 (polish requiere features)
- Fase 2 no bloquea Fase 3 (independientes)
