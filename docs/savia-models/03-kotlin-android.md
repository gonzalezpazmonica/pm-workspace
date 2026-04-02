# Savia Model 03 — Kotlin + Jetpack Compose Android

> Stack: Kotlin 2.x + Jetpack Compose + Hilt + Room + Coroutines
> Architecture: Single-activity, multi-module, offline-first
> Team Scale: Small (2-5) to Growth (6-20)
> Exemplar: savia-mobile

---

## 1. Philosophy and Culture

### Offline-first is not optional

The network is a suggestion, not a guarantee. Room is the single source of
truth. The UI layer never observes the network directly — it subscribes to
a `StateFlow` emitted by the local database. Background sync updates Room;
Compose reacts. This eliminates an entire class of race conditions, loading
states, and data inconsistency bugs.

### Unidirectional data flow

State flows in one direction: Intent -> ViewModel -> State -> Composable.
Events travel upward via lambdas. Side effects travel via sealed interfaces
and `Channel`. There is exactly one path data takes through the system,
which makes every screen debuggable by inspecting a single `data class`.

### Composition over inheritance

Compose already enforces this at the UI layer. We extend it to the domain:
UseCases compose other UseCases. Repositories compose data sources. There are
no `BaseActivity`, no `BaseFragment`, no `BaseViewModel` with 14 abstract
methods. The only base class permitted is a thin MVI ViewModel contract.

### Modularize by feature, not by layer

A `:feature:auth` module contains its screens, ViewModels, UseCases, and
repository interfaces. It does not depend on `:feature:profile`. Both depend
on `:core:domain` for shared entities and `:core:data` for repository
implementations. This enforces encapsulation at the Gradle level — not by
convention, but by compilation.

### Why Kotlin and not KMP (yet)

This model targets native Android. Kotlin Multiplatform is viable for shared
domain logic, but adds complexity that small teams do not need on day one.
The architecture is KMP-ready: domain and data layers are pure Kotlin with
no Android imports. Migration is a build configuration change, not a rewrite.

---

## 2. Architecture Principles

### Clean Architecture — Three Layers

```
┌─────────────────────────────────────┐
│            UI Layer                 │  Compose screens, ViewModels
│  (depends on Domain)               │  MVI state machines
├─────────────────────────────────────┤
│          Domain Layer              │  UseCases, entities, repository interfaces
│  (depends on nothing)              │  Pure Kotlin, no Android imports
├─────────────────────────────────────┤
│           Data Layer               │  Repository implementations, Room DAOs
│  (depends on Domain)              │  Retrofit services, DataStore, mappers
└─────────────────────────────────────┘
```

**Dependency rule**: outer layers depend on inner layers. Domain depends on
nothing. Data implements Domain interfaces. UI consumes Domain UseCases.

### MVI for complex screens, MVVM for simple ones

Not every screen needs a full intent-reducer loop. A settings screen with
three toggles uses a simple `ViewModel` with `MutableStateFlow`. A checkout
flow with payment validation, address lookup, and error recovery uses MVI
with explicit `Intent`, `State`, and `Effect` types. The threshold: if the
screen has more than 3 distinct user actions that modify state, use MVI.

### Compose Navigation with type-safe routes

Navigation uses the official `navigation-compose` library with type-safe
route definitions via `@Serializable` data classes (Compose Navigation 2.8+).
No string-based routes. No argument parsing. Deep links map to the same
route data classes.

```kotlin
@Serializable
data class TaskDetail(val taskId: String)

@Serializable
data object TaskList

// In NavHost
composable<TaskDetail> { backStackEntry ->
    val route = backStackEntry.toRoute<TaskDetail>()
    TaskDetailScreen(taskId = route.taskId)
}
```

### Module dependency rules

