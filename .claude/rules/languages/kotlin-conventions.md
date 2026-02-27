---
paths:
  - "**/*.kt"
  - "**/*.kts"
  - "**/build.gradle.kts"
---

# Regla: Convenciones y Prácticas Kotlin/Android
# ── Aplica a todos los proyectos Kotlin en este workspace ──────────────────────

## Verificación obligatoria en cada tarea

Antes de dar una tarea por terminada, ejecutar siempre en este orden:

```bash
./gradlew build --dry-run                      # 1. ¿Compila sin warnings?
./gradlew ktlint                               # 2. ¿Respeta el formato (ktlint)?
./gradlew detekt                               # 3. ¿Pasa análisis estático (detekt)?
./gradlew test                                 # 4. ¿Pasan los tests unitarios?
```

Si hay tests de integración o de UI relevantes:
```bash
./gradlew connectedAndroidTest                 # tests en dispositivo/emulador
```

## Convenciones de código Kotlin

- **Naming:** `PascalCase` para clases, interfaces, enums; `camelCase` para propiedades, funciones; `UPPER_SNAKE_CASE` para constantes
- **Null safety:** Maximizar uso de non-null types; `?.` para optional chaining; `!!` solo en casos seguros (Hilt, UI bindings)
- **Data classes y value objects:** Usar `data class` para DTOs, Entities con `copy()` para inmutabilidad
- **Extension functions:** Agrupar en archivos `{Entity}Extensions.kt`; evitar sobrecarga innecesaria
- **Infix functions:** Usar para readability en DSLs; ej: `infix fun Int.times(other: Int)`
- **Scope functions:** `apply`, `also`, `let`, `run` con propósito claro; nunca anidar más de un nivel
- **Collections:** Usar operaciones funcionales (map, filter, fold) sobre loops explícitos; Sequences para colecciones grandes
- **Sealed classes:** Para jerarquías cerradas de tipos; muy útil con `when` exhaustivo
- **By delegation:** `by lazy`, `by Delegates`, `by SomeClass()`

## Arquitectura MVVM + Jetpack Compose + Kotlin Flow

```
├── feature/
│   └── {feature}/
│       ├── presentation/
│       │   ├── screens/
│       │   │   └── {Feature}Screen.kt        ← composables
│       │   ├── viewmodels/
│       │   │   └── {Feature}ViewModel.kt     ← gestión de estado
│       │   └── components/
│       │       └── {Component}.kt             ← composables reutilizables
│       ├── domain/
│       │   ├── models/
│       │   │   └── {Entity}.kt
│       │   ├── repository/
│       │   │   └── {Repository}Interface.kt
│       │   └── usecase/
│       │       └── {UseCase}.kt
│       └── data/
│           ├── repository/
│           │   └── {Repository}Impl.kt
│           ├── datasource/
│           │   ├── local/
│           │   │   └── {Entity}LocalDataSource.kt (Room)
│           │   └── remote/
│           │       └── {Entity}RemoteDataSource.kt (Retrofit)
│           └── models/
│               └── {Entity}Dto.kt
├── di/                                       ← Hilt modules
│   ├── AppModule.kt
│   └── {Feature}Module.kt
└── MainActivity.kt
```

## Jetpack Compose

- **Composables:** Funciones puras, sin estado si es posible; nombres `PascalCase` para `@Composable`
- **Hoisting de estado:** Mover estado lo más arriba posible para composability
- **Modifiers:** Orden estándar: tamaño → padding → background → otros
- **Preview:** `@Preview` para todos los composables; parámetros tipados
- **LazyLists:** `LazyColumn`, `LazyRow` para listas eficientes; nunca `Column(modifier = Modifier.verticalScroll())`

```kotlin
@Composable
fun UserListScreen(
    viewModel: UserViewModel = hiltViewModel(),
    modifier: Modifier = Modifier
) {
    val users by viewModel.users.collectAsState()
    
    LazyColumn(modifier = modifier) {
        items(users) { user ->
            UserCard(user = user)
        }
    }
}

@Preview
@Composable
fun UserListScreenPreview() {
    UserListScreen()
}
```

## Kotlin Flow (Reactive)

- **StateFlow:** Para estado mutable observable (reemplaza LiveData)
- **Flow:** Para streams de eventos/datos (cold stream)
- **LiveData:** SOLO en casos legacy; preferir `StateFlow` con `asLiveData()` si necesario
- **Collectors:** En ViewModel usar `viewModelScope.launch { flow.collect { } }`
- **SharedFlow:** Para broadcast de eventos; `MutableSharedFlow` en casos avanzados

