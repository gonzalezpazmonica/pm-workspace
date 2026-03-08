# Savia Mobile — Documento de Diseño Técnico

> Última actualización: Marzo 2026
> Versión: 1.0 (Implementación actual)
> Autores: Savia Mobile Team

## 1. Arquitectura General

### Estructura de Módulos

```
savia-mobile-android/
├── app/                                        # Application module (Hilt entry point)
│   ├── src/main/kotlin/com/savia/mobile/
│   │   ├── MainActivity.kt                    # Single Activity
│   │   ├── SaviaApp.kt                        # @HiltAndroidApp
│   │   ├── auth/                              # Google Sign-In (futuro)
│   │   │   └── GoogleAuthManager.kt
│   │   ├── di/                                # Hilt modules
│   │   │   ├── NetworkModule.kt               # Retrofit, OkHttp, JSON
│   │   │   ├── RepositoryModule.kt            # Repository bindings
│   │   │   └── DatabaseModule.kt              # Room database
│   │   └── ui/                                # Jetpack Compose screens
│   │       ├── navigation/
│   │       │   └── SaviaNavigation.kt         # NavHost, Screen routes
│   │       ├── chat/
│   │       │   ├── ChatScreen.kt
│   │       │   ├── ChatViewModel.kt
│   │       │   └── components/
│   │       ├── dashboard/
│   │       │   ├── DashboardScreen.kt
│   │       │   └── DashboardViewModel.kt
│   │       ├── settings/
│   │       │   ├── SettingsScreen.kt
│   │       │   └── SettingsViewModel.kt
│   │       └── theme/
│   │           ├── Color.kt                   # Material 3 colors (violet/mauve)
│   │           ├── Type.kt                    # Typography
│   │           └── Theme.kt                   # CompositionLocalProvider
│   └── build.gradle.kts
│
├── domain/                                     # Pure Kotlin (no Android deps)
│   ├── src/main/kotlin/com/savia/domain/
│   │   ├── model/
│   │   │   ├── Message.kt                    # Message(id, role, content)
│   │   │   ├── Conversation.kt               # Conversation(id, title, messages)
│   │   │   ├── MessageRole.kt                # USER, ASSISTANT, SYSTEM
│   │   │   └── StreamDelta.kt                # Text, Done, Error, Start
│   │   ├── repository/
│   │   │   ├── ChatRepository.kt             # Interface
│   │   │   └── SecurityRepository.kt         # Config storage interface
│   │   └── usecase/
│   │       └── SendMessageUseCase.kt         # Main business logic
│   └── build.gradle.kts
│
├── data/                                       # Implementation layer
│   ├── src/main/kotlin/com/savia/data/
│   │   ├── api/
│   │   │   ├── SaviaBridgeService.kt         # Bridge HTTP client
│   │   │   ├── ClaudeApiService.kt           # Anthropic Retrofit interface
│   │   │   ├── ClaudeStreamParser.kt         # SSE event parser
│   │   │   └── model/
│   │   │       ├── ApiMessage.kt
│   │   │       └── CreateMessageRequest.kt
│   │   ├── local/
│   │   │   ├── database/
│   │   │   │   └── SaviaDatabase.kt
│   │   │   ├── entity/
│   │   │   │   ├── ConversationEntity.kt
│   │   │   │   └── MessageEntity.kt
│   │   │   └── dao/
│   │   │       └── ConversationDao.kt
│   │   ├── security/
│   │   │   ├── TinkCryptoManager.kt
│   │   │   └── SecureStorageManager.kt
│   │   └── repository/
│   │       ├── ChatRepositoryImpl.kt          # Dual-stack routing
│   │       └── SecurityRepositoryImpl.kt      # Config management
│   └── build.gradle.kts
│
├── build.gradle.kts                           # Root config
└── settings.gradle.kts                        # Module declaration
```