```
:app             → :feature:*, :core:*
:feature:auth    → :core:domain, :core:ui, :core:data
:feature:tasks   → :core:domain, :core:ui, :core:data
:core:domain     → (nothing — pure Kotlin)
:core:data       → :core:domain, :core:network, :core:database
:core:ui         → :core:domain (shared Compose components)
:core:network    → :core:domain (Retrofit, interceptors)
:core:database   → :core:domain (Room, DAOs)
:core:testing    → (test utilities, fakes, shared fixtures)
:build-logic     → (convention plugins, no runtime dependency)
```

**Forbidden**: `:feature:X` depending on `:feature:Y`. Features communicate
through `:core:domain` shared contracts or navigation events.

---

## 3. Project Structure

```
project-root/
├── app/                          # Application module — wiring only
│   └── src/main/
│       ├── AndroidManifest.xml
│       └── kotlin/.../
│           ├── App.kt            # @HiltAndroidApp Application
│           ├── MainActivity.kt   # Single activity, setContent {}
│           └── navigation/
│               └── AppNavGraph.kt
├── feature/
│   ├── auth/
│   │   └── src/main/kotlin/.../
│   │       ├── ui/               # Compose screens + ViewModels
│   │       ├── domain/           # Feature-specific UseCases
│   │       └── navigation/       # Feature nav graph
│   └── tasks/
│       └── ...
├── core/
│   ├── domain/                   # Entities, repository interfaces, UseCases base
│   ├── data/                     # Repository implementations, DI modules
│   ├── database/                 # Room DB, DAOs, entities, migrations
│   ├── network/                  # Retrofit, interceptors, DTOs
│   ├── ui/                       # Design system: theme, shared composables
│   └── testing/                  # Fakes, test rules, Turbine helpers
├── build-logic/
│   └── convention/               # Convention plugins (Gradle)
│       └── src/main/kotlin/
│           ├── AndroidApplicationPlugin.kt
│           ├── AndroidLibraryPlugin.kt
│           ├── AndroidComposePlugin.kt
│           └── AndroidHiltPlugin.kt
├── gradle/
│   └── libs.versions.toml        # Version catalog — single source of truth
├── build.gradle.kts              # Root build file
└── settings.gradle.kts           # Module declarations
```

### Version catalog (`libs.versions.toml`)

```toml
[versions]
kotlin = "2.1.0"
agp = "8.8.0"
compose-bom = "2026.03.00"
hilt = "2.56"
room = "2.7.0"
ksp = "2.1.0-1.0.29"
coroutines = "1.10.1"
navigation = "2.8.5"
roborazzi = "1.34.0"
turbine = "1.2.1"
mockk = "1.13.14"

[libraries]
compose-bom = { group = "androidx.compose", name = "compose-bom", version.ref = "compose-bom" }
hilt-android = { group = "com.google.dagger", name = "hilt-android", version.ref = "hilt" }
hilt-compiler = { group = "com.google.dagger", name = "hilt-compiler", version.ref = "hilt" }
room-runtime = { group = "androidx.room", name = "room-runtime", version.ref = "room" }
room-ktx = { group = "androidx.room", name = "room-ktx", version.ref = "room" }
room-compiler = { group = "androidx.room", name = "room-compiler", version.ref = "room" }
turbine = { group = "app.cash.turbine", name = "turbine", version.ref = "turbine" }
mockk = { group = "io.mockk", name = "mockk", version.ref = "mockk" }

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
kotlin-android = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
kotlin-compose = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
ksp = { id = "com.google.devtools.ksp", version.ref = "ksp" }
hilt = { id = "com.google.dagger.hilt.android", version.ref = "hilt" }
roborazzi = { id = "io.github.takahirom.roborazzi", version.ref = "roborazzi" }
```

---

## 4. Code Patterns

### UseCase base class

```kotlin
// :core:domain
abstract class UseCase<in P, R> {
    suspend operator fun invoke(params: P): Result<R> {
        return try {
            Result.success(execute(params))
        } catch (e: CancellationException) {
            throw e // never swallow cancellation
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    protected abstract suspend fun execute(params: P): R
}

abstract class FlowUseCase<in P, R> {
    operator fun invoke(params: P): Flow<R> = execute(params)
    protected abstract fun execute(params: P): Flow<R>
}
```

