# Savia Mobile — Asistente de PM con IA en Android

> **Savia en tu bolsillo.** Accede a tu workspace de pm-workspace desde cualquier lugar, conectado o sin conexión.

## Visión

Savia Mobile extiende el poder del asistente de pm-workspace de IA a dispositivos Android, proporcionando una interfaz intuitiva y optimizada para mobile que permite a los directores de proyectos, tech leads y ejecutivos permanecer conectados en movimiento — sin requerir SSH, Termux, VPN, o conocimientos técnicos profundos.

## Características Principales

- **Chat inteligente:** Acceso a Savia (Claude) especializado en gestión de proyectos
- **Consultas rápidas:** Estado del sprint, descomposición de PBI, scoring de riesgos
- **Dashboard offline:** Acceso a datos cacheados cuando no hay conexión
- **Sincronización:** Contexto compartido con pm-workspace en tu computadora
- **Bilingual:** Interfaz en español e inglés
- **Privacidad:** Datos almacenados localmente, cifrados con SQLCipher
- **Flexible:** Conecta vía Claude API directo o túnel SSH a tu servidor

## Requisitos Previos

### Para Desarrolladores
- **Android Studio** 2024.1.1 LTS o posterior
- **JDK 17** (incluido en Android Studio)
- **Gradle 8.13.2** (especificado en el proyecto)
- **Android SDK:** API 35 (compileSdk), API 26+ (minSdk)
- **Kotlin 2.1.0**

### Para Usuarios
- **Dispositivo Android:** 8.0 (API 26) o superior
- **Conexión de red:** Para acceso a Claude API o SSH tunnel
- **Clave de API Anthropic:** (opcional, si usas conexión directa a Claude)
- **Servidor Savia Bridge:** (opcional, para acceso via SSH tunnel)

## Guía Rápida de Inicio

### 1. Clonar el Repositorio

```bash
git clone https://github.com/tu-usuario/savia-mobile-android.git
cd savia-mobile-android
```

### 2. Abrir en Android Studio

```bash
# Linux/Mac
open -a Android\ Studio .

# Windows
start "" %ANDROID_SDK_HOME%\tools\studio64.exe .
```

### 3. Compilar Debug APK

```bash
./gradlew assembleDebug
```

El APK aparecerá en: `app/build/outputs/apk/debug/app-debug.apk`

Instalar en emulador o dispositivo físico:

```bash
./gradlew installDebug
```

### 4. Ejecutar Tests

```bash
# Tests unitarios
./gradlew testDebugUnitTest

# Tests de integración (con emulador)
./gradlew connectedAndroidTest

# Cobertura de código
./gradlew jacocoTestReport
```

Ver reporte: `app/build/reports/jacoco/jacocoTestReport/html/index.html`

## Arquitectura

```
app/                          # Módulo principal de la app
├─ ui/                        # Jetpack Compose screens + ViewModels
│  ├─ screens/               # ChatScreen, DashboardScreen, etc.
│  ├─ components/            # Composables reutilizables
│  └─ theme/                 # Material 3 theming
├─ domain/                   # Casos de uso (sin dependencias Android)
│  ├─ usecase/              # Business logic
│  ├─ model/                # Entities
│  └─ repository/           # Abstracciones
├─ data/                     # Implementaciones de repositorios
│  ├─ local/                # Room DAO, DataStore
│  ├─ remote/               # Retrofit, OkHttp
│  └─ di/                   # Hilt modules
├─ MainActivity.kt           # Entry point
└─ SaviaApp.kt             # Hilt application

domain/                       # Módulo independiente (portable)
└─ [models, interfaces]

data/                        # Módulo de datos (transportable)
└─ [repositories, local storage]
```

## Stack Tecnológico

### UI & Navigation
- **Jetpack Compose** 2024.12.01 (BOM)
- **Material 3** 1.3.1
- **Navigation Compose** 2.8.5
- **Activity Compose** 1.9.3

### Networking
- **Retrofit** 2.11.0
- **OkHttp** 4.12.0 + Logging Interceptor
- **Kotlin Serialization** 1.7.3
- **Server-Sent Events:** savia-bridge.py