### Capas Clean Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                       │
│  (Compose UI: ChatScreen, DashboardScreen, SettingsScreen) │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                   ViewModel Layer                           │
│    (ChatViewModel, DashboardViewModel, SettingsViewModel)   │
│               StateFlow<UiState>                            │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                    Domain Layer                             │
│  (SendMessageUseCase, interfaces, domain models)           │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                    Data Layer                               │
│  (ChatRepositoryImpl, API clients, Room database)           │
└──────────────────────────┬──────────────────────────────────┘
                           │
    ┌──────────────────────┼──────────────────────┐
    ▼                      ▼                      ▼
┌────────────┐      ┌────────────┐       ┌───────────────┐
│  Bridge    │      │ Anthropic  │       │  Room DB +    │
│  (Primary) │      │  API (FB)  │       │  SQLCipher    │
└────────────┘      └────────────┘       └───────────────┘
```

## 2. Flujo de Datos

### Envío de Mensaje

```
1. ChatScreen (UI)
   ├─ User taps "Send"
   └─ Calls ChatViewModel.sendMessage(content)

2. ChatViewModel
   ├─ Check if conversation exists
   ├─ Create or use existing ConversationId
   ├─ Create user Message
   ├─ Emit to UI state
   └─ Call SendMessageUseCase(conversationId, content)

3. SendMessageUseCase (Domain)
   ├─ Pass through to ChatRepository.sendMessage()
   └─ Returns Flow<StreamDelta>

4. ChatRepositoryImpl (Data)
   ├─ Determine route:
   │  ├─ If SecurityRepository.hasBridgeConfig() → SaviaBridgeService
   │  └─ Else → ClaudeApiService (Anthropic)
   ├─ Load message history from Room
   ├─ Send request to selected endpoint
   └─ Parse SSE stream via ClaudeStreamParser

5. SaviaBridgeService or ClaudeApiService
   ├─ Make HTTP request
   └─ Emit StreamDelta events:
      ├─ StreamDelta.Text (content chunk)
      ├─ StreamDelta.Done (completion)
      └─ StreamDelta.Error (errors)

6. ChatRepositoryImpl
   ├─ Collect full response into StringBuilder
   ├─ On StreamDelta.Done:
   │  ├─ Save assistant message to Room
   │  ├─ Update conversation timestamp
   │  └─ Auto-title (if message count ≤ 2)
   └─ Emit deltas to Flow

7. ChatViewModel
   ├─ Collect deltas from repository
   ├─ On StreamDelta.Text: append to streamingText state
   ├─ On StreamDelta.Done:
   │  ├─ Create final Message object
   │  ├─ Add to messages list
   │  ├─ Clear streamingText
   │  └─ Set isStreaming = false

8. ChatScreen (UI)
   ├─ Collect uiState changes
   └─ Recompose to display new messages
```

### Carga de Conversación

```
ChatScreen → ChatViewModel.loadConversation(conversationId)
           → ChatRepository.getMessages(conversationId)
           → Room Flow → ChatViewModel.uiState updates
           → ChatScreen recomposes with messages
```

## 3. Configuración de Conexión Dual

### Preferencia de Ruta

```
Decision Logic (ChatRepositoryImpl.sendMessage):

if (securityRepository.hasBridgeConfig()) {
    // Primary: Savia Bridge
    val bridgeUrl = securityRepository.getBridgeUrl()
    val bridgeToken = securityRepository.getBridgeToken()

    return bridgeService.sendMessageStream(
        bridgeUrl, bridgeToken, message, sessionId, systemPrompt
    )
} else {
    // Fallback: Anthropic API
    val apiKey = securityRepository.getApiKey()

    // Must send full message history (stateless)
    val messages = conversationDao.getMessages(conversationId).first()

    return apiService.createMessageStream(apiKey, messages)
}
```

### Bridge (Primario)

**Endpoint**: `POST https://localhost:8922/chat` (configurable)

**Autenticación**: `Authorization: Bearer {token}`

**Request**:
```json
{
  "message": "user text",
  "session_id": "conversation-id",
  "system_prompt": "optional instructions"
}
```

**Response** (SSE):
```
data: {"type":"text","text":"chunk"}
data: {"type":"done"}
data: {"type":"error","text":"message"}
```

**Ventajas**:
- Mantiene sesión en servidor (conversación en servidor)
- Más rápido (menor latencia)
- No requiere enviar historial completo cada vez
- Integración futura con PM-Workspace

