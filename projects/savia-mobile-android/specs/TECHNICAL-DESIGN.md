# Savia Mobile — Technical Design Document

## 1. Module Structure

```
savia-mobile/
├── app/                          # Application module
│   ├── src/main/
│   │   ├── kotlin/com/savia/mobile/
│   │   │   ├── SaviaApp.kt      # Application class
│   │   │   ├── MainActivity.kt  # Single activity
│   │   │   └── di/              # Hilt modules
│   │   └── res/
│   │       ├── values/strings.xml
│   │       └── values-es/strings.xml
│   └── build.gradle.kts
├── domain/                       # Business logic (pure Kotlin)
│   ├── model/                    # Domain models
│   ├── repository/               # Repository interfaces
│   └── usecase/                  # Use cases
├── data/                         # Data layer
│   ├── api/                      # Anthropic API client
│   ├── ssh/                      # SSH connection manager
│   ├── local/                    # Room database
│   └── repository/               # Repository implementations
├── presentation/                 # UI layer
│   ├── chat/                     # Chat screen
│   ├── dashboard/                # Dashboard screen
│   ├── settings/                 # Settings screen
│   ├── onboarding/               # Onboarding flow
│   └── theme/                    # Material You theme
└── build.gradle.kts              # Root build
```

## 2. Key Dependencies

```kotlin
// build.gradle.kts (app)
dependencies {
    // Core
    implementation("androidx.core:core-ktx:1.13.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.0")

    // Compose
    implementation(platform("androidx.compose:compose-bom:2024.06.00"))
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.navigation:navigation-compose:2.8.0")

    // DI
    implementation("com.google.dagger:hilt-android:2.51")
    kapt("com.google.dagger:hilt-compiler:2.51")

    // Network
    implementation("io.ktor:ktor-client-okhttp:2.3.12")
    implementation("io.ktor:ktor-client-content-negotiation:2.3.12")
    implementation("io.ktor:ktor-serialization-kotlinx-json:2.3.12")

    // SSH
    implementation("com.jcraft:jsch:0.1.55")

    // Persistence
    implementation("androidx.room:room-runtime:2.6.1")
    implementation("androidx.room:room-ktx:2.6.1")
    kapt("androidx.room:room-compiler:2.6.1")
    implementation("androidx.datastore:datastore-preferences:1.1.1")
    implementation("androidx.security:security-crypto:1.1.0-alpha06")

    // Markdown
    implementation("io.noties.markwon:core:4.6.2")
    implementation("io.noties.markwon:syntax-highlight:4.6.2")

    // Testing
    testImplementation("junit:junit:4.13.2")
    testImplementation("io.mockk:mockk:1.13.12")
    testImplementation("app.cash.turbine:turbine:1.1.0")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.1")
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
}
```

## 3. Claude API Integration

### System Prompt Construction

```kotlin
class SaviaSystemPromptBuilder @Inject constructor(
    private val identityLoader: IdentityLoader,
    private val workspaceRepo: WorkspaceRepository
) {
    suspend fun build(locale: Locale): String {
        val identity = identityLoader.load()
        val workspace = workspaceRepo.getLatestSnapshot()

        return buildString {
            appendLine("You are Savia, an AI Project Management assistant.")
            appendLine("Identity: ${identity.summary}")
            appendLine("Values: ${identity.values}")
            appendLine("Language: respond in ${locale.displayLanguage}")
            if (workspace != null) {
                appendLine("Current workspace health: ${workspace.healthScore}%")
                appendLine("Skills: ${workspace.skillCount}, Commands: ${workspace.commandCount}")
            }
            appendLine("Be concise for mobile. Use short paragraphs.")
            appendLine("Format: markdown-friendly, avoid wide tables.")
        }
    }
}
```

### Streaming Client

```kotlin
class ClaudeApiClient @Inject constructor(
    private val httpClient: HttpClient,
    private val keyStore: ApiKeyStore
) {
    fun streamMessage(
        messages: List<Message>,
        systemPrompt: String
    ): Flow<StreamEvent> = callbackFlow {
        val request = MessagesRequest(
            model = "claude-sonnet-4-6",
            maxTokens = 2048,
            system = systemPrompt,
            messages = messages.map { it.toApiMessage() },
            stream = true
        )

        httpClient.preparePost("https://api.anthropic.com/v1/messages") {
            header("x-api-key", keyStore.getKey())
            header("anthropic-version", "2023-06-01")
            contentType(ContentType.Application.Json)
            setBody(request)
        }.execute { response ->
            response.bodyAsChannel().readSSE { event ->
                when (event.type) {
                    "content_block_delta" -> trySend(StreamEvent.Text(event.data))
                    "message_stop" -> trySend(StreamEvent.Done)
                    "error" -> trySend(StreamEvent.Error(event.data))
                }
            }
        }
        awaitClose()
    }
}
```

## 4. SSH Tunnel Architecture

```kotlin
class SshConnectionManager @Inject constructor(
    private val configStore: ConnectionConfigStore
) {
    private var session: Session? = null

    suspend fun connect(profile: ConnectionProfile): Result<Unit> =
        withContext(Dispatchers.IO) {
            runCatching {
                val jsch = JSch()
                jsch.addIdentity(profile.privateKeyPath)

                session = jsch.getSession(
                    profile.username,
                    profile.host,
                    profile.port
                ).apply {
                    setConfig("StrictHostKeyChecking", "ask")
                    connect(10_000) // 10s timeout
                }
            }
        }

    suspend fun execute(command: String): Flow<String> = callbackFlow {
        val channel = session?.openChannel("exec") as? ChannelExec
            ?: throw IllegalStateException("Not connected")

        channel.setCommand("cd \$SAVIA_ROOT && $command")
        channel.connect()

        channel.inputStream.bufferedReader().useLines { lines ->
            lines.forEach { trySend(it) }
        }

        channel.disconnect()
        close()
    }
}
```

## 5. Room Database Schema

```kotlin
@Database(
    entities = [
        ConversationEntity::class,
        MessageEntity::class,
        WorkspaceSnapshotEntity::class,
        ConnectionProfileEntity::class
    ],
    version = 1,
    exportSchema = true
)
@TypeConverters(Converters::class)
abstract class SaviaDatabase : RoomDatabase() {
    abstract fun conversationDao(): ConversationDao
    abstract fun snapshotDao(): SnapshotDao
    abstract fun connectionDao(): ConnectionDao
}
```

## 6. Navigation Graph

```kotlin
@Composable
fun SaviaNavHost(navController: NavHostController) {
    NavHost(navController, startDestination = "chat") {
        composable("chat") { ChatScreen() }
        composable("chat/{conversationId}") { ChatScreen(it.arguments) }
        composable("dashboard") { DashboardScreen() }
        composable("settings") { SettingsScreen() }
        composable("onboarding") { OnboardingFlow() }
        composable("connection/{profileId}") { ConnectionSetupScreen(it.arguments) }
    }
}
```

## 7. CI/CD Pipeline

```yaml
# .github/workflows/android-ci.yml
name: Android CI
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { java-version: '17', distribution: 'temurin' }
      - run: ./gradlew lintDebug
      - run: ./gradlew testDebug
      - run: ./gradlew assembleRelease
      - uses: actions/upload-artifact@v4
        with: { name: apk, path: app/build/outputs/apk/release/*.apk }
```
