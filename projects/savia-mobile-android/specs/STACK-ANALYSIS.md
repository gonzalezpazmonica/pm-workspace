# Savia Mobile — Análisis de Stack Tecnológico

> Análisis actualizado: Marzo 2026. Versiones reales del proyecto verificadas en libs.versions.toml.

## 1. Decisión: Kotlin Nativo vs KMP

| Criterio | Kotlin Nativo | Kotlin Multiplatform |
|----------|--------------|---------------------|
| Madurez | Plena | Estable desde 2023 |
| Necesidad de iOS | No (solo Android) | Sí |
| Complejidad | Baja | Media-Alta |
| Velocidad de desarrollo | Alta | Media |
| Jetpack completo | Sí | Parcial |

**Decisión: Kotlin Nativo (Android puro)**

Razón: Savia Mobile es Android-first. KMP añadiría complejidad sin beneficio inmediato. Si en el futuro necesitamos iOS, la capa domain/ está diseñada para ser portable a KMP sin reescritura.

## 2. Decisión: UI Framework

| Opción | Estado 2026 | Pros | Contras |
|--------|------------|------|---------|
| Jetpack Compose | Default, estable | Declarativo, Hot Reload estable | — |
| XML Views | Legacy | Más tutoriales antiguos | No recomendado para nuevos proyectos |
| Compose Multiplatform | 1.10.0+ | iOS sharing | Innecesario sin iOS |

**Decisión: Jetpack Compose 2024.12.01 (BOM)**

Razón: Es el estándar de facto para nuevos proyectos Android. Hot Reload estable desde 2026. Material 3 v1.3.1 + Material You (dynamic colors) incluido.

## 3. Decisión: Cliente HTTP para Claude API

**Hallazgo crítico: No existe SDK oficial de Anthropic para Kotlin/Android.**

| Opción | Mantenimiento | Android-friendly | Streaming |
|--------|--------------|-------------------|-----------|
| Retrofit 2.11.0 + OkHttp 4.12.0 | Activo | Nativo | Via OkHttp SSE |
| Ktor Client 2.3.12 | Activo | Sí (multiplataforma) | Via chunked |
| anthropic-sdk-kotlin (xemantic) | Comunitario | Sí | Sí |

**Decisión: Retrofit 2.11.0 + OkHttp 4.12.0 con KotlinX Serialization 1.7.3**

Razón: Estándar de la industria Android, excelente soporte de streaming SSE con OkHttp, máxima documentación y comunidad. Ktor es buena alternativa si migramos a KMP en el futuro.

**Streaming de respuestas Claude:** Retrofit + OkHttp con servidor SSE personalizado en el bridge (savia-bridge.py) que convierte respuestas streaming a eventos Server-Sent Events para el cliente Android.

## 4. Decisión: Biblioteca SSH

**Hallazgo crítico: JSch original está deprecado (último release Nov 2025).**

| Opción | Estado | Última versión | Android |
|--------|--------|---------------|---------|
| JSch (original) | Deprecado | Nov 2025 | Sí pero inseguro |
| mwiede/jsch (fork) | Activo | 2026 | Sí |
| Apache MINA SSHD | Activo | 1.18.0 (Ene 2026) | No (requiere NIO) |

**Decisión: Usar savia-bridge.py (puente Python)**

Razón: En lugar de implementar SSH directamente en la app, la conectividad SSH se delega al servidor bridge (savia-bridge.py) que corre en la máquina del usuario. La app se conecta al bridge via HTTPS simple, reduciendo complejidad criptográfica en el cliente Android.

## 5. Decisión: Seguridad y Almacenamiento de Secretos

**Hallazgo crítico: EncryptedSharedPreferences está DEPRECADO (security-crypto 1.1.0-alpha).**

| Componente | Solución | Razón |
|-----------|----------|-------|
| API keys Claude | Android Keystore + Tink 1.10.0 | Hardware-backed, Google estándar |
| Auth tokens | Tink AEAD encrypt | Nunca en texto plano |
| Preferencias | Jetpack DataStore 1.1.1 | Reemplazo moderno de SharedPreferences |
| BD offline | Room 2.7.0 + SQLCipher 4.6.1 | Cifrado transparente de BD |
| Biometría | BiometricPrompt API | Lock opcional de app |

**Decisión: Tink 1.10.0 + Android Keystore + DataStore 1.1.1**

Razón: Tink es la biblioteca criptográfica de Google (usada en Google Pay, Firebase). Reemplaza EncryptedSharedPreferences con API más robusta y mantenida. DataStore proporciona almacenamiento de preferencias type-safe y coroutine-aware.

## 6. Decisión: Persistencia Local

| Dato | Solución | Razón |
|------|----------|-------|
| Historial de chat | Room 2.7.0 | Relacional, queries complejas, offline |
| Snapshots workspace | Room 2.7.0 | Historial temporal con expiracion |
| Preferencias usuario | DataStore 1.1.1 | Key-value moderno, Proto3 optional |
| Cache API responses | Room + expiración 30d | Offline mode, evita re-fetches |

**Decisión: Room 2.7.0 + DataStore 1.1.1 + SQLCipher 4.6.1**

Room provee esquema type-safe con KSP (2.1.0-1.0.29) para compilación. Todas las conversaciones y datos se cifran con SQLCipher a nivel de BD.

## 7. Decisión: Inyección de Dependencias

| Opción | Complejidad | Performance | Estándar |
|--------|------------|-------------|----------|
| Hilt 2.56.2 | Media | Compile-time | Google recomendado |
| Koin | Baja | Runtime | Popular comunidad |

**Decisión: Hilt 2.56.2**

Razón: Recomendación oficial de Google para Android, inyección en compile-time con KSP (mejor performance), integración nativa con ViewModel y Navigation.