### MVI ViewModel with Channel for effects

```kotlin
// :core:ui
abstract class MviViewModel<S : Any, I : Any, E : Any>(
    initialState: S,
) : ViewModel() {

    private val _state = MutableStateFlow(initialState)
    val state: StateFlow<S> = _state.asStateFlow()

    private val _effects = Channel<E>(Channel.BUFFERED)
    val effects: Flow<E> = _effects.receiveAsFlow()

    fun dispatch(intent: I) {
        viewModelScope.launch { handleIntent(intent) }
    }

    protected abstract suspend fun handleIntent(intent: I)

    protected fun setState(reducer: S.() -> S) {
        _state.update { it.reducer() }
    }

    protected suspend fun sendEffect(effect: E) {
        _effects.send(effect)
    }
}
```

### Concrete MVI screen — Tasks

```kotlin
// State, Intent, Effect — all sealed/data classes
@Immutable
data class TaskListState(
    val tasks: List<TaskUi> = emptyList(),
    val isLoading: Boolean = true,
    val filter: TaskFilter = TaskFilter.ALL,
)

sealed interface TaskListIntent {
    data object LoadTasks : TaskListIntent
    data class ToggleComplete(val taskId: String) : TaskListIntent
    data class FilterChanged(val filter: TaskFilter) : TaskListIntent
    data class DeleteTask(val taskId: String) : TaskListIntent
}

sealed interface TaskListEffect {
    data class ShowSnackbar(val message: String) : TaskListEffect
    data class NavigateToDetail(val taskId: String) : TaskListEffect
}

// ViewModel
@HiltViewModel
class TaskListViewModel @Inject constructor(
    private val observeTasks: ObserveTasksUseCase,
    private val toggleTask: ToggleTaskCompleteUseCase,
    private val deleteTask: DeleteTaskUseCase,
) : MviViewModel<TaskListState, TaskListIntent, TaskListEffect>(
    initialState = TaskListState()
) {

    init { dispatch(TaskListIntent.LoadTasks) }

    override suspend fun handleIntent(intent: TaskListIntent) {
        when (intent) {
            is TaskListIntent.LoadTasks -> {
                observeTasks(state.value.filter)
                    .onEach { tasks -> setState { copy(tasks = tasks, isLoading = false) } }
                    .launchIn(viewModelScope)
            }
            is TaskListIntent.ToggleComplete -> {
                toggleTask(intent.taskId)
                    .onFailure { sendEffect(TaskListEffect.ShowSnackbar("Failed to update task")) }
            }
            is TaskListIntent.FilterChanged -> {
                setState { copy(filter = intent.filter, isLoading = true) }
                dispatch(TaskListIntent.LoadTasks)
            }
            is TaskListIntent.DeleteTask -> {
                deleteTask(intent.taskId)
                    .onSuccess { sendEffect(TaskListEffect.ShowSnackbar("Task deleted")) }
                    .onFailure { sendEffect(TaskListEffect.ShowSnackbar("Delete failed")) }
            }
        }
    }
}
```

### Screen/Content split pattern

```kotlin
@Composable
fun TaskListScreen(
    viewModel: TaskListViewModel = hiltViewModel(),
    onNavigateToDetail: (String) -> Unit,
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    // Effects — collect in LaunchedEffect with lifecycle awareness
    LaunchedEffect(Unit) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is TaskListEffect.NavigateToDetail -> onNavigateToDetail(effect.taskId)
                is TaskListEffect.ShowSnackbar -> { /* snackbar host */ }
            }
        }
    }

    TaskListContent(
        state = state,
        onToggleComplete = { viewModel.dispatch(TaskListIntent.ToggleComplete(it)) },
        onFilterChanged = { viewModel.dispatch(TaskListIntent.FilterChanged(it)) },
        onDelete = { viewModel.dispatch(TaskListIntent.DeleteTask(it)) },
    )
}

// Content is a pure function — preview-friendly, screenshot-testable
@Composable
fun TaskListContent(
    state: TaskListState,
    onToggleComplete: (String) -> Unit,
    onFilterChanged: (TaskFilter) -> Unit,
    onDelete: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    LazyColumn(modifier = modifier) {
        items(
            items = state.tasks,
            key = { it.id }, // stable keys for performance
        ) { task ->
            TaskItem(
                task = task,
                onToggle = { onToggleComplete(task.id) },
                onDelete = { onDelete(task.id) },
            )
        }
    }
}
```

