# Savia Mobile — Technical Design Document (v2)

> Actualizado tras investigación de stack tecnológico — Marzo 2026

## 1. Module Structure

```
savia-mobile/
├── app/                              # Application module (Hilt entry)
│   ├── src/main/kotlin/com/savia/mobile/
│   │   ├── SaviaApp.kt              # @HiltAndroidApp
│   │   ├── MainActivity.kt          # Single Activity
│   │   └── di/                       # Hilt modules
│   ├── src/main/res/
│   │   ├── values/strings.xml        # English
│   │   └── values-es/strings.xml     # Spanish
│   └── src/main/assets/
│       └── savia-identity.md         # System prompt
├── domain/                           # Pure Kotlin (sin deps Android)
│   ├── model/                        # Conversation, Message, Snapshot, Profile
│   ├── repository/                   # Interfaces
│   └── usecase/                      # SendMessage, GetHealth, ExecuteRemote
├── data/                             # Implementaciones
│   ├── api/                          # Retrofit + OkHttp SSE streaming
│   ├── ssh/                          # Apache MINA SSHD
│   ├── local/                        # Room + SQLCipher
│   ├── security/                     # Tink AEAD + BiometricPrompt
│   └── repository/                   # Impl con modo híbrido API+SSH
├── presentation/                     # Jetpack Compose
│   ├── chat/                         # ChatScreen, ViewModel, MessageBubble
│   ├── dashboard/                    # DashboardScreen, RadarChart, QuickAction
│   ├── settings/                     # Settings, ConnectionSetup
│   ├── onboarding/                   # OnboardingFlow
│   ├── widget/                       # Glance widget
│   ├── navigation/                   # NavHost
│   └── theme/                        # Material 3 + Savia colors
└── build.gradle.kts
```

## 2. Key Dependencies

```toml
# gradle/libs.versions.toml
[versions]
kotlin = "2.1.0"
compose-bom = "2024.06.00"
hilt = "2.51"
retrofit = "2.11.0"
okhttp = "4.12.0"
room = "2.7.0"
datastore = "1.1.1"
tink = "1.10.0"
sqlcipher = "4.6.0"
mina-sshd = "1.18.0"
markwon = "4.6.2"
kotlinx-serialization = "1.6.0"
```

Nota: EncryptedSharedPreferences DEPRECADO → sustituido por Tink.
JSch ABANDONADO → sustituido por Apache MINA SSHD.

## 3. Claude API Streaming (Retrofit + OkHttp SSE)

```kotlin
interface ClaudeApiService {
    @POST("v1/messages")
    @Streaming
    suspend fun createMessageStream(
        @Header("x-api-key") apiKey: String,
        @Header("anthropic-version") version: String = "2023-06-01",
        @Body request: CreateMessageRequest
    ): ResponseBody
}

// SSE parser emite Flow<StreamDelta>
class ClaudeStreamParser {
    fun parse(body: ResponseBody): Flow<StreamDelta> = callbackFlow {
        body.source().use { source ->
            while (!source.exhausted()) {
                val line = source.readUtf8Line() ?: continue
                if (line.startsWith("data: ")) {
                    val json = line.removePrefix("data: ")
                    when {
                        "content_block_delta" in json -> {
                            val delta = Json.decodeFromString<ContentDelta>(json)
                            trySend(StreamDelta.Text(delta.delta.text))
                        }
                        "message_stop" in json -> {
                            trySend(StreamDelta.Done); close()
                        }
                    }
                }
            }
        }
        awaitClose()
    }
}
```

## 4. SSH with Apache MINA SSHD