## 8. Decisión: CI/CD

**Decisión: GitHub Actions nativo**

Razón: El proyecto está en GitHub. Pipeline:
- PR: lint + unit tests + security scan + build debug APK
- main: build release AAB + deploy internal track
- tags: build release AAB + deploy production (staged)

## 9. Decisión: Target SDK y Compatibilidad

| Parámetro | Valor | Razón |
|-----------|-------|-------|
| minSdk | 26 (Android 8.0) | 99%+ dispositivos, API requerida para Room/Compose |
| targetSdk | 35 (Android 15) | Requisito Play Store 2026, últimas APIs |
| compileSdk | 35 | Última API disponible |

## 10. Dependencias Clave (versiones reales)

### Build & Plugins
- Android Gradle Plugin (AGP): 8.13.2
- Kotlin: 2.1.0
- KSP (Kotlin Symbol Processor): 2.1.0-1.0.29
- Kotlin Compose Compiler Plugin: 1.5.15
- Kotlin Serialization: 1.7.3
- Kotlinx Coroutines: 1.9.0

### Compose
- Compose BOM: 2024.12.01
- Material 3: 1.3.1
- Material Icons Extended: included in BOM
- Activity Compose: 1.9.3

### Jetpack/AndroidX
- Core KTX: 1.15.0
- AppCompat: via Compose
- Lifecycle: 2.8.7
- Navigation Compose: 2.8.5
- DataStore Preferences: 1.1.1
- Credentials (Google Sign-In): 1.5.0-beta01

### Networking
- Retrofit: 2.11.0
- OkHttp: 4.12.0 + Logging Interceptor
- Kotlinx Serialization JSON: 1.7.3

### Database
- Room: 2.7.0 (runtime + ktx + compiler)
- SQLCipher: 4.6.1

### Security
- Google Tink (Android): 1.10.0

### Markdown Rendering
- Markwon Core: 4.6.2
- Markwon Strikethrough: 4.6.2
- Markwon Tables: 4.6.2

### Testing
- JUnit 4: 4.13.2
- JUnit Ext (AndroidX): 1.2.1
- Mockk: 1.13.13
- Turbine (StateFlow testing): 1.2.0
- Truth (assertions): 1.4.4
- MockWebServer (OkHttp): 4.12.0
- Robolectric: 4.14.1
- Architecture Core Testing: 2.2.0
- Test Core: 1.6.1
- Compose UI Test JUnit4: via BOM
- Room Testing: 2.7.0
- Kotlinx Coroutines Test: 1.9.0

## Stack Final Consolidado

```
┌─────────────────────────────────────────────┐
│           SAVIA MOBILE ANDROID              │
├─────────────────────────────────────────────┤
│ Kotlin      │ 2.1.0 (JVM target 17)        │
│ AGP         │ 8.13.2                        │
│ Compose     │ 2024.12.01 BOM + Material 3  │
│             │                               │
│ UI          │ Jetpack Compose               │
│ State       │ ViewModel + StateFlow         │
│ Navigation  │ Navigation Compose 2.8.5      │
│ DI          │ Hilt 2.56.2                   │
├─────────────────────────────────────────────┤
│ HTTP        │ Retrofit 2.11.0 + OkHttp 4.12│
│ Streaming   │ SSE via savia-bridge.py       │
│ SSH Bridge  │ savia-bridge.py (pure Python) │
│ JSON        │ Kotlin Serialization 1.7.3    │
├─────────────────────────────────────────────┤
│ Storage     │ Room 2.7.0 + DataStore 1.1.1 │
│ Encryption  │ SQLCipher 4.6.1 + Tink 1.10.0│
│ Crypto DB   │ SQLCipher AES-256             │
├─────────────────────────────────────────────┤
│ Testing     │ JUnit 4 + Mockk + Turbine     │
│ UI Tests    │ Compose UI Test JUnit4        │
│ CI/CD       │ GitHub Actions                │
│ Target      │ SDK 26-35 (Android 8.0 → 15) │
└─────────────────────────────────────────────┘
```

## Arquitectura de Capas

```
Presentation Layer (Jetpack Compose)
├─ Screens (Sprint Status, Chat, etc.)
├─ ViewModels (Hilt-injected)
└─ Navigation (Navigation Compose)

Domain Layer
├─ Use Cases (Business logic)
├─ Entities (App models)
└─ Repositories (abstraction)

Data Layer
├─ RepositoryImpl (Room + API)
├─ Local (Room DAO, DataStore)
└─ Remote (Retrofit + OkHttp)

Infrastructure
├─ Networking (Retrofit, OkHttp)
├─ Security (Tink, Android Keystore)
└─ Database (Room, SQLCipher)
```

## Consideraciones de Rendimiento

- Compile-time DI con Hilt (KSP) → mejora startup
- Baseline profiles (generados en nightly CI) → optimiza Compose
- Room queries compiladas en tiempo de compilación → previene runtime errors
- DataStore async (no bloquea UI) → mejor responsividad
- State management con StateFlow → cancellable coroutines
- APK target size: <20 MB (verificado en CI)

## Seguridad

- API keys nunca en texto plano (Tink + Android Keystore)
- BD cifrada con SQLCipher (AES-256)
- Conexión al bridge via HTTPS + cert fingerprint verification
- No almacenar contraseñas SSH (delegado al bridge)
- Biometric lock opcional para app

## Deprecaciones Evitadas

- ❌ EncryptedSharedPreferences → ✅ DataStore
- ❌ JSch directo → ✅ Bridge Python
- ❌ LiveData → ✅ StateFlow
- ❌ Dagger directo → ✅ Hilt
- ❌ ViewBinding manual → ✅ Compose