### Offline-first Repository (cache-then-network)

```kotlin
class TaskRepositoryImpl @Inject constructor(
    private val taskDao: TaskDao,
    private val taskApi: TaskApi,
    private val dispatchers: CoroutineDispatchers,
) : TaskRepository {

    override fun observeTasks(filter: TaskFilter): Flow<List<Task>> {
        return taskDao.observeByFilter(filter.toDbFilter())
            .map { entities -> entities.map { it.toDomain() } }
            .flowOn(dispatchers.io)
            .onStart { refreshFromNetwork() }
    }

    private suspend fun refreshFromNetwork() {
        try {
            val remote = taskApi.getTasks()
            taskDao.upsertAll(remote.map { it.toEntity() })
        } catch (_: IOException) {
            // Offline — Room data is still flowing. No crash.
        }
    }

    override suspend fun toggleComplete(taskId: String): Result<Unit> {
        return runCatching {
            taskDao.toggleComplete(taskId)
            // Optimistic UI — sync later
            withContext(dispatchers.io) { taskApi.toggleComplete(taskId) }
        }
    }
}
```

### Compose performance essentials

```kotlin
// derivedStateOf — avoid recomposition when only derived value matters
val showEmptyState by remember {
    derivedStateOf { state.tasks.isEmpty() && !state.isLoading }
}

// Stable keys in LazyColumn — never use index as key
items(items = tasks, key = { it.id }) { task -> ... }

// @Immutable on state classes — tells Compose the class is deeply immutable
@Immutable
data class TaskListState(...)

// Avoid lambda allocation in loops
val onToggleCallback = remember<(String) -> Unit> { { id -> dispatch(ToggleComplete(id)) } }
```

---

## 5. Testing and Quality

### Test pyramid

```
           ┌──────────┐
           │  E2E (5%) │  Maestro/UI Automator — critical paths only
          ┌┴──────────┴┐
          │ Screenshot  │  Roborazzi — visual regression on every PR
         ┌┴────────────┴┐
         │  Integration  │  Room + Fakes — repository layer
        ┌┴──────────────┴┐
        │    Unit Tests    │  JUnit5 + MockK + Turbine — ViewModel, UseCase
        └──────────────────┘
```

### Tools

| Layer | Tool | Purpose |
|-------|------|---------|
| Unit | JUnit5 + MockK | Fast, expressive, coroutine-aware |
| Flow | Turbine 1.2+ | Deterministic Flow assertions |
| Screenshot | Roborazzi 1.34+ | JVM-based visual regression (no emulator) |
| E2E | Maestro | Declarative YAML flows |
| Coverage | Kover | Kotlin-native coverage reporting |

### Coverage targets

| Layer | Target | Rationale |
|-------|--------|-----------|
| UseCases | >= 95% | Pure logic, no excuse for gaps |
| ViewModels | >= 90% | State transitions are critical |
| Repositories | >= 85% | Integration with Room/Retrofit |
| Composables (screenshot) | >= 80% of screens | Visual regressions caught before merge |
| Mappers/DTOs | >= 90% | Data integrity |

### ViewModel test with Turbine

