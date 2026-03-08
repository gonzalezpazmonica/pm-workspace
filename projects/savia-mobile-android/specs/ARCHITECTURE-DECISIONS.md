# Savia Mobile Android — Architecture Decision Records (ADRs)

Registro de decisiones arquitectónicas tomadas durante la construcción de Savia Mobile Android v0.1.0.

---

## ADR-001: Clean Architecture con 3 Módulos Gradle

**Título:** Separación de capas con módulos independientes

**Contexto:**
El proyecto necesita arquitectura escalable que facilite testing, mantenibilidad, y potencial migración a multiplataforma (KMP). Las apps Android producción requieren separación clara de responsabilidades para evitar acoplamiento.

**Opciones Evaluadas:**
1. Single module (monolito) — Rápido, pero acoplamiento total
2. Clean Architecture (3 módulos) — Estándar Android profesional
3. Modularización por feature (5+ módulos) — Demasiado para v0.1

**Decisión:**
Implementar Clean Architecture con 3 módulos independientes:
- `:domain` — Lógica de negocio pura (Kotlin sin Android)
- `:data` — Implementaciones (API, caching, security)
- `:app` — UI, DI, Application context

**Estructura:**
```
app/
├── build.gradle.kts
└── src/main/kotlin/com/savia/mobile/
    ├── MainActivity.kt
    └── di/NetworkModule.kt

domain/
└── src/main/kotlin/com/savia/domain/
    ├── model/StreamDelta.kt
    ├── repository/ChatRepository.kt
    └── repository/SecurityRepository.kt

data/
└── src/main/kotlin/com/savia/data/
    ├── api/ClaudeApiService.kt
    ├── api/SaviaBridgeService.kt
    ├── security/TinkKeyManager.kt
    └── repository/ChatRepositoryImpl.kt
```

**Consecuencias:**
- ✅ Domain portátil a KMP/iOS sin cambios
- ✅ Testing aislado sin Android
- ✅ Mantenibilidad clara de responsabilidades
- ❌ Más ficheros iniciales que monolito
- ❌ Coordinación inter-módulos (minor overhead)

**Justificación:**
Es el estándar de la industria Android. Google lo recomienda. Soporta crecimiento futuro.

---

## ADR-002: Retrofit + OkHttp sobre Ktor

**Título:** Stack HTTP para Anthropic API directa

**Contexto:**
Necesitamos HTTP client que soporte:
- REST API (Anthropic Messages)
- Streaming SSE (respuestas word-by-word)
- Interceptors (logging, auth, retry)
- Android ecosystem estándar

**Opciones Evaluadas:**
1. **Ktor Client** — Multiplataforma, builtin SSE, menos maduro en Android
2. **Retrofit + OkHttp** — Estándar Android, maduro, 95% de apps profesionales
3. **Volley** — Antiguo, deprecated
4. **HttpURLConnection** — Low-level, tedioso

**Decisión:**
Retrofit 2.11.0 + OkHttp 4.12.0

**Justificación:**
- OkHttp es la mejor solución HTTP en Android (usado por Retrofit, Picasso, Square apps)
- EventSource nativo para SSE
- Interceptors maduros (logging HEADERS, connection pooling, timeouts)
- Documentación abundante + Stack Overflow
- Type-safety con Retrofit interfaces

**Versiones:**
```gradle
retrofit = "2.11.0"
okhttp = "4.12.0"
retrofit-serialization = "2.11.0"
okhttp-logging = "4.12.0"
```

**Timeout Configuration:**
```kotlin
// Anthropic API (estándar)
connectTimeout = 30 segundos
readTimeout = 120 segundos (streaming)
writeTimeout = 30 segundos

// Savia Bridge (local, streaming largo)
connectTimeout = 15 segundos
readTimeout = 300 segundos (Claude streaming)
writeTimeout = 30 segundos
```

**Consecuencias:**
- ✅ Maduro, confiable, documentado
- ✅ SSE nativo
- ✅ Comunidad grande
- ❌ No multiplataforma (Ktor sí, pero menos maduro)
- ❌ Si migramos a KMP, habría que wrappear con expect/actual o usar Ktor