### Storage & Database
- **Room** 2.7.0 (Kotlin Symbol Processor 2.1.0-1.0.29)
- **DataStore Preferences** 1.1.1
- **SQLCipher** 4.6.1 (cifrado de BD)

### Security
- **Tink** 1.10.0 (criptografía Google)
- **Android Keystore** (hardware-backed)
- **BiometricPrompt** (lock opcional)

### DI & State Management
- **Hilt** 2.56.2
- **StateFlow** (reactive state)
- **ViewModel** 2.8.7

### Concurrency
- **Kotlin Coroutines** 1.9.0

### Markdown Rendering
- **Markwon** 4.6.2 (rendering de respuestas markdown)

### Testing
- **JUnit 4** 4.13.2 + **JUnit Ext** 1.2.1
- **Mockk** 1.13.13 (mocking)
- **Turbine** 1.2.0 (StateFlow testing)
- **Truth** 1.4.4 (assertions)
- **Robolectric** 4.14.1 (unit testing)
- **Compose UI Test** (tests de UI)
- **MockWebServer** 4.12.0 (mock HTTP)

**Para versiones completas:** Ver `gradle/libs.versions.toml`

## Configuración de Desarrollo

### 1. Variables de Entorno (Opcional)

```bash
# ~/.bashrc o ~/.zshrc
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools
```

### 2. Archivo local.properties

Android Studio auto-genera este archivo. Verificar:

```
sdk.dir=/Users/tu-usuario/Library/Android/Sdk
```

### 3. API Key de Anthropic (en Settings de la app)

La app solicita la clave API al primer inicio. Puede obtenerse de: https://console.anthropic.com/

## Flujo de Desarrollo

### Branch Naming

```
feature/#123-description        # Nuevas características
fix/#456-description           # Fixes de bugs
refactor/module-name           # Refactorización
docs/section-name              # Documentación
```

### Commit Message Format

```
[#123] Short description

Optional longer explanation of why this change was made.
```

### Code Review Checklist

- [ ] Lint & formato pasan (`./gradlew lintDebug`)
- [ ] Tests unitarios pasan (`./gradlew testDebugUnitTest`)
- [ ] Cobertura >= 80% en nuevas clases
- [ ] No hardcoded secrets
- [ ] Documentación actualizada

### Before Pushing

```bash
# Lint + análisis estático
./gradlew lintDebug detekt

# Tests completos
./gradlew testDebugUnitTest

# Build release (simula CI)
./gradlew assembleRelease
```

## CI/CD Pipeline

Configurado en `.github/workflows/`

| Evento | Pipeline | Acciones |
|--------|----------|----------|
| **Pull Request** | `android-ci.yml` | Lint, tests, security scan, build debug |
| **Merge a main** | `release.yml` | Build AAB, deploy internal track |
| **Tag v1.0.0** | `release.yml` | Build AAB, deploy production staged |
| **Nightly** | `nightly.yml` | Tests instrumented, baseline profiles, size check |

**Secretos requeridos en GitHub:**
- `KEYSTORE_BASE64` — Keystore de firma (base64)
- `KEYSTORE_PASSWORD` — Password del keystore
- `KEY_ALIAS` — Alias de la clave
- `KEY_PASSWORD` — Password de la clave
- `PLAY_SERVICE_ACCOUNT` — Service account JSON de Google Play

Ver `specs/CI-CD-PIPELINES.md` para detalles.

## Servidor Bridge (Savia Bridge)

El servidor Python que actúa de puente entre la app y Claude Code CLI:

```bash
# Instalar (una sola vez)
pip3 install --user savia-bridge

# Ejecutar
python3 savia-bridge.py --port 8922 --host 0.0.0.0

# Ver token de autenticación
python3 savia-bridge.py --print-token

# Ver fingerprint del certificado TLS
python3 savia-bridge.py --print-fingerprint
```

**Ubicación:** `/home/monica/savia/scripts/savia-bridge.py`

**Configuración en la app:**
- Protocol: HTTPS
- Host: 192.168.x.x (tu IP local o VPN)
- Port: 8922
- Token: (copiar de salida del servidor)
- Certificate Fingerprint: (verificación de identidad)