```kotlin
@OptIn(ExperimentalCoroutinesApi::class)
class TaskListViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private val observeTasks = mockk<ObserveTasksUseCase>()
    private val toggleTask = mockk<ToggleTaskCompleteUseCase>()
    private val deleteTask = mockk<DeleteTaskUseCase>()

    private lateinit var viewModel: TaskListViewModel

    @Test
    fun `loading tasks updates state with task list`() = runTest {
        val fakeTasks = listOf(TaskUi("1", "Buy milk", false))
        every { observeTasks(any()) } returns flowOf(fakeTasks)

        viewModel = createViewModel()

        viewModel.state.test {
            val initial = awaitItem()
            assertTrue(initial.isLoading)

            val loaded = awaitItem()
            assertEquals(fakeTasks, loaded.tasks)
            assertFalse(loaded.isLoading)

            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `delete failure emits snackbar effect`() = runTest {
        every { observeTasks(any()) } returns flowOf(emptyList())
        coEvery { deleteTask(any()) } returns Result.failure(IOException("Network error"))

        viewModel = createViewModel()

        viewModel.effects.test {
            viewModel.dispatch(TaskListIntent.DeleteTask("1"))
            val effect = awaitItem()
            assertIs<TaskListEffect.ShowSnackbar>(effect)
            assertTrue(effect.message.contains("failed", ignoreCase = true))
        }
    }

    private fun createViewModel() = TaskListViewModel(observeTasks, toggleTask, deleteTask)
}
```

### Roborazzi screenshot test

```kotlin
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34])
class TaskListScreenshotTest {

    @get:Rule
    val roborazziRule = RoborazziRule(
        captureRoot = onRoot(),
        options = RoborazziRule.Options(
            captureType = RoborazziRule.CaptureType.LastImage(),
        ),
    )

    @Test
    fun taskListWithItems() {
        composeTestRule.setContent {
            AppTheme {
                TaskListContent(
                    state = TaskListState(
                        tasks = listOf(
                            TaskUi("1", "Design review", false),
                            TaskUi("2", "Write tests", true),
                        ),
                        isLoading = false,
                    ),
                    onToggleComplete = {},
                    onFilterChanged = {},
                    onDelete = {},
                )
            }
        }
        onRoot().captureRoboImage()
    }

    @Test
    fun taskListEmpty() {
        composeTestRule.setContent {
            AppTheme {
                TaskListContent(
                    state = TaskListState(tasks = emptyList(), isLoading = false),
                    onToggleComplete = {},
                    onFilterChanged = {},
                    onDelete = {},
                )
            }
        }
        onRoot().captureRoboImage()
    }
}
```

---

## 6. Security and Data Sovereignty

### OWASP Mobile Top 10 (2024) — Android Mitigations

| # | Risk | Mitigation |
|---|------|-----------|
| M1 | Improper Credential Usage | Never store tokens in plain SharedPreferences. Use `EncryptedSharedPreferences` with AES-256-SIV. Tokens in memory only during session |
| M2 | Inadequate Supply Chain Security | Dependabot + `gradle/verification-metadata.xml` for dependency checksum verification. Pin all dependency versions in `libs.versions.toml` |
| M3 | Insecure Authentication/Authorization | BiometricPrompt for sensitive operations. OAuth 2.0 PKCE flow with AppAuth. No custom crypto |
| M4 | Insufficient Input/Output Validation | Validate all API responses with kotlinx.serialization strict mode. Sanitize user input before Room queries |
| M5 | Insecure Communication | TLS 1.3 enforced via `network_security_config.xml`. Certificate pinning on all API endpoints. No cleartext traffic |
| M6 | Inadequate Privacy Controls | Minimize PII collection. Room encryption with SQLCipher for sensitive tables. Data retention policies in code |
| M7 | Insufficient Binary Protections | R8 full mode with aggressive obfuscation. Integrity checks at startup. No debuggable release builds |
| M8 | Security Misconfiguration | `android:exported=false` on all internal components. `android:allowBackup="false"`. StrictMode in debug |
| M9 | Insecure Data Storage | `EncryptedFile` for documents. No sensitive data in logs. ProGuard rules to strip log calls in release |
| M10 | Insufficient Cryptography | Use AndroidKeyStore for key generation. AES-256-GCM for encryption. No MD5, no SHA1 for security purposes |

