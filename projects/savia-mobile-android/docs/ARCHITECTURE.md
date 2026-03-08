# Arquitectura de Savia Mobile

## Visión General

Savia Mobile es una aplicación Android nativa construida con arquitectura limpia (Clean Architecture) que separa la lógica en tres módulos independientes:

```
┌─────────────────────────────────────────────────────────────┐
│                    Capa de Presentación                      │
│  (Composables, ViewModels, Navigation)                       │
│               (módulo: app)                                   │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                  Capa de Dominio                             │
│  (Casos de uso, Entidades, Puertos/Contratos)               │
│               (módulo: domain)                               │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                   Capa de Datos                              │
│  (Repositorios, Fuentes de datos, Mappers)                   │
│               (módulo: data)                                 │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
        ┌────────────┬────────────┐
        │            │            │
        ▼            ▼            ▼
    Savia Bridge  Claude API  Local DB
```

## Módulos

### 1. app (Presentación)

**Responsabilidades:**
- Interfaz de usuario en Jetpack Compose
- Navegación entre pantallas (Compose Navigation)
- ViewModels para gestión de estado
- Inyección de dependencias con Hilt

**Estructura:**
```
app/
├── src/main/kotlin/com/savia/mobile/
│   ├── MainActivity.kt
│   ├── SaviaNavigation.kt          ← Rutas y grafo de navegación
│   ├── di/
│   │   └── NetworkModule.kt         ← Inyección de Retrofit, OkHttp
│   ├── ui/
│   │   ├── screens/                 ← Composables por pantalla
│   │   └── theme/                   ← Colores, tipografía, estilos
│   └── viewmodel/                   ← ViewModels de cada pantalla
├── build.gradle.kts                 ← JDK 17, Compose, Hilt, Retrofit
└── proguard-rules.pro
```

**Dependencias:**
- `domain` (casos de uso, entidades)
- `data` (repositorios, fuentes de datos)

---

### 2. domain (Lógica de Negocio)

**Responsabilidades:**
- Definir entidades del negocio (Usuario, Chat, Sesión)
- Casos de uso (UseCases) que orquestan lógica
- Puertos (interfaces) para abstraer repositorios
- Sin dependencias hacia Android ni frameworks externos

**Estructura:**
```
domain/
├── src/main/kotlin/com/savia/domain/
│   ├── model/                       ← Entidades
│   │   ├── User.kt
│   │   ├── ChatMessage.kt
│   │   └── Session.kt
│   ├── usecase/                     ← Casos de uso
│   │   ├── SendMessageUseCase.kt
│   │   ├── LoadChatHistoryUseCase.kt
│   │   └── CreateSessionUseCase.kt
│   └── repository/                  ← Puertos (interfaces)
│       ├── ChatRepository.kt
│       ├── SessionRepository.kt
│       └── UserRepository.kt
└── build.gradle.kts                 ← Solo Kotlin stdlib + Coroutines
```

**Responsabilidad clave:** `domain` no depende de nada. Todos otros módulos importan `domain`.

---

### 3. data (Acceso a Datos)

**Responsabilidades:**
- Implementar interfaces de `domain` (repositorios)
- Conectar con Savia Bridge (HTTPS) o Claude API directa
- Mapear respuestas HTTP a entidades de dominio
- Serialización/deserialización JSON con kotlinx.serialization

**Estructura:**
```
data/
├── src/main/kotlin/com/savia/data/
│   ├── api/
│   │   ├── ClaudeApiService.kt      ← Retrofit service para API de Anthropic
│   │   ├── SaviaBridgeService.kt    ← Retrofit service para Savia Bridge
│   │   └── model/                   ← DTOs (modelos de respuesta API)
│   ├── repository/                  ← Implementación de puertos
│   │   ├── ChatRepositoryImpl.kt
│   │   └── SessionRepositoryImpl.kt
│   └── mapper/                      ← Conversión DTO → Entidad
│       └── ChatMapper.kt
└── build.gradle.kts                 ← Retrofit, OkHttp, kotlinx.serialization
```

**Dual-Mode:** La app puede conectar con:
1. **Savia Bridge** (servidor HTTPS local/VPN) → inyección de perfil
2. **Claude API directa** (api.anthropic.com) → sin contexto de usuario