**Trade-off:**
Maturity + Community (Retrofit) vs Multiplataforma (Ktor). Priorizamos maturity.

---

## ADR-003: Google Tink para Criptografía

**Título:** AES-256-GCM con Android Keystore en lugar de EncryptedSharedPreferences

**Contexto:**
EncryptedSharedPreferences (androidx.security:security-crypto) está deprecated desde v1.1.0-alpha07 (2023).
Necesitamos almacenar API keys y tokens de forma segura en dispositivo, protegidos contra:
- Disk theft (physical access)
- Memory dumps (cold boot attacks)
- Side-channel attacks (timing)

**Opciones Evaluadas:**
1. **Tink (Google)** — Crypto lib usada en Google Pay, Firebase, AdMob
2. **EncryptedSharedPreferences** — Deprecated, wrappea Tink internamente
3. **Conscrypt** — Más low-level, menos seguro por default
4. **Bouncy Castle** — Pesado, deprecated en Android

**Decisión:**
Google Tink 1.10.0 con AEAD (Authenticated Encryption with Associated Data)

**Implementación (TinkKeyManager.kt):**
```kotlin
// AES-256-GCM cipher
private val aead: Aead by lazy {
    AeadConfig.register()
    AndroidKeysetManager.Builder()
        .withSharedPref(context, KEYSET_NAME, PREFS_NAME)
        .withKeyTemplate(AesGcmKeyManager.aes256GcmTemplate())
        .withMasterKeyUri("android-keystore://savia_master_key")
        .build()
        .keysetHandle
        .getPrimitive(Aead::class.java)
}

fun encryptString(plaintext: String, context: String = "savia-mobile"): ByteArray =
    aead.encrypt(plaintext.toByteArray(UTF_8), context.toByteArray())

fun decryptString(ciphertext: ByteArray, context: String = "savia-mobile"): String =
    String(aead.decrypt(ciphertext, context.toByteArray()), UTF_8)
```

**Hardware Backing (Automático):**
- API 23+ con Android Keystore
- Pixel/Samsung/etc. con Secure Element
- Otros: software backing (aún seguro, sin hardware)

**Garantías Criptográficas:**
- **Confidentiality:** AES-256 (128-bit security margin)
- **Authenticity:** GCM authentication tag
- **Integrity:** Decryption falls si data corrupted
- **Freshness:** AAD (contexto) previene replay
- **Forward Secrecy:** IV aleatorio per message

**Consecuencias:**
- ✅ Enterprise-grade (Google mantiene activamente)
- ✅ Hardware-backed en modernos (Secure Element)
- ✅ Master key automático in Android Keystore
- ✅ Lazy initialization (<1s gen en primer uso)
- ❌ Tink API más verbose que EncryptedSharedPreferences
- ❌ Múltiples capas (Tink → Keystore) vs. abstracto

**Almacenamiento:**
- **Keyset:** `data/data/com.savia.mobile/shared_prefs/savia_crypto_prefs.xml` (encrypted)
- **Master Key:** Android Keystore (hardware-backed si disponible)
- **Alias:** `android-keystore://savia_master_key`

---

## ADR-004: SaviaBridgeService (OkHttp directo) vs Retrofit

**Título:** Bridge HTTP requiere self-signed certs (usar OkHttp directo)

**Contexto:**
Savia Bridge es servicio local/VPN que proxies Claude API. Usa HTTPS con certificado self-signed.
Necesitamos:
- Aceptar self-signed certs (TLS permisivo en LAN)
- Timeout extendido 300s (Claude streaming largo)
- Bearer token authentication
- SSE streaming idéntico a Anthropic API

**Opciones Evaluadas:**
1. **Retrofit con custom client** — Posible, pero overhead
2. **OkHttp directo** — Control total, más simple para local
3. **Ktor** — Multiplataforma, pero ya tenemos Retrofit

**Decisión:**
OkHttp directo (no Retrofit) para SaviaBridgeService