```kotlin
class SshConnectionManager @Inject constructor(
    private val keyManager: TinkKeyManager
) {
    private var session: ClientSession? = null

    suspend fun connect(profile: ConnectionProfile): Result<Unit> =
        withContext(Dispatchers.IO) {
            runCatching {
                val client = SshClient.setUpDefaultClient().apply { start() }
                val s = client.connect(profile.username, profile.host, profile.port)
                    .verify(10_000).session
                s.addPublicKeyIdentity(keyManager.decryptSshKey(profile.encryptedKeyId))
                s.auth().verify(10_000)
                session = s
            }
        }

    suspend fun execute(command: String): Flow<String> = callbackFlow {
        val ch = session?.createExecChannel(command) ?: error("Not connected")
        ch.open().verify(5_000)
        ch.invertedOut.bufferedReader().useLines { it.forEach { l -> trySend(l) } }
        ch.close(); close()
    }
}
```

## 5. Security (Tink + Android Keystore)

```kotlin
class TinkKeyManager @Inject constructor(@ApplicationContext private val ctx: Context) {
    private val aead: Aead by lazy {
        AeadConfig.register()
        AndroidKeysetManager.Builder()
            .withSharedPref(ctx, "savia_keyset", "savia_prefs")
            .withKeyTemplate(AesGcmKeyManager.aes256GcmTemplate())
            .withMasterKeyUri("android-keystore://savia_master")
            .build().keysetHandle.getPrimitive(Aead::class.java)
    }
    fun encrypt(data: ByteArray): ByteArray = aead.encrypt(data, AD)
    fun decrypt(data: ByteArray): ByteArray = aead.decrypt(data, AD)
    companion object { private val AD = "savia-mobile".toByteArray() }
}
```

## 6. Room + SQLCipher

```kotlin
@Database(entities = [ConversationEntity::class, MessageEntity::class,
    WorkspaceSnapshotEntity::class, ConnectionProfileEntity::class], version = 1)
abstract class SaviaDatabase : RoomDatabase() {
    abstract fun conversationDao(): ConversationDao
    abstract fun snapshotDao(): SnapshotDao
    abstract fun connectionDao(): ConnectionDao
}

// Builder con cifrado
fun buildDb(ctx: Context, passphrase: ByteArray): SaviaDatabase =
    Room.databaseBuilder(ctx, SaviaDatabase::class.java, "savia.db")
        .openHelperFactory(SupportFactory(passphrase))
        .build()
```

## 7. Navigation (Single Activity)

```kotlin
sealed class Screen(val route: String) {
    object Chat : Screen("chat")
    object Dashboard : Screen("dashboard")
    object Settings : Screen("settings")
    object Onboarding : Screen("onboarding")
}

@Composable
fun SaviaNavHost(navController: NavHostController) {
    NavHost(navController, startDestination = Screen.Chat.route) {
        composable(Screen.Chat.route) { ChatScreen() }
        composable("chat/{id}") { ChatScreen(it.arguments?.getString("id")) }
        composable(Screen.Dashboard.route) { DashboardScreen() }
        composable(Screen.Settings.route) { SettingsScreen() }
        composable(Screen.Onboarding.route) { OnboardingFlow() }
    }
}
```

## 8. Hybrid Connection Strategy

```
Prioridad de conexión:
1. Si SSH configurado + host alcanzable → SSH (datos reales del workspace)
2. Si SSH falla o no configurado → Claude API (IA responde con contexto del system prompt)
3. Si sin internet → cache offline de Room
```

El HybridWorkspaceRepository implementa esta lógica:

```kotlin
class HybridWorkspaceRepository @Inject constructor(
    private val apiRepo: ApiWorkspaceRepository,
    private val sshRepo: SshWorkspaceRepository,
    private val cacheRepo: CacheRepository,
    private val connectivity: ConnectivityObserver
) : WorkspaceRepository {

    override suspend fun getHealth(): WorkspaceHealth =
        when {
            sshRepo.isConnected() -> sshRepo.getHealth().also { cacheRepo.save(it) }
            connectivity.isOnline() -> apiRepo.getHealth().also { cacheRepo.save(it) }
            else -> cacheRepo.getHealth() ?: WorkspaceHealth.UNAVAILABLE
        }
}
```