## Deployment

### Google Play Store

1. **Crear release (versión production):**

```bash
./gradlew bundleRelease
```

2. **Firma manual (si no usas GitHub Actions):**

```bash
jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 \
  -keystore release.keystore \
  app/build/outputs/bundle/release/app-release.aab \
  savia-key
```

3. **Google Play Console:**
   - Upload AAB en `Releases` → `Production`
   - Set 10% users (staged rollout)
   - Monitorear 48h antes de expandir

### APK Manual (Debug o Release)

```bash
# Debug
./gradlew installDebug

# Release (requiere keystore)
./gradlew assembleRelease
adb install -r app/build/outputs/apk/release/app-release.apk
```

## Documentación Adicional

### Guías (`docs/`)

- **[Arquitectura](docs/ARCHITECTURE.md)** — Clean Architecture, módulos, flujo de datos, DI
- **[Guía de Setup](docs/SETUP.md)** — Instalación, build, ejecución, configuración del bridge
- **[Guía del Bridge](docs/BRIDGE-GUIDE.md)** — Cómo funciona Savia Bridge, endpoints, troubleshooting

### Especificaciones (`specs/`)

- **[Producto](specs/PRODUCT-SPEC.md)** — Características, usuarios objetivo, criterios de aceptación
- **[Diseño Técnico](specs/TECHNICAL-DESIGN.md)** — Arquitectura, modelo de datos, SSE, seguridad
- **[Backlog](specs/BACKLOG.md)** — PBIs completados y pendientes
- **[Decisiones](specs/ARCHITECTURE-DECISIONS.md)** — ADRs: Tink, SSE, dual-backend, tema violeta
- **[Stack](specs/STACK-ANALYSIS.md)** — Análisis del stack tecnológico
- **[CI/CD](specs/CI-CD-PIPELINES.md)** — Pipelines de integración continua
- **[Mercado](specs/MARKET-ANALYSIS.md)** — Análisis de mercado y posicionamiento

### Referencias

- **[API Reference](API_REFERENCE.md)** — Endpoints del Bridge
- **[Implementation Summary](IMPLEMENTATION_SUMMARY.md)** — Resumen de implementación
- **[Bridge Migration](BRIDGE_MIGRATION.md)** — Guía de migración al bridge
- **[Changelog](CHANGELOG.md)** — Historial de cambios
- **[PM-Workspace README](../../README.md)** — Proyecto principal

## Troubleshooting

### Build failing: `Could not resolve all dependencies`

```bash
./gradlew clean --refresh-dependencies
./gradlew build
```

### Tests failing with Android API issues

```bash
# Usar Robolectric para simular Android APIs
./gradlew testDebugUnitTest --info
```

### APK signing failure

Verificar que el keystore existe y passwords son correctas:

```bash
keytool -list -v -keystore release.keystore
```

### Emulator not detected

```bash
# Listar emuladores
emulator -list-avds

# Iniciar uno específico
emulator -avd Pixel_API_34 &

# O usar dispositivo físico con USB debug
adb devices
```

## Comunidad & Contribución

- **GitHub Issues:** Reportar bugs, solicitar features
- **Discussions:** Preguntas de desarrollo
- **Pull Requests:** Contribuciones bienvenidas (ver CONTRIBUTING.md)
- **Discord:** Comunidad de users y developers

## Licencia

- **Código de app:** MIT License
- **Bridge (Python):** Apache 2.0
- **Documentación:** CC BY-SA 4.0

## Versión Actual

- **App Version:** 0.1.0-debug (MVP en desarrollo)
- **API Mínima:** Android 8.0 (API 26)
- **Target API:** Android 15 (API 35)

## Roadmap

- **v0.1.0:** MVP — Chat + dashboard básico
- **v0.2.0:** Offline sync, templates rápidas
- **v0.3.0:** Integración Jira/Azure DevOps nativa
- **v0.4.0:** Widgets, notificaciones inteligentes
- **v1.0.0:** Beta pública, Google Play oficial
- **v1.1.0+:** iOS via Flutter (considerar)

---

**Mantener actualizado:** Este README refleja el estado del proyecto a marzo 2026. Feedback es bienvenido.