**Implementación**: `SaviaBridgeService.sendMessageStream()`

### API Directo (Fallback)

**Endpoint**: `POST https://api.anthropic.com/v1/messages` (Retrofit)

**Autenticación**: `x-api-key: {key}`

**Request**:
```json
{
  "model": "claude-3-5-sonnet-20241022",
  "max_tokens": 1024,
  "system": "optional system prompt",
  "messages": [
    {"role": "user", "content": "..."},
    {"role": "assistant", "content": "..."}
  ]
}
```

**Response** (SSE):
```
event: content_block_start
data: {"type":"content_block_start","content_block":{"type":"text"}}

event: content_block_delta
data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"chunk"}}

event: message_stop
data: {"type":"message_stop"}
```

**Implementación**:
- `ClaudeApiService` (Retrofit interface)
- `ClaudeStreamParser.parse()` (SSE parsing)

## 4. Streaming SSE

### Implementación en Android

**Problema**: Retrofit no soporta SSE out-of-box. OkHttpClient devuelve ResponseBody buffered.

**Solución**:

```kotlin
// SaviaBridgeService.sendMessageStream()
val response = httpClient.newCall(request).execute()
response.body?.source()?.use { source ->
    while (!source.exhausted()) {
        val line = source.readUtf8Line() ?: continue
        if (line.startsWith("data: ")) {
            val json = line.removePrefix("data: ").trim()
            val event = Json.decodeFromString<BridgeStreamEvent>(json)
            when (event.type) {
                "text" -> trySend(StreamDelta.Text(event.text ?: ""))
                "done" -> { trySend(StreamDelta.Done); close() }
                "error" -> trySend(StreamDelta.Error(event.text ?: "Error"))
            }
        }
    }
}
```

**Características**:
- `callbackFlow {}` para backpressure-aware Flow
- `BufferedSource.readUtf8Line()` para leer líneas sin buffering completo
- `Dispatchers.IO` para no bloquear UI thread
- Manejo de eventos malformados (skip con try-catch)

### Streaming Completo hasta UI

```
SaviaBridgeService.sendMessageStream()
  → emits StreamDelta.Text("chunk1"), .Text("chunk2"), ..., .Done

ClaudeStreamParser.parse(responseBody)
  → emits same deltas for Anthropic API

ChatRepositoryImpl.sendMessage()
  → collects deltas
  → accumulates text in StringBuilder
  → on Done: saves full message to Room

ChatViewModel.sendMessage()
  → collects deltas
  → StreamDelta.Text: update state.streamingText (visual)
  → StreamDelta.Done: finalize message

ChatScreen
  → collects uiState
  → recomposes on every text delta (smooth visual feedback)
```

## 5. Persistencia Local

### Room Database Schema

```sql
-- Conversaciones
CREATE TABLE conversations (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    createdAt INTEGER NOT NULL,
    updatedAt INTEGER NOT NULL,
    isArchived INTEGER NOT NULL DEFAULT 0
);

-- Mensajes
CREATE TABLE messages (
    id TEXT PRIMARY KEY,
    conversationId TEXT NOT NULL,
    role TEXT NOT NULL,  -- USER, ASSISTANT, SYSTEM
    content TEXT NOT NULL,
    timestamp INTEGER NOT NULL,
    FOREIGN KEY (conversationId) REFERENCES conversations(id)
        ON DELETE CASCADE
);

-- Índices
CREATE INDEX idx_messages_conversationId ON messages(conversationId);
CREATE INDEX idx_conversations_updatedAt ON conversations(updatedAt DESC);
```

### Operaciones DAO

```kotlin
interface ConversationDao {
    // Read
    @Query("SELECT * FROM conversations WHERE id = :id")
    fun getById(id: String): Flow<ConversationEntity?>

    @Query("SELECT * FROM conversations WHERE isArchived = 0 ORDER BY updatedAt DESC")
    fun getAll(): Flow<List<ConversationEntity>>

    @Query("SELECT * FROM messages WHERE conversationId = :conversationId ORDER BY timestamp ASC")
    fun getMessages(conversationId: String): Flow<List<MessageEntity>>

    // Write
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertConversation(conversation: ConversationEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertMessage(message: MessageEntity)

    @Update
    suspend fun updateTitle(id: String, title: String)

    @Query("UPDATE conversations SET updatedAt = :timestamp WHERE id = :id")
    suspend fun updateTimestamp(id: String, timestamp: Long)

    // Delete
    @Query("DELETE FROM conversations WHERE id = :id")
    suspend fun deleteConversation(id: String)
}
```