### EncryptedSharedPreferences

```kotlin
@Module
@InstallIn(SingletonComponent::class)
object SecurityModule {

    @Provides
    @Singleton
    fun provideEncryptedPrefs(@ApplicationContext context: Context): SharedPreferences {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()

        return EncryptedSharedPreferences.create(
            context,
            "secure_prefs",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }
}
```

### Certificate pinning (`network_security_config.xml`)

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>
    <domain-config>
        <domain includeSubdomains="true">api.example.com</domain>
        <pin-set expiration="2027-01-01">
            <pin digest="SHA-256">AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=</pin>
            <pin digest="SHA-256">BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=</pin>
        </pin-set>
    </domain-config>
</network-security-config>
```

### R8 full mode

```kotlin
// build.gradle.kts (app module)
android {
    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}
```

### Savia Shield integration

Data sovereignty applies to Android: Savia Shield classifies N4 data locally
before any cloud API call. On mobile, this translates to: never log PII,
never send client project data to analytics, encrypt all local databases
containing business data.

---

## 7. DevOps and Operations

### Convention plugins (`build-logic/`)

Convention plugins eliminate duplicated Gradle configuration across modules.
Each module applies one plugin instead of repeating 40 lines of setup.

```kotlin
// build-logic/convention/src/main/kotlin/AndroidLibraryPlugin.kt
class AndroidLibraryPlugin : Plugin<Project> {
    override fun apply(target: Project) {
        with(target) {
            pluginManager.apply("com.android.library")
            pluginManager.apply("org.jetbrains.kotlin.android")

            extensions.configure<LibraryExtension> {
                compileSdk = 35
                defaultConfig.minSdk = 26
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }
    }
}
```

### Gradle build cache and configuration cache

```properties
# gradle.properties
org.gradle.caching=true
org.gradle.configuration-cache=true
org.gradle.parallel=true
org.gradle.daemon=true
org.gradle.jvmargs=-Xmx4g -XX:+UseG1GC
kotlin.incremental=true
```

### CI pipeline (GitHub Actions)

```yaml
name: Android CI
on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: 17 }
      - uses: gradle/actions/setup-gradle@v4
        with: { cache-read-only: ${{ github.ref != 'refs/heads/main' }} }

      - name: Lint + Compile
        run: ./gradlew lintDebug compileDebugKotlin

      - name: Unit Tests
        run: ./gradlew testDebugUnitTest

      - name: Screenshot Tests (Roborazzi verify)
        run: ./gradlew verifyRoborazziDebug

      - name: Coverage Report
        run: ./gradlew koverXmlReportDebug

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with: { files: "**/kover/xml/*.xml" }
```

### Staged rollout with crash-free rate gates

| Stage | Rollout % | Duration | Gate |
|-------|-----------|----------|------|
| Internal | 100% testers | 24h | All smoke tests pass |
| Alpha | 1% users | 48h | Crash-free rate >= 99.5% |
| Beta | 10% users | 72h | Crash-free rate >= 99.8%, no P0 bugs |
| Production | 25% -> 50% -> 100% | 7 days | ANR rate < 0.5%, crash-free >= 99.9% |

Halt rollout immediately if crash-free rate drops below 99.5% at any stage.

---

## 8. Anti-Patterns and Guardrails

### 15 DOs

| # | DO | Rationale |
|---|----|-----------| 
| 1 | Use `collectAsStateWithLifecycle()` | Stops collection when app is in background, preventing wasted work and crashes |
| 2 | Use KSP for all annotation processors | KAPT is in maintenance mode. KSP builds 2x faster with native Kotlin support |
| 3 | Use `Channel` for one-shot effects | `SharedFlow` replays to new subscribers; `Channel` delivers once, matching effect semantics |
| 4 | Split Screen/Content composables | Screen handles ViewModel; Content is a pure function. Enables previews and screenshot tests |
| 5 | Use `@Immutable` on state data classes | Tells Compose compiler the class is deeply stable, skipping unnecessary recompositions |
| 6 | Use version catalog (`libs.versions.toml`) | Single source of truth for all dependency versions across modules |
| 7 | Use convention plugins in `build-logic/` | Eliminate duplicated Gradle config. One plugin per archetype |
| 8 | Use `flowOn(Dispatchers.IO)` in repositories | Keep the main thread free. Never call blocking I/O on `Dispatchers.Main` |
| 9 | Use `Result<T>` for UseCase return types | Explicit success/failure. No thrown exceptions crossing layer boundaries |
| 10 | Use `key = { it.id }` in LazyColumn items | Stable keys prevent unnecessary recomposition and enable item animations |
| 11 | Use Room as the single source of truth | UI observes Room flows. Network syncs to Room. Eliminates stale data bugs |
| 12 | Use Turbine for Flow testing | Deterministic, timeout-safe, explicitly tests emissions rather than time-based collection |
| 13 | Use `coVerify` over `verify` for suspend functions | MockK requires coroutine-aware verification for suspend functions |
| 14 | Use Gradle configuration cache | Reduces configuration time to near-zero on incremental builds |
| 15 | Use `@Serializable` routes for navigation | Type-safe navigation. Compile-time route validation. No string parsing |

### 15 DONTs

| # | DONT | Consequence |
|---|------|-----------| 
| 1 | Use `collectAsState()` without lifecycle | Keeps collecting in background, wasting battery and potentially crashing on disposed scope |
| 2 | Use KAPT for Hilt/Room | 2x slower builds, deprecated, breaks Kotlin 2.x features like context receivers |
| 3 | Use `SharedFlow` for navigation/snackbar effects | Late subscribers receive replayed events, causing duplicate navigations |
| 4 | Put business logic in Composables | Untestable without UI framework. Logic belongs in ViewModel or UseCase |
| 5 | Use `mutableStateOf` in ViewModel | Compose runtime dependency leaks into ViewModel layer. Use `MutableStateFlow` |
| 6 | Use index as key in LazyColumn | Item reordering causes wrong state association. Every item needs a stable ID |
| 7 | Create ViewModels manually | Hilt handles scoping and lifecycle. Manual creation breaks DI graph |
| 8 | Use `GlobalScope.launch` | Leaks coroutines past lifecycle. Always use `viewModelScope` or structured concurrency |
| 9 | Catch `CancellationException` | Breaks structured concurrency. Always rethrow it |
| 10 | Use `Thread.sleep()` in coroutines | Blocks the thread. Use `delay()` which suspends without blocking |
| 11 | Store API tokens in BuildConfig | Extractable from APK. Use EncryptedSharedPreferences or server-side token exchange |
| 12 | Skip R8/ProGuard in release builds | APK is trivially decompilable. Always minify and obfuscate release builds |
| 13 | Use `remember { mutableStateOf() }` for ViewModel state | ViewModel state must survive configuration changes. Use `StateFlow` in ViewModel |
| 14 | Use hardcoded strings in Composables | Breaks i18n, accessibility, and testability. Always use `stringResource()` |
| 15 | Use `runBlocking` in production code | Deadlocks the main thread. Use `suspend` functions and structured concurrency |

---

## 9. Agentic Integration

### Confidence matrix — what agents can do safely

| Task | Agent Confidence | Human Review | Rationale |
|------|-----------------|--------------|-----------|
| Generate data class / DTO | 95% | Optional | Pure structure, low risk |
| Implement UseCase | 90% | Recommended | Business logic needs domain validation |
| Write unit test | 90% | Optional | Tests are self-verifying |
| Create Compose screen from wireframe | 80% | Required | Visual fidelity needs human eye |
| Write Room migration | 30% | **Mandatory** | Data loss risk. Always test migration with `MigrationTestHelper` |
| Configure ProGuard rules | 40% | **Mandatory** | Wrong rules break release builds silently |
| Set up CI pipeline | 70% | Required | Infrastructure changes need ops review |
| Implement auth flow | 50% | **Mandatory** | Security-critical. Token handling, PKCE, biometrics |
| Performance optimization | 60% | Required | Requires profiling data agents cannot generate |
| Dependency version upgrade | 75% | Required | Breaking changes need integration testing |

### Workflow for agent-assisted development

```
1. Spec approved (human)
     ↓