---

## Inyección de Dependencias (Hilt)

### NetworkModule.kt

Define los OkHttpClient y Retrofit para ambos canales:

```kotlin
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {

    // OkHttpClient estándar (certificados del sistema)
    @Provides
    fun provideOkHttpClient(): OkHttpClient { ... }

    // OkHttpClient para Bridge (acepta certificados autofirmados)
    @Provides
    @Named("bridge")
    fun provideBridgeOkHttpClient(): OkHttpClient { ... }

    // Retrofit para Claude API
    @Provides
    fun provideRetrofit(client: OkHttpClient, json: Json): Retrofit { ... }

    // Services
    @Provides
    fun provideClaudeApiService(retrofit: Retrofit): ClaudeApiService { ... }

    @Provides
    fun provideSaviaBridgeService(
        @Named("bridge") bridgeClient: OkHttpClient,
        json: Json
    ): SaviaBridgeService { ... }
}
```

**Configuración de Bridge:**
- Timeout de lectura: **300 segundos** (streaming de Claude)
- TLS: acepta certificados autofirmados
- Autenticación: token en header `Authorization: Bearer {TOKEN}`

---

## Flujo de Datos

### 1. Usuario escribe un mensaje en la UI

```
┌─────────────────────────────────────────────────────┐
│ Composable (ChatScreen.kt)                          │
│ ┌───────────────────────────────────────────────┐   │
│ │ TextField: "Ayúdame con el sprint"            │   │
│ │ Button: "Enviar"                              │   │
│ └───────────────────────────────────────────────┘   │
└────────────────────┬────────────────────────────────┘
                     │ onSendMessage(text)
                     ▼
┌─────────────────────────────────────────────────────┐
│ ViewModel (ChatViewModel.kt)                        │
│ ┌───────────────────────────────────────────────┐   │
│ │ viewModelScope.launch {                       │   │
│ │   sendMessageUseCase(text)                    │   │
│ │ }                                              │   │
│ └───────────────────────────────────────────────┘   │
└────────────────────┬────────────────────────────────┘
                     │ UseCase
                     ▼
┌─────────────────────────────────────────────────────┐
│ SendMessageUseCase (domain)                         │
│ ┌───────────────────────────────────────────────┐   │
│ │ chatRepository.sendMessage(message)           │   │
│ └───────────────────────────────────────────────┘   │
└────────────────────┬────────────────────────────────┘
                     │ Repository
                     ▼
┌─────────────────────────────────────────────────────┐
│ ChatRepositoryImpl (data)                           │
│ ┌───────────────────────────────────────────────┐   │
│ │ if (useBridge) {                               │   │
│ │   saviaBridgeService.chat(message)            │   │
│ │ } else {                                        │   │
│ │   claudeApiService.messages(message)          │   │
│ │ }                                              │   │
│ └───────────────────────────────────────────────┘   │
└────────────────────┬────────────────────────────────┘
                     │ HTTPS
        ┌────────────┴────────────┐
        │                         │
        ▼                         ▼
   Savia Bridge             Claude API
   (puerto 8922)            (api.anthropic.com)
```

### 2. Respuesta de Claude (SSE Streaming)

```
Savia Bridge → event: message_start
             → event: message_delta (chunk 1)
             → event: message_delta (chunk 2)
             → ...
             → event: message_stop
    │
    └─► OkHttp interceptor
        └─► Response body (SSE)
            └─► ChatRepositoryImpl.sendMessage()
                └─► Flow<ChatMessage>
                    └─► ViewModel.uiState
                        └─► Composable updates UI
```

---

## Componentes Clave

### SaviaNavigation.kt

Define las rutas y la estructura de navegación:

```kotlin
@Composable
fun SaviaApp(navController: NavHostController) {
    NavHost(navController, startDestination = "home") {
        composable("home") { HomeScreen() }
        composable("chat/{sessionId}") { ChatScreen(it.arguments?.getString("sessionId")) }
        composable("settings") { SettingsScreen() }
    }
}
```

### NetworkModule.kt