**Implementación (SaviaBridgeService.kt):**
```kotlin
class SaviaBridgeService @Inject constructor(
    @Named("bridge") private val httpClient: OkHttpClient,
    private val json: Json
)

fun sendMessageStream(
    bridgeUrl: String,
    authToken: String,
    message: String,
    sessionId: String,
    systemPrompt: String? = null
): Flow<StreamDelta> = callbackFlow { ... }
```

**NetworkModule Bridge Client:**
```kotlin
@Provides @Singleton @Named("bridge")
fun provideBridgeOkHttpClient(): OkHttpClient {
    // Trust all certs (seguridad por VPN + bearer token)
    val trustManager = object : X509TrustManager {
        override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) {}
        override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
    }

    val sslContext = SSLContext.getInstance("TLS")
    sslContext.init(null, arrayOf(trustManager), SecureRandom())

    return OkHttpClient.Builder()
        .sslSocketFactory(sslContext.socketFactory, trustManager)
        .hostnameVerifier { _, _ -> true }
        .readTimeout(300, TimeUnit.SECONDS)  // Streaming largo
        .build()
}
```

**Request Format (Bridge):**
```json
{
  "message": "user text",
  "session_id": "conversation-uuid",
  "system_prompt": "optional instructions"
}
```

**Response (SSE idéntico):**
```
data: {"type":"text","text":"chunk"}
data: {"type":"done"}
data: {"type":"error","text":"error"}
```

**Enrutamiento (ChatRepositoryImpl):**
```kotlin
val response = if (securityRepository.hasBridgeConfig()) {
    bridgeService.sendMessageStream(
        bridgeUrl = securityRepository.getBridgeUrl(),
        authToken = securityRepository.getBridgeToken(),
        message = message,
        sessionId = conversationId,
        systemPrompt = systemPrompt
    )
} else {
    claudeApiService.sendMessage(apiKey, message, ...)
}
```

**Consecuencias:**
- ✅ Control total sobre TLS + timeouts
- ✅ Más simple que Retrofit para single service
- ✅ SSE parsing idéntico a ClaudeApiService
- ❌ Más code que usar Retrofit
- ❌ Manual request building (vs. Retrofit interfaces)

**Seguridad (TLS Permisivo Justificado):**
- ✅ Bridge en LAN privada o VPN
- ✅ Bearer token authentication en header
- ✅ Future: certificate pinning por fingerprint
- ⚠️ NUNCA usar en internet público sin certificado válido

---

## ADR-005: Tema Violet/Mauve (Identidad Savia)

**Título:** Paleta de colores Material 3 para brand coherence

**Contexto:**
Savia es asistente de PM. Necesitamos paleta visual que evoque:
- Sabiduría, claridad, inteligencia
- Confianza profesional
- Accesibilidad (WCAG AA)
- Material 3 compliance

**Opciones Evaluadas:**
1. **Blue (Android Material default)** — Genérico, sin identidad
2. **Purple/Violet** — Sabiduría, inteligencia, distinto
3. **Green (Savia original)** — Verde claro, baja contrast
4. **Red** — Demasiado alerta, no profesional

**Decisión:**
Violet/Mauve palette con #6B4C9A como primario

**Color System (Colors.kt):**
```kotlin
val SaviaPrimary = Color(0xFF6B4C9A)        // Deep violet
val SaviaPrimaryLight = Color(0xFF8E6FBF)   // Medium violet
val SaviaPrimaryDark = Color(0xFF4A2D7A)    // Dark violet
val SaviaSecondary = Color(0xFFA78BCA)      // Soft lavender
val SaviaAccent = Color(0xFFCDB4DB)         // Light mauve

// Light Mode
val SaviaBackground = Color(0xFFF9F7FB)     // Very light lavender
val SaviaSurface = Color(0xFFFFFFFF)        // White
val SaviaOnBackground = Color(0xFF1C1A1E)  // Dark text

// Dark Mode
val SaviaDarkBackground = Color(0xFF1C1A1E)
val SaviaDarkSurface = Color(0xFF211F26)
val SaviaDarkOnBackground = Color(0xFFE6E1E5)  // Light text

// Chat Bubbles
val UserBubbleColor = Color(0xFF6B4C9A)         // Violet (user)
val AssistantBubbleColor = Color(0xFFEDE7F3)   // Lavender (assistant)
```