2. /spec-slice → agent generates slice plan
     ↓
3. Agent generates UseCase + tests (confidence 90%)
     ↓
4. Agent generates ViewModel + MVI contract (confidence 85%)
     ↓
5. Agent generates Screen/Content composables (confidence 80%)
     ↓
6. Agent runs: ./gradlew testDebugUnitTest (automated gate)
     ↓
7. Agent runs: ./gradlew verifyRoborazziDebug (automated gate)
     ↓
8. Human reviews: PR with diff, screenshots, coverage delta
     ↓
9. Merge only after human approval (Rule: Code Review E1 = ALWAYS human)
```

### Layer assignment matrix for Kotlin Android

| Layer | Agent | Model | Confidence |
|-------|-------|-------|------------|
| Domain (entities, UseCases) | mobile-developer | Sonnet | High |
| Data (repositories, DAOs) | mobile-developer | Sonnet | High |
| Room migrations | mobile-developer | Opus | Low — always human review |
| UI (Compose screens) | mobile-developer | Sonnet | Medium |
| Navigation graph | mobile-developer | Sonnet | Medium |
| DI modules (Hilt) | mobile-developer | Sonnet | High |
| Build config (Gradle) | mobile-developer | Sonnet | Medium |
| Security (auth, crypto) | security-guardian | Opus | Low — always human review |
| Tests (unit + screenshot) | test-engineer | Sonnet | High |

### Quality gates for agent-generated code

1. **Compilation**: `./gradlew compileDebugKotlin` must pass
2. **Lint**: `./gradlew lintDebug` with zero errors
3. **Unit tests**: `./gradlew testDebugUnitTest` with zero failures
4. **Screenshot tests**: `./gradlew verifyRoborazziDebug` with zero regressions
5. **Coverage**: Kover report meets targets (UseCase >= 95%, ViewModel >= 90%)
6. **Human review**: PR approved by at least one human developer

No agent-generated code reaches `main` without passing all six gates.

---

## Sources

- [Google Guide to App Architecture](https://developer.android.com/topic/architecture)
- [Jetpack Compose API Guidelines](https://developer.android.com/develop/ui/compose/api-guidelines)
- [Offline-First Android App Architecture (2026)](https://www.zignuts.com/blog/android-architecture-with-jetpack-compose-and-kotlin)
- [MVI Base ViewModel for Compose (2026)](https://medium.com/@alviandf/building-a-clean-simple-mvi-base-view-model-for-jetpack-compose-android-multiplatform-fb28580de589)
- [Turbine — Flow Testing Library](https://github.com/cashapp/turbine)
- [Roborazzi — JVM Screenshot Testing](https://github.com/takahirom/roborazzi)
- [Dagger KSP Migration Guide](https://dagger.dev/dev-guide/ksp.html)
- [OWASP Mobile Top 10 2024](https://owasp.org/www-project-mobile-top-10/)
- [Testing Kotlin Flows on Android](https://developer.android.com/kotlin/flow/test)
- [Hilt with KSP Setup (2025)](https://medium.com/@mohit2656422/setup-of-hilt-with-ksp-in-an-android-project-2025-e76e42bb261a)
- [MVI Architecture with Jetpack Compose](https://dzone.com/articles/using-jetpack-compose-with-mvi-architecture)
- [Roborazzi with GitHub Actions](https://medium.com/@matiasdelbel/automating-screens-verification-with-roborazzi-and-github-actions-473b3301a5c0)
- [OWASP Mobile Mitigations Guide](https://medium.com/@izaz.haque246/the-ultimate-guide-to-owasp-mobile-top-10-2024-2025-d488c070d512)

---

*v0.1 — 2026-04-02 | Status: Draft*