### Encriptación (SQLCipher)

```kotlin
// DatabaseModule.kt
Room.databaseBuilder(context, SaviaDatabase::class.java, "savia.db")
    .openHelperFactory(SupportFactory(passphrase.toByteArray()))  // SQLCipher
    .build()
```

**Passphrase**: Derivada de clave maestra Tink (hardware-backed)

## 6. Seguridad

### Tink AEAD (AES-256-GCM)

```kotlin
class TinkCryptoManager @Inject constructor(context: Context) {
    private val aead: Aead by lazy {
        AeadConfig.register()
        AndroidKeysetManager.Builder()
            .withSharedPref(context, "savia_keyset", "savia_prefs")
            .withKeyTemplate(AesGcmKeyManager.aes256GcmTemplate())
            .withMasterKeyUri("android-keystore://savia_master")
            .build()
            .keysetHandle
            .getPrimitive(Aead::class.java)
    }

    fun encrypt(data: ByteArray): ByteArray =
        aead.encrypt(data, "savia-mobile".toByteArray())

    fun decrypt(data: ByteArray): ByteArray =
        aead.decrypt(data, "savia-mobile".toByteArray())
}
```

**Características**:
- Clave maestra almacenada en Android Keystore (hardware-backed si disponible)
- AES-256-GCM para autenticación + confidencialidad
- Nonce aleatorio por operación (automático en Tink)

### SecureStorageManager

```kotlin
class SecureStorageManager @Inject constructor(
    context: Context,
    private val cryptoManager: TinkCryptoManager
) {
    private val prefs = EncryptedSharedPreferences.create(
        context,
        "savia_secure",
        masterKey,  // Tink-derived
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    fun saveBridgeToken(token: String) {
        prefs.edit().putString("bridge_token", cryptoManager.encrypt(token.toByteArray()))
    }
}
```

**Almacenamiento de Secretos**:
- API key: EncryptedSharedPreferences + Tink
- Bridge token: EncryptedSharedPreferences + Tink
- Bridge URL: EncryptedSharedPreferences (URL no es secreto pero se encripta por consistencia)

## 7. Inyección de Dependencias (Hilt)

### NetworkModule

```kotlin
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {
    @Provides
    @Singleton
    fun provideJson(): Json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
    }

    @Provides
    @Singleton
    fun provideOkHttpClient(
        loggingInterceptor: HttpLoggingInterceptor
    ): OkHttpClient = OkHttpClient.Builder()
        .addInterceptor(loggingInterceptor)
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build()

    @Provides
    @Singleton
    fun provideRetrofit(
        json: Json,
        okHttpClient: OkHttpClient
    ): Retrofit = Retrofit.Builder()
        .baseUrl("https://api.anthropic.com/")
        .client(okHttpClient)
        .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
        .build()

    @Provides
    @Singleton
    fun provideClaudeApiService(retrofit: Retrofit): ClaudeApiService =
        retrofit.create(ClaudeApiService::class.java)

    @Provides
    @Singleton
    fun provideSaviaBridgeService(
        httpClient: OkHttpClient,
        json: Json
    ): SaviaBridgeService = SaviaBridgeService(httpClient, json)
}
```

### RepositoryModule

```kotlin
@Module
@InstallIn(SingletonComponent::class)
object RepositoryModule {
    @Provides
    @Singleton
    fun provideChatRepository(
        apiService: ClaudeApiService,
        bridgeService: SaviaBridgeService,
        streamParser: ClaudeStreamParser,
        conversationDao: ConversationDao,
        securityRepository: SecurityRepository
    ): ChatRepository = ChatRepositoryImpl(
        apiService, bridgeService, streamParser,
        conversationDao, securityRepository
    )

    @Provides
    @Singleton
    fun provideSecurityRepository(
        context: Context,
        cryptoManager: TinkCryptoManager
    ): SecurityRepository = SecurityRepositoryImpl(
        context, cryptoManager
    )
}
```