```kotlin
class UserViewModel : ViewModel() {
    private val _users = MutableStateFlow<List<User>>(emptyList())
    val users: StateFlow<List<User>> = _users.asStateFlow()
    
    init {
        viewModelScope.launch {
            repository.getUsers()
                .onStart { /* loading = true */ }
                .catch { /* handleError */ }
                .collect { _users.value = it }
        }
    }
}
```

## Hilt Dependency Injection

```kotlin
// En módulo (reemplaza dagger-hilt module)
@Module
@InstallIn(SingletonComponent::class)
object AppModule {
    @Provides
    @Singleton
    fun provideUserRepository(
        localDataSource: UserLocalDataSource,
        remoteDataSource: UserRemoteDataSource
    ): UserRepository = UserRepositoryImpl(localDataSource, remoteDataSource)
}

// En clase
@HiltViewModel
class UserViewModel @Inject constructor(
    private val repository: UserRepository
) : ViewModel() { }

// En Activity/Fragment
@AndroidEntryPoint
class MainActivity : AppCompatActivity() { }
```

## Room (Persistencia local)

```kotlin
@Entity(tableName = "users", indices = [Index(value = ["email"], unique = true)])
@Serializable
data class UserEntity(
    @PrimaryKey val id: String,
    val name: String,
    val email: String
)

@Dao
interface UserDao {
    @Query("SELECT * FROM users WHERE id = :id")
    suspend fun getUserById(id: String): UserEntity?
    
    @Upsert
    suspend fun upsertUser(user: UserEntity)
    
    @Query("SELECT * FROM users ORDER BY name")
    fun getAllUsers(): Flow<List<UserEntity>>
}

@Database(entities = [UserEntity::class], version = 1)
abstract class AppDatabase : RoomDatabase() {
    abstract fun userDao(): UserDao
}
```

## Retrofit (API Remote)

```kotlin
data class UserDto(
    @SerializedName("user_id") val id: String,
    val name: String,
    val email: String
)

interface UserApiService {
    @GET("/users/{id}")
    suspend fun getUser(@Path("id") id: String): UserDto
    
    @GET("/users")
    suspend fun getUsers(): List<UserDto>
    
    @POST("/users")
    suspend fun createUser(@Body user: UserDto): UserDto
}
```

## Tests

- **Unit tests:** JUnit 5 + Mockk + AssertJ
- **Android tests:** Espresso (UI) o Robolectric (unitarios rápidos)
- **Naming:** `test_[componente]_[escenario]_[esperado]`
- Usar `TestDispatchers` para corrutinas en tests
- Mockk preferido para mocking de Kotlin

```bash
./gradlew test                                 # unitarios (JVM)
./gradlew connectedAndroidTest                 # en dispositivo
./gradlew testDebugUnitTest                    # unitarios con Robolectric
```

## Formato y Linting

```bash
./gradlew ktlint                               # análisis de formato
./gradlew ktlintFormat                         # auto-format
./gradlew detekt                               # análisis estático detallado
```

Configurar en `build.gradle.kts`:
```kotlin
plugins {
    id("org.jlleitschuh.gradle.ktlint") version "11.0.0"
    id("io.gitlab.arturbosch.detekt") version "1.22.0"
}

detekt {
    config = files("detekt.yml")
}
```

## Gestión de dependencias (Gradle)

```bash
./gradlew dependencies                         # árbol de dependencias
./gradlew dependencyUpdates                    # updates disponibles
./gradlew bundleRelease                        # build en modo release
```

Versiones base recomendadas:
- Kotlin 1.9+
- Gradle 8.0+
- Compose 1.5+
- Jetpack Compose compiler 1.5.0

## Build y Deploy

```bash
./gradlew clean build                          # build completo
./gradlew bundleRelease                        # Android App Bundle
./gradlew installDebug                         # instalar en emulador
adb logcat                                     # ver logs
```

## Hooks recomendados para proyectos Kotlin/Android

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "run": "cd $(git rev-parse --show-toplevel) && ./gradlew ktlint 2>&1 | head -10"
    }],
    "PreToolUse": [{
      "matcher": "Bash(git commit*)",
      "run": "./gradlew test --quiet 2>&1 | tail -20"
    }]
  }
}
```