**Bridge OkHttpClient** - Diferencias clave:
- `SSLContext`: permite certificados autofirmados
- `HostnameVerifier`: acepta cualquier hostname
- `readTimeout`: 300 segundos (respuestas largas de Claude)
- Logging en HEADERS level

**Dual-mode:**
- Si hay conexión a Bridge (configurada en settings) → usar BridgeService
- Si no hay Bridge → usar Claude API directa (requiere API key)

---

## Patrones de Arquitectura

### 1. Clean Architecture (3 capas)

```
Presentation (UI, ViewModel)
         ↓
Domain (UseCases, Entities)
         ↓
Data (Repositories, Network)
```

Dependencias **unidireccionales**: Solo hacia adentro (hacia Domain).

### 2. Inyección de Dependencias (Hilt)

```kotlin
@HiltViewModel
class ChatViewModel @Inject constructor(
    private val sendMessageUseCase: SendMessageUseCase,
    private val sessionRepository: SessionRepository
) : ViewModel() { ... }
```

### 3. Reactive Streams (Flow)

Todos los repositorios devuelven `Flow<T>` para observabilidad:

```kotlin
interface ChatRepository {
    fun sendMessage(message: String): Flow<ChatMessage>
    fun getHistory(): Flow<List<ChatMessage>>
}
```

### 4. Repository Pattern

Abstrae fuentes de datos (Network, Cache, Local DB):

```kotlin
class ChatRepositoryImpl @Inject constructor(
    private val bridgeService: SaviaBridgeService,
    private val claudeService: ClaudeApiService
) : ChatRepository {
    override fun sendMessage(msg: String): Flow<ChatMessage> =
        if (config.useBridge)
            bridgeService.chat(msg)
        else
            claudeService.messages(msg)
}
```

---

## Diferencias: Bridge vs. Claude API

| Aspecto | Savia Bridge | Claude API |
|---------|-------------|-----------|
| **URL** | `https://localhost:8922` (VPN) | `https://api.anthropic.com` |
| **Autenticación** | Bearer token (auth_token) | API key |
| **TLS** | Certificado autofirmado | Certificados del sistema |
| **Contexto** | Inyecta perfil del usuario | Sin contexto de usuario |
| **Disponibilidad** | Requiere Bridge corriendo | Siempre disponible (con clave) |

---

## Configuración del Proyecto

### settings.gradle.kts

Incluye los 3 módulos:

```kotlin
include(":app")
include(":domain")
include(":data")
```

### build.gradle.kts (app)

```kotlin
dependencies {
    implementation(project(":domain"))
    implementation(project(":data"))

    // Jetpack Compose, Navigation, Hilt
    implementation(libs.compose.ui)
    implementation(libs.navigation.compose)
    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
}
```

---

## Flujo de Compilación

```
settings.gradle.kts
    ├── domain/ (Kotlin stdlib, Coroutines)
    ├── data/ (Retrofit, OkHttp, kotlinx.serialization)
    └── app/ (Compose, Navigation, Hilt)
        └── app/src/main/AndroidManifest.xml (única manifestación)

Construcción:
1. Compilar domain/
2. Compilar data/ (depende de domain/)
3. Compilar app/ (depende de domain + data/)
4. Generar APK con ProGuard (release) o sin (debug)
```

---

## Seguridad

### Bridge (Local/VPN)

1. **TLS autofirmado**: Aceptable en VPN/red local
2. **Token de autenticación**: `Authorization: Bearer {token}`
3. **Certificate pinning**: Futura mejora (fingerprint almacenado)

### Claude API

1. **Certificados estándar del sistema**
2. **API key** como credencial
3. **HTTPS obligatorio**

---

## Resumen de Módulos

| Módulo | Tipo | Dependencias | Responsabilidad |
|--------|------|--------------|-----------------|
| **app** | Android | domain, data, Compose, Hilt | UI, Navegación, ViewModels |
| **domain** | Kotlin puro | stdlib, Coroutines | Lógica de negocio, Puertos |
| **data** | Kotlin + Android | domain, Retrofit, OkHttp | Repositorios, Networking |

---

## Siguientes Pasos

- Implementar autenticación con Google Sign-In
- Añadir Room Database para caché local
- Integrar Markdown rendering en UI
- Testing: unitarios (domain), integración (data), UI (app)