### DatabaseModule

```kotlin
@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {
    @Provides
    @Singleton
    fun provideSaviaDatabase(
        context: Context,
        cryptoManager: TinkCryptoManager
    ): SaviaDatabase = Room.databaseBuilder(
        context,
        SaviaDatabase::class.java,
        "savia.db"
    ).openHelperFactory(
        SupportFactory(
            cryptoManager.getMasterKeyBytes()  // Passphrase
        )
    ).build()

    @Provides
    @Singleton
    fun provideConversationDao(
        database: SaviaDatabase
    ): ConversationDao = database.conversationDao()
}
```

## 8. Navegación

### Rutas

```kotlin
sealed class Screen(val route: String) {
    data object Chat : Screen("chat")
    data object Sessions : Screen("sessions")
    data object Settings : Screen("settings")
}

// Bottom navigation items
val bottomNavScreens = listOf(
    Screen.Chat,
    Screen.Sessions,
    Screen.Settings
)
```

### NavHost

```kotlin
NavHost(
    navController,
    startDestination = Screen.Chat.route
) {
    composable(Screen.Chat.route) { ChatScreen() }
    composable(Screen.Sessions.route) {
        DashboardScreen(
            onConversationSelected = { id ->
                navController.navigate("chat?conversationId=$id")
            }
        )
    }
    composable("chat?conversationId={conversationId}") { entry ->
        val id = entry.arguments?.getString("conversationId")
        ChatScreen(conversationIdToLoad = id?.takeIf { it.isNotBlank() })
    }
    composable(Screen.Settings.route) { SettingsScreen() }
}
```

**Bottom Navigation**:
- Material 3 NavigationBar
- saveState/restoreState para preservar scroll y state
- launchSingleTop para evitar duplicados en back stack

## 9. Persistencia de Sesión

### Restauración en App Launch

```kotlin
// ChatViewModel.init {}
init {
    checkConfig()
    loadConversations()
    restoreLastSession()
}

private fun restoreLastSession() {
    viewModelScope.launch {
        val lastId = securityRepository.getLastConversationId()
        if (lastId != null) {
            loadConversation(lastId)
        }
    }
}
```

### Guardado en SecurityRepository

```kotlin
// Al cambiar conversación o crear nueva:
fun saveCurrentSession(conversationId: String) {
    viewModelScope.launch {
        securityRepository.saveLastConversationId(conversationId)
    }
}
```

**Comportamiento**:
- Si hay última conversación: restaura automáticamente
- Si no hay: pantalla vacía (invita a crear nueva)
- Al cambiar de conversación: guarda ID para próxima sesión
- Al eliminar conversación activa: limpia almacenamiento

## 10. Dependencias Principales

```gradle
// Platform
compose-bom = "2024.06.00"
kotlin = "2.1.0"

// Compose
compose.ui = "1.7.1"
compose.material3 = "1.2.1"

// AndroidX
androidx-core-ktx = "1.13.1"
androidx-lifecycle = "2.8.1"
androidx-navigation-compose = "2.7.7"
androidx-splashscreen = "1.1.1"

// Networking
retrofit = "2.11.0"
okhttp = "4.12.0"
kotlinx-serialization = "1.6.0"

// Local Storage
room = "2.7.0"
sqlcipher = "4.6.0"
datastore = "1.1.1"
androidx-security-crypto = "1.1.0-alpha06"

// Security & Crypto
tink = "1.10.0"
google-credential-manager = "1.2.0"

// Markdown & Rendering
markwon = "4.6.2"

// DI
hilt = "2.51"

// Testing
junit = "4.13.2"
mockk = "1.13.10"
turbine = "1.0.0"
truth = "1.4.2"
robolectric = "4.12.1"
mockwebserver = "4.12.0"
```

## 11. Requisitos de Versión