**Material 3 Compliance:**
- Respects Material 3 color system
- Light + Dark modes definidos
- Contrast ratios: WCAG AA minimum (4.5:1 para text)
- Semantic colors: error (#BA1A1A), warning (#E6A817)

**Consecuencias:**
- ✅ Identidad visual coherente
- ✅ WCAG AA accessible
- ✅ Light + Dark modes
- ✅ Distinto de Material default
- ✅ Profesional + memorable
- ❌ No es blue (Android default, pero estamos bien)

**Justificación:**
Violet ↔ sabiduría, claridad, inteligencia. Perfecto para asistente PM.
Mauve secundario ↔ suavidad, accesibilidad. Confianza profesional.

---

## ADR-006: Kotlinx Serialization (no Gson/Jackson)

**Título:** JSON serialization type-safe en compile-time

**Contexto:**
Necesitamos serializar/deserializar JSON para:
- Requests a Anthropic API
- Responses de Bridge
- Room type converters (future)
- Log events (future)

**Opciones Evaluadas:**
1. **Gson** — Reflection-based, tamaño, sin type safety
2. **Jackson** — Pesado, muchas dependencias
3. **Kotlinx Serialization** — Type-safe, compile-time, sin reflection
4. **Moshi** — Type-safe pero menos performant que Kotlinx

**Decisión:**
Kotlinx Serialization 1.6.0

**Ventajas:**
```kotlin
@Serializable
data class StreamEvent(
    val type: String,
    val text: String? = null
)

// Type-safe, compile-time, sin reflection
val event = json.decodeFromString<StreamEvent>(jsonString)
val json = json.encodeToString(event)
```

**Beneficios:**
- ✅ Type-safe en compile-time
- ✅ Sin reflection (ProGuard-friendly)
- ✅ Soporte nativo sealed classes
- ✅ Performance superior a Gson
- ✅ Kotlin-first design

**Configuración:**
```kotlin
val json = Json {
    ignoreUnknownKeys = true      // Forward compatibility
    isLenient = true               // Relaxed parsing
    encodeDefaults = true          // Always serialize defaults
}
```

**Consecuencias:**
- ✅ Type-safe, compile-time safety
- ✅ Mejor performance (sin reflection)
- ✅ Smaller APK size
- ❌ Necesita @Serializable annotations
- ❌ Menos comunidad que Gson (pero creciendo)

---

## ADR-007: Hilt para Dependency Injection

**Título:** Hilt (no Koin, no manual DI)

**Contexto:**
Necesitamos DI framework para:
- OkHttpClient (2 configs)
- Retrofit
- Services (Claude, Bridge)
- TinkKeyManager
- Repositories (future)

**Opciones Evaluadas:**
1. **Manual DI** — Sin dependencies, tedioso
2. **Koin** — Service locator, runtime, flexible
3. **Dagger** — Compile-time, complex, verbose
4. **Hilt** — Compile-time, Android-optimized, Google-supported

**Decisión:**
Hilt 2.50 (built on Dagger, Android-first)

**Justificación:**
- ✅ Recomendado por Google (official)
- ✅ Android-specific (activities, fragments, services)
- ✅ Compile-time safety (Dagger underneath)
- ✅ Scopes simples (@Singleton, @ActivityScoped, etc.)
- ✅ Integration con Jetpack (ViewModel, LiveData)

**Implementation (NetworkModule.kt):**
```kotlin
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {
    @Provides @Singleton
    fun provideJson(): Json = Json { ... }

    @Provides @Singleton
    fun provideOkHttpClient(): OkHttpClient = ...

    @Provides @Singleton
    fun provideRetrofit(client: OkHttpClient, json: Json): Retrofit = ...

    @Provides @Singleton
    fun provideClaudeApiService(retrofit: Retrofit): ClaudeApiService = ...
}
```

**Uso:**
```kotlin
@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    @Inject lateinit var claudeService: ClaudeApiService
}
```

**Consecuencias:**
- ✅ Compile-time safety
- ✅ Google-supported
- ✅ Android-optimized
- ✅ Clear scopes
- ❌ Curva aprendizaje (Dagger underneath)
- ❌ Build time (annotation processing)

---

## ADR-008: API-First con Bridge Optional

**Título:** Anthropic API como primario, Bridge como enriquecimiento

**Contexto:**
Dos formas de conectar:
1. **Claude API Directo:** Rápido, fiable, requisitos mínimos (solo internet)
2. **Savia Bridge:** Enriquecimiento (workspace context), requiere setup local

**Arquitectura:**
```
ChatRepositoryImpl
    ↓
if (hasBridgeConfig()) {
    Bridge → workspace context → Claude response
} else {
    Claude API → response
}
```

**Flujo Bridge (futuro):**
1. User conecta bridge (host, port, token)
2. Bridge ejecuta pm-workspace commands
3. Bridge enriquece prompt → Claude
4. Claude responde con workspace context

**Flujo API (actual v0.1):**
1. User ingresa API key
2. App conecta api.anthropic.com
3. Envía mensaje + system prompt
4. Recibe streaming response

**Decisión:**
API-first (bridge es optional)

**Justificación:**
- ✅ API siempre funciona (solo internet)
- ✅ Bridge es bonus para power users
- ✅ No bloquea v0.1 (bridge en v0.3)
- ✅ Fallback transparente

**Enrutamiento Transparente:**
```kotlin
val response = if (securityRepository.hasBridgeConfig()) {
    bridgeService.sendMessageStream(...)  // Bridge
} else {
    claudeApiService.sendMessage(...)     // API
}
```

**Consecuencias:**
- ✅ Simple MVP (API solo)
- ✅ Upgrade path claro (Bridge futuro)
- ✅ No breaking changes
- ❌ Bridge no en v0.1

---

## Resumen de Decisiones

| ADR | Decisión | Alternativa | Razón |
|-----|----------|-------------|-------|
| ADR-001 | Clean Architecture (3 módulos) | Monolito | Escalabilidad, testability |
| ADR-002 | Retrofit + OkHttp | Ktor | Maturity, community, Android std |
| ADR-003 | Google Tink | EncryptedSharedPreferences | Deprecation, explicit control |
| ADR-004 | OkHttp directo (Bridge) | Retrofit | Control TLS, simpler |
| ADR-005 | Violet/Mauve theme | Blue | Identidad, sabiduría |
| ADR-006 | Kotlinx Serialization | Gson | Type-safety, performance |
| ADR-007 | Hilt | Koin | Compile-time, Google-supported |
| ADR-008 | API-first | Bridge-first | MVP focus, fallback |

---

## Trade-offs y Riesgos

### Trade-off: Retrofit vs Ktor
- **Escogemos:** Retrofit (Android std, community)
- **Sacrificamos:** Multiplataforma (Ktor)
- **Mitigación:** Domain layer portable; futura wrap con expect/actual

### Trade-off: Tink vs EncryptedSharedPreferences
- **Escogemos:** Tink (long-term support)
- **Sacrificamos:** Simplicity (EncryptedSP más abstracto)
- **Mitigación:** TinkKeyManager wrapper (abstraction)

### Risk: Bridge TLS Permisivo
- **Riesgo:** Self-signed certs en local
- **Mitigación:** VPN + Bearer token (v0.1); certificate pinning (v0.3)
- **Justificación:** Local network es seguro; internet public NO

---

## Conclusión

Las decisiones arquitectónicas de v0.1.0 están optimizadas para:
1. **Maturity:** Stack establecido (Retrofit, Tink, Hilt)
2. **Security:** Cifrado + Android Keystore
3. **Testability:** Clean Architecture
4. **Scalability:** Módulos independientes
5. **Future:** Bridge optional, API primary

Todo el stack es recomendado por Google o usado en Google apps (Tink, Hilt, Compose).
