# Guía de Instalación y Configuración — Savia Mobile

## Requisitos Previos

### Sistema Operativo

- **macOS** 11+ o **Linux** (Ubuntu 18.04+) o **Windows** 10+ (WSL2)
- **RAM**: Mínimo 8GB, recomendado 16GB
- **Espacio en disco**: 50GB libre (Android SDK + Gradle cache)

### Software Obligatorio

#### 1. JDK 17

Savia Mobile requiere **Java 17 o superior**.

**Verificar versión actual:**
```bash
java -version
javac -version
```

**Instalación:**

*macOS (Homebrew):*
```bash
brew install openjdk@17
export JAVA_HOME=$(/usr/libexec/java_home -v 17)
echo 'export JAVA_HOME=$(/usr/libexec/java_home -v 17)' >> ~/.zshrc
```

*Linux (Ubuntu):*
```bash
sudo apt update
sudo apt install openjdk-17-jdk
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> ~/.bashrc
```

#### 2. Android SDK

**Opción A: Android Studio (Recomendado)**

1. Descargar desde [developer.android.com](https://developer.android.com/studio)
2. Instalar y ejecutar
3. Android Studio descargará automáticamente el SDK

**Opción B: Instalación manual**

```bash
# Descargar Command-line Tools
mkdir -p ~/Android/Sdk
cd ~/Android/Sdk
# Descargar cmdline-tools desde developer.android.com
unzip cmdline-tools*.zip
mkdir -p cmdline-tools
mv cmdline-tools/* cmdline-tools/
# Configurar variables de entorno
export ANDROID_SDK_ROOT=~/Android/Sdk
echo 'export ANDROID_SDK_ROOT=~/Android/Sdk' >> ~/.bashrc
```

**Verificar instalación:**
```bash
echo $ANDROID_SDK_ROOT
ls -la $ANDROID_SDK_ROOT/platforms/
```

#### 3. Variables de Entorno

Crear o actualizar `~/.bash_profile` (macOS) o `~/.bashrc` (Linux):

```bash
# JDK 17
export JAVA_HOME=/Library/Java/JavaVirtualMachines/openjdk-17.jdk/Contents/Home  # macOS
# o para Linux:
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# Android SDK
export ANDROID_HOME=$HOME/Android/Sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME
export PATH=$ANDROID_HOME/emulator:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools:$PATH

# Gradle (opcional, Gradle wrapper se descarga automáticamente)
export GRADLE_HOME=/path/to/gradle
export PATH=$GRADLE_HOME/bin:$PATH
```

**Aplicar cambios:**
```bash
source ~/.bashrc    # Linux
# o
source ~/.zshrc     # macOS (si usa Zsh)
```

---

## Configuración del Proyecto

### 1. Clonar el Repositorio

```bash
git clone https://github.com/tu-org/savia-mobile-android.git
cd savia-mobile-android
```

### 2. Descargar Dependencias

Las dependencias se especifican en `gradle/libs.versions.toml` y se descargan automáticamente:

```bash
# Linux/macOS
./gradlew build

# Windows
gradlew.bat build
```

Esto descargará:
- Kotlin compiler
- Jetpack Compose
- Retrofit + OkHttp
- Hilt + KSP
- Room Database (futuro)

### 3. Verificar Compilación

```bash
./gradlew app:assembleDebug
```

**Salida esperada:**
```
BUILD SUCCESSFUL in Xs
```

Si hay errores de SDK, ejecutar:
```bash
$ANDROID_HOME/tools/bin/sdkmanager "platforms;android-35" "build-tools;35.0.0"
```

---

## Conectar Savia Bridge

### ¿Qué es Savia Bridge?

Servidor Python HTTPS que envuelve Claude Code CLI. Proporciona:
- Streaming de respuestas de Claude vía SSE
- Inyección de perfil del usuario
- Autenticación con token
- Certificado TLS autofirmado

### Configurar la Conexión

#### 1. Obtener Token de Bridge

En la máquina donde corre Savia Bridge:

```bash
cat ~/.savia/bridge/auth_token
```

Copiar el token (cadena larga de caracteres).

#### 2. Obtener URL del Bridge

Si el Bridge corre en `192.168.1.100:8922`:

```bash
https://192.168.1.100:8922
```

(Requiere VPN o red local)

#### 3. En la App de Savia Mobile

1. Abrir **Ajustes** → **Conexión**
2. Seleccionar **"Servidor personalizado (Bridge)"**
3. Ingresar:
   - **URL**: `https://192.168.1.100:8922`
   - **Token**: `[pegar token aquí]`
4. Pulsar **Guardar**

#### 4. Verificar Conexión

En la app, ir a **Chat** e intentar enviar un mensaje:

- ✅ Mensaje se envía y recibe respuesta → conexión OK
- ❌ Error de conexión → verificar URL, token, VPN, firewall

---

## Ejecutar en Dispositivo o Emulador

### Opción A: Emulador Android

#### Crear AVD (Emulador Virtual)

```bash
# Abrir Android Studio → Tools → Device Manager
# O usar CLI:
$ANDROID_HOME/tools/bin/avdmanager create avd \
  -n pixel7 \
  -k "system-images;android-35;default;x86_64"
```

#### Iniciar Emulador

```bash
# Listar AVDs disponibles
$ANDROID_HOME/emulator/emulator -list-avds

# Iniciar
$ANDROID_HOME/emulator/emulator -avd pixel7 &
```

**Esperar a que aparezca la pantalla de inicio** (puede tardar 2 minutos).

#### Instalar en Emulador

```bash
./gradlew app:installDebug
```

**Salida esperada:**
```
Installed on emulator-5554 (AVD: pixel7)
```

### Opción B: Dispositivo Android Físico

#### 1. Habilitar USB Debugging

En el dispositivo:
1. **Ajustes** → **Información del dispositivo** → Tocar 7 veces **Número de compilación**
2. **Ajustes** → **Opciones de desarrollador** → Activar **Depuración USB**
3. Conectar a PC via USB

#### 2. Autorizar en PC

En el dispositivo debe aparecer un cuadro de diálogo: **¿Permitir depuración USB?** → Aceptar

#### 3. Verificar Conexión

```bash
$ANDROID_HOME/platform-tools/adb devices
```

**Salida esperada:**
```
List of attached devices
ABCDEF1234 device
```

#### 4. Instalar la App

```bash
./gradlew app:installDebug
```

---

## Ejecutar Tests

### Tests Unitarios (Domain)

```bash
./gradlew domain:test
```

Verifica lógica de negocio sin Android.

### Tests de Integración (Data)

```bash
./gradlew data:test
```

Verifica repositorios y mapeadores.

### Tests de UI (App)

En un emulador o dispositivo:

```bash
./gradlew app:connectedAndroidTest
```

---

## Construir APK para Distribución

### Debug APK (para testing)

```bash
./gradlew app:assembleDebug
```

**Localización:**
```
app/build/outputs/apk/debug/app-debug.apk
```

### Release APK (para producción)

```bash
./gradlew app:assembleRelease
```

**Localización:**
```
app/build/outputs/apk/release/app-release.apk
```

**Nota**: Requiere firma digital (keystore). Ver [Android Developer Documentation](https://developer.android.com/studio/publish/app-signing).

---

## Estructura de Directorios

```
savia-mobile-android/
├── settings.gradle.kts           ← Módulos (app, domain, data)
├── gradle/
│   └── libs.versions.toml        ← Versiones de dependencias
├── app/
│   ├── build.gradle.kts
│   ├── src/main/
│   │   ├── AndroidManifest.xml
│   │   ├── kotlin/com/savia/mobile/
│   │   │   ├── MainActivity.kt
│   │   │   ├── SaviaNavigation.kt
│   │   │   ├── di/NetworkModule.kt
│   │   │   ├── ui/screens/
│   │   │   └── viewmodel/
│   │   └── res/
│   └── build/outputs/apk/
├── domain/
│   ├── build.gradle.kts
│   └── src/main/kotlin/com/savia/domain/
│       ├── model/
│       ├── usecase/
│       └── repository/
├── data/
│   ├── build.gradle.kts
│   └── src/main/kotlin/com/savia/data/
│       ├── api/
│       ├── repository/
│       └── mapper/
└── docs/
    ├── ARCHITECTURE.md           ← Este archivo
    ├── SETUP.md                  ← Guía de instalación
    └── BRIDGE-GUIDE.md           ← Guía de Savia Bridge
```

---

## Solución de Problemas

### "JAVA_HOME not set"

```bash
export JAVA_HOME=$(which java | xargs dirname | xargs dirname)
```

Verificar:
```bash
echo $JAVA_HOME
ls $JAVA_HOME/bin/java
```

### "ANDROID_HOME not set"

```bash
export ANDROID_HOME=~/Android/Sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME
```

### Gradle build falla con "Java version mismatch"

Verificar que Gradle usa JDK 17:

```bash
./gradlew --version
```

Si no es 17, establecer:

```bash
export JAVA_HOME=$(jenv versions | grep 17 | xargs jenv which)  # macOS con jenv
# o manualmente:
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
./gradlew clean build
```

### "Could not find SDK" en emulador

```bash
$ANDROID_HOME/tools/bin/sdkmanager --list_installed
$ANDROID_HOME/tools/bin/sdkmanager "platforms;android-35" "build-tools;35.0.0"
```

### Emulador no se inicia

Posibles causas:
- KVM no disponible (Linux): Verificar virtualización en BIOS
- Memoria insuficiente: Reducir RAM del AVD en Android Studio
- Puerto en uso: `lsof -i :5554` (en Linux)

```bash
# Forzar reinicio
$ANDROID_HOME/emulator/emulator -avd pixel7 -wipe-data &
```

---

## Variables de Entorno Resumen

| Variable | Valor | Notas |
|----------|-------|-------|
| `JAVA_HOME` | `/usr/lib/jvm/java-17-openjdk-amd64` | JDK 17 (no OpenJDK < 17) |
| `ANDROID_HOME` | `~/Android/Sdk` | Android SDK root |
| `ANDROID_SDK_ROOT` | `~/Android/Sdk` | Alternativa a ANDROID_HOME |
| `PATH` | `$ANDROID_HOME/platform-tools:...` | Para adb, emulator |

---

## Siguientes Pasos

1. ✅ Instalar requisitos previos (JDK 17, Android SDK)
2. ✅ Clonar repositorio y descargar dependencias
3. ✅ Conectar Savia Bridge (URL + token)
4. ✅ Ejecutar en emulador o dispositivo
5. 🔄 Explorar el código en `app/src/main/kotlin/`
6. 🔄 Leer [ARCHITECTURE.md](ARCHITECTURE.md) para entender la estructura
7. 🔄 Consultar [BRIDGE-GUIDE.md](BRIDGE-GUIDE.md) para profundizar en el Bridge

---

## Recursos Adicionales

- [Android Developer Docs](https://developer.android.com/)
- [Jetpack Compose](https://developer.android.com/jetpack/compose)
- [Hilt Dependency Injection](https://developer.android.com/training/dependency-injection/hilt-android)
- [Retrofit Networking](https://square.github.io/retrofit/)
- [Kotlin Coroutines](https://kotlinlang.org/docs/coroutines-overview.html)