- **Kotlin**: 2.1.0+
- **Java Target**: 17
- **Gradle**: 8.9+
- **AGP**: 8.x+
- **Android SDK**: min 26, target 35

## 12. Modelos de Dominio

```kotlin
// Message
data class Message(
    val id: String,
    val conversationId: String,
    val role: MessageRole,        // USER, ASSISTANT, SYSTEM
    val content: String,
    val timestamp: Long = System.currentTimeMillis(),
    val isStreaming: Boolean = false,
    val tokenCount: Int? = null
)

// Conversation
data class Conversation(
    val id: String,
    val title: String,
    val messages: List<Message> = emptyList(),
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val isArchived: Boolean = false
)

// Stream events
sealed class StreamDelta {
    data class Text(val text: String) : StreamDelta()
    data object Done : StreamDelta()
    data class Error(val message: String) : StreamDelta()
    data object Start : StreamDelta()
}
```

## 13. Flujo Completo: Enviar Mensaje

```
Usuario escribe "¿Qué es Kotlin?" y toca "Send"
  ↓
ChatScreen.sendButton.onClick()
  ↓
ChatViewModel.sendMessage("¿Qué es Kotlin?")
  ↓
ChatViewModel crea Message(role=USER) en estado
  ↓
ChatViewModel llama SendMessageUseCase(conversationId, content)
  ↓
SendMessageUseCase llama ChatRepository.sendMessage()
  ↓
ChatRepositoryImpl.sendMessage():
  - Determina si usar Bridge (hasBridgeConfig?) o API
  - Carga historial de Room
  - Hace request HTTP con SSE
  ↓
SSE Stream comienza:
  "data: {type: text, text: "Kotlin"}"
  "data: {type: text, text: " es un"}"
  "data: {type: text, text: " lenguaje..."}"
  "data: {type: done}"
  ↓
ChatRepositoryImpl.sendMessage() emite:
  StreamDelta.Text("Kotlin")
  StreamDelta.Text(" es un")
  StreamDelta.Text(" lenguaje...")
  StreamDelta.Done
  ↓
ChatViewModel.sendMessage() colecta:
  StreamDelta.Text → _uiState.update { streamingText += "Kotlin" }
  StreamDelta.Text → _uiState.update { streamingText += " es un" }
  ...
  StreamDelta.Done →
    - Crea Message(role=ASSISTANT, content=streamingText)
    - Guarda en Room
    - Actualiza timestamp conversación
    - Auto-titula si primer mensaje
    - Limpia streamingText
  ↓
ChatScreen.collect(uiState):
  - Re-compose con nuevos mensajes
  - Material Text con markdown rendering
  - Usuario ve respuesta en tiempo real
```

## 14. Decisiones de Arquitectura

### Por qué Clean Architecture
- **Testabilidad**: Domain totalmente independiente de Android
- **Reusabilidad**: Data layer reutilizable en iOS (KMP futuro)
- **Mantenibilidad**: Cambios en UI no afectan business logic

### Por qué Flow en lugar de LiveData
- **Composable**: Compose native, sin bridge
- **Reactive**: Multicast sin observer pattern
- **Structured Concurrency**: Cancellation automática con viewModelScope

### Por qué Room en lugar de DataStore
- **Queries**: Búsqueda por conversationId, ordenamiento
- **Escalabilidad**: 10k+ mensajes sin degradación
- **Crypto**: SQLCipher integrado

### Por qué Hilt en lugar de Manual DI
- **Compile-safe**: Errores en build time
- **Boilerplate**: Inyección automática
- **Scope**: Singleton, ViewModelScoped, etc. automático

## 15. Consideraciones de Futuro

### Kotlin Multiplatform (v2.0)
- Domain y Data layer serán compartidos
- UI Compose solo Android (Xcode bridging para iOS)
- Compilación a shared.framework para iOS

### WebSocket para Bridge
- SSE actual funciona pero HTTP request/response es innecesario
- WebSocket permitiría bidireccional (futuras notificaciones)
- Implementación: OkHttp 3.x websocket o Scarlet

### Caché Inteligente
- Last-read timestamps para sync incremental
- Offline-first arquitectura (guardar localmente primero)
- Conflict resolution para cambios simultáneos
