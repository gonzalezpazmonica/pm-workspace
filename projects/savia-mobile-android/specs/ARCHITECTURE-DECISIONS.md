# Savia Mobile — Architecture Decision Records

## ADR-001: Clean Architecture con 4 módulos Gradle

**Contexto**: Necesitamos una arquitectura que separe responsabilidades y facilite el testing.

**Decisión**: 4 módulos Gradle independientes:
- `:app` — Application, MainActivity, Hilt entry point
- `:domain` — Modelos, interfaces de repositorio, use cases (Kotlin puro, sin dependencias Android)
- `:data` — Implementaciones de repositorio, API client, SSH client, Room
- `:presentation` — Compose screens, ViewModels, Navigation

**Consecuencia**: El módulo `:domain` es portable a KMP sin cambios si necesitamos iOS en el futuro.

---

## ADR-002: Retrofit + OkHttp para Claude API (no Ktor)

**Contexto**: No existe SDK oficial de Anthropic para Kotlin.

**Opciones evaluadas**:
1. Ktor — multiplataforma pero menos ecosistema Android
2. Retrofit + OkHttp — estándar de la industria Android
3. anthropic-sdk-kotlin — comunitario, riesgo de abandono

**Decisión**: Retrofit 2.11.0 + OkHttp 4.12.0

**Razón**: Máxima documentación, comunidad, interceptors maduros, SSE streaming nativo con OkHttp EventSource. 95% de apps Android profesionales usan este stack.

**Trade-off**: Si migramos a KMP, habrá que wrappear con expect/actual o migrar a Ktor.

---

## ADR-003: Tink en lugar de EncryptedSharedPreferences

**Contexto**: EncryptedSharedPreferences está deprecado desde security-crypto 1.1.0-alpha07.

**Decisión**: Google Tink 1.10.0 para toda la criptografía:
- AEAD (AES-256-GCM) para cifrar API keys y SSH keys
- KeysetHandle almacenado en Android Keystore
- Tink StreamingAead para archivos grandes si necesario

**Razón**: Tink es la biblioteca criptográfica de Google usada en Google Pay, Firebase, AdMob. Mantenimiento garantizado a largo plazo.

---

## ADR-004: Apache MINA SSHD (no JSch)

**Contexto**: JSch original abandonado (Nov 2025).

**Decisión**: Apache MINA SSHD 1.18.0

**Razón**: 100% Java puro (funciona en Android sin NDK), mantenimiento activo (última release Enero 2026), arquitectura extensible, soporte Ed25519.

**Fallback**: Si MINA da problemas en Android (tamaño APK o conflictos), migrar al fork mwiede/jsch que es compatible API.

---

## ADR-005: Room + SQLCipher para datos offline

**Contexto**: Necesitamos cache offline cifrada para conversaciones y snapshots.

**Decisión**: Room 2.7.0 con SQLCipher 4.6.0 para cifrado transparente de BD.

**Razón**: Room es el estándar de persistencia Android con soporte de migraciones, LiveData/Flow, y testing. SQLCipher añade cifrado AES-256 sin cambiar el código de Room.

---

## ADR-006: Single Activity + Navigation Compose

**Contexto**: Patrón de navegación para la app.

**Decisión**: Una sola Activity con NavHostController de Jetpack Navigation Compose.

**Rutas**:
```
chat                      → Conversación activa
chat/{conversationId}     → Conversación específica
dashboard                 → Dashboard de métricas
settings                  → Configuración
settings/connections      → Gestión de conexiones
settings/connections/{id} → Detalle de conexión
onboarding               → Primer uso
```

**Razón**: Patrón recomendado por Google para Compose. Menos overhead que múltiples Activities, deep links nativos, animaciones de transición.

---

## ADR-007: StateFlow para estado reactivo (no LiveData)

**Contexto**: Mecanismo de estado reactivo para ViewModels.

**Decisión**: Kotlin StateFlow + SharedFlow

**Razón**: StateFlow es null-safe, lifecycle-aware con collectAsStateWithLifecycle(), y más idiomático en Kotlin que LiveData. Mejor integración con Coroutines.

```kotlin
class ChatViewModel : ViewModel() {
    private val _uiState = MutableStateFlow(ChatUiState())
    val uiState: StateFlow<ChatUiState> = _uiState.asStateFlow()
}
```

---

## ADR-008: Modo híbrido API-first con SSH fallback

**Contexto**: Dos formas de conectar: Claude API directo o SSH al pm-workspace.

**Decisión**: API-first, SSH como enriquecimiento.

**Flujo**:
1. Siempre usar Claude API para chat (rápido, fiable)
2. Si SSH configurado y alcanzable → enriquecer respuestas con datos reales del workspace
3. Si SSH no disponible → Claude responde basándose en contexto del system prompt
4. Dashboard: intenta SSH para datos reales, fallback a estimaciones vía API

**Razón**: API siempre funciona (solo necesita internet). SSH es bonus para usuarios avanzados.

---

## ADR-009: Kotlin Serialization (no Gson)

**Contexto**: Necesitamos serialización JSON para API responses y Room type converters.

**Decisión**: Kotlin Serialization 1.6.0

**Razón**: Type-safe en compile-time, rendimiento superior a Gson, no necesita reflection (mejor para ProGuard/R8), soporte nativo de sealed classes y data classes.

---

## ADR-010: Bilingual ES/EN desde día 1

**Contexto**: Target market es hispano y anglo.

**Decisión**: Todas las strings en `res/values/strings.xml` (EN) y `res/values-es/strings.xml` (ES).

**Reglas**:
- 0 strings hardcodeadas en Kotlin
- ES como idioma primario de Savia
- Detección automática del locale del dispositivo
- Override manual en Settings
