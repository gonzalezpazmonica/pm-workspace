# Savia Mobile — Pipelines de CI/CD

> Actualizado: Marzo 2026. Configuración real basada en `.github/workflows/android-ci.yml`.

## Arquitectura General

```
develop (feature branches)
        ↓
   Pull Request
        ↓
   GitHub Actions: CI Validation
   ├─ Lint & Static Analysis
   ├─ Unit Tests
   ├─ Security Scan (Dependency Check)
   └─ Build Debug APK
        ↓
   Code Review → merge a main
        ↓
   main branch
        ↓
   GitHub Actions: Release Pipeline
   ├─ Build Release AAB
   └─ Deploy Internal Testing (Google Play)
        ↓
   Tag v1.0.0, v1.1.0, etc.
        ↓
   GitHub Actions: Production Pipeline
   └─ Deploy Production (staged: 10% → 25% → 50% → 100%)
```

## Pipeline 1: Validación en PR

**Trigger:** Cualquier pull request a `main` o `develop`

**Workflow:** `.github/workflows/android-ci.yml` (primeras 3 secciones)

### Job: Lint & Static Analysis

Ejecuta en **ubuntu-latest**

```bash
# Lint de recursos Android
./gradlew lintDebug

# Static analysis con Detekt (Kotlin linter)
./gradlew detekt
```

Artefactos:
- `**/build/reports/lint-results-*.html` (si hay warnings/errors)
- Detekt reports (en build/reports/)

**Criterio de Éxito:** No hay warnings críticos (bloqueadores de merge)

### Job: Unit Tests

Ejecuta en **ubuntu-latest**

```bash
# Tests unitarios Android (mocks, sin emulador)
./gradlew testDebugUnitTest

# Cobertura de código
./gradlew jacocoTestReport

# Verificación de cobertura mínima (80%)
COVERAGE=$(cat app/build/reports/jacoco/jacocoTestReport/html/index.html \
  | grep -oP 'Total.*?(\d+)%' | grep -oP '\d+' | head -1)
[ "${COVERAGE:-0}" -ge 80 ] || { echo "FAIL: Coverage below 80%"; exit 1; }
```

Artefactos:
- `**/build/reports/tests/` (resultados de tests)
- `app/build/reports/jacoco/jacocoTestReport/` (cobertura)

**Criterio de Éxito:**
- Todos los tests pasan
- Cobertura ≥ 80%

### Job: Security Scan

Ejecuta en **ubuntu-latest**

```bash
# Scan de dependencias (OWASP Dependency Check)
./gradlew dependencyCheckAnalyze
```

Detecta:
- CVEs en dependencias
- Librerías deprecadas
- Vulnerabilidades conocidas

Artefactos:
- `build/reports/dependency-check-report.html`

**Criterio de Éxito:** No hay vulnerabilidades críticas

### Job: Build Debug APK

Ejecuta en **ubuntu-latest** (requiere: lint, unit-tests)

```bash
./gradlew assembleDebug
```

Artefactos:
- `app/build/outputs/apk/debug/*.apk`

**Criterio de Éxito:** APK compilado exitosamente

## Pipeline 2: Compilación Release & Internal Deploy

**Trigger:** Push a rama `main` (merge de PR)

**Workflow:** `.github/workflows/release.yml`

### Job: Build Release Bundle

Ejecuta en **ubuntu-latest**

```bash
# Decodificar keystore (almacenado como secret base64)
echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 -d > app/release.keystore

# Compilar bundle para Google Play
./gradlew bundleRelease \
  -PSIGNING_STORE_FILE=release.keystore \
  -PSIGNING_STORE_PASSWORD=${{ secrets.KEYSTORE_PASSWORD }} \
  -PSIGNING_KEY_ALIAS=${{ secrets.KEY_ALIAS }} \
  -PSIGNING_KEY_PASSWORD=${{ secrets.KEY_PASSWORD }}
```

Variables de entorno:
- `SIGNING_STORE_FILE`: Ruta al keystore
- `SIGNING_STORE_PASSWORD`: Password del keystore
- `SIGNING_KEY_ALIAS`: Alias de la clave de firma
- `SIGNING_KEY_PASSWORD`: Password de la clave

Artefactos:
- `app/build/outputs/bundle/release/*.aab` (Android App Bundle)

**Criterio de Éxito:** AAB generado y firmado

### Job: Deploy to Internal Testing

Ejecuta en **ubuntu-latest** (requiere: build-release)

Trigger: Solo en rama `main`

```bash
# Usar Google Play service account para deploy
# Token provisto via secret: PLAY_SERVICE_ACCOUNT (JSON)
```

Acción: `r0adkll/upload-google-play@v1.1.3`

Parámetros:
- `serviceAccountJsonPlainText`: Service account credentials
- `packageName`: `com.savia.mobile`
- `releaseFiles`: `*.aab` (el bundle generado)
- `track`: `internal` (pista de prueba interna)
- `status`: `completed` (versión lista para pruebas)

**Criterio de Éxito:** AAB subido a Google Play interno track

**Próximo paso:** QA puede instalar desde Google Play Console (Internal Testing)

## Pipeline 3: Production Deploy (Staged Rollout)

**Trigger:** Nuevo tag `v*` (ej: `v1.0.0`, `v1.2.3`)

**Workflow:** `.github/workflows/release.yml` (sección deploy-production)

```bash
# Crear un tag
git tag v1.0.0
git push origin v1.0.0
```

### Job: Deploy to Production (10%)

Ejecuta en **ubuntu-latest** (requiere: build-release)

Trigger: Solo si `github.ref` comienza con `refs/tags/v`

```bash
# Mismo proceso que internal, pero track=production + staged rollout
```

Parámetros:
- `track`: `production`
- `userFraction`: `0.1` (10% de usuarios)
- `status`: `inProgress` (rollout progresivo, no inmediato)

**Significado:** El 10% de usuarios en Google Play recibirán la versión v1.0.0. Se monitorean crashes, ratings, feedback durante 48 horas.

### Rollout Manual (después de 48h en cada etapa)

Una vez que se verifica que la versión v1.0.0 es estable en 10%, manualmente:

1. Google Play Console → Releases → Production
2. Change user fraction → 25%
3. Esperar 48h, monitorear métricas
4. Cambiar → 50%
5. Esperar 48h
6. Cambiar → 100% (todos los usuarios)

**Criterio de Éxito:** Sin crashes críticos, ratings > 4.0, feedback positivo

## Pipeline 4: Nightly Quality Check (Opcional)

**Trigger:** Programado: Lun-Vie 3:00 AM UTC

**Workflow:** `.github/workflows/nightly.yml`

### Job: Instrumented Tests (con Emulador)

Ejecuta en **ubuntu-latest**

```bash
# Tests de integración en Android Emulator (API 34)
./gradlew connectedAndroidTest
```

Usa acción: `reactivecircus/android-emulator-runner@v2`

Configuración del emulador:
- API Level: 34
- Target: `google_apis`
- Arquitectura: x86_64 (rápido en CI)

**Duración:** ~10-15 minutos

### Job: Baseline Profile Generation

Ejecuta en **ubuntu-latest**

```bash
# Generar perfiles de baseline para optimizar Compose
./gradlew :app:generateBaselineProfile
```

Resultado: Archivos `baseline-prof.txt` que optimizan el arranque de la app

### Job: APK Size Check

Ejecuta en **ubuntu-latest**

```bash
./gradlew assembleRelease

# Verificar que APK < 20 MB
SIZE=$(stat -f%z app/build/outputs/apk/release/*.apk)
SIZE_MB=$((SIZE / 1048576))
[ "$SIZE_MB" -le 20 ] || { echo "FAIL: APK exceeds 20MB"; exit 1; }
```

**Umbral:** 20 MB (para que descarga sea rápida en 4G)

## Secretos Requeridos en GitHub

Configurar en: Repository Settings → Secrets and Variables → Actions

| Secret | Descripción | Ejemplo |
|--------|-------------|---------|
| `KEYSTORE_BASE64` | Keystore de firma codificado en base64 | (resultado de: `base64 -w 0 release.keystore`) |
| `KEYSTORE_PASSWORD` | Password del keystore | `MySecurePass123!` |
| `KEY_ALIAS` | Alias de la clave de firma dentro del keystore | `savia-key` |
| `KEY_PASSWORD` | Password individual de la clave | `MyKeyPass456!` |
| `PLAY_SERVICE_ACCOUNT` | JSON de service account de Google Play | (JSON completo con credenciales de API) |

### Cómo Obtener los Secretos

#### 1. Crear Keystore

```bash
# Una sola vez, guardar de forma segura
keytool -genkey -v -keystore release.keystore \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias savia-key -storepass MySecurePass123! \
  -keypass MyKeyPass456!
```

#### 2. Codificar a Base64

```bash
base64 -w 0 release.keystore | pbcopy  # macOS
# o
base64 release.keystore | tr -d '\n' | xclip -selection clipboard  # Linux
```

#### 3. Google Play Service Account

1. Google Cloud Console → Project
2. Service Accounts → Create Service Account
3. Roles: `Firebase App Distribution Service Agent` + `Play Console API User`
4. Create Key (JSON) → descargar
5. Copiar contenido JSON completo a secret `PLAY_SERVICE_ACCOUNT`

## Archivos de Workflow

- `.github/workflows/android-ci.yml` — Linting, tests, security (PR)
- `.github/workflows/release.yml` — Build release y deploy (main + tags)
- `.github/workflows/nightly.yml` — Tests instrumented, baseline profiles, size check

## Métricas & Monitoreo

### Pre-Merge (antes de main)
- Lint score: 0 errores críticos
- Test pass rate: 100%
- Coverage: ≥ 80%
- Security scan: 0 críticos

### Post-Release (después de deploy)
- Crash rate: < 0.1%
- ANR rate: < 0.05%
- Google Play ratings: ≥ 4.0
- User feedback: monitor en Google Play Console

## Rollback Plan

Si hay problemas en producción:

1. **Staged < 5% afectados:** Reducir userFraction al 1%
2. **Staged 5-25% afectados:** Pausar rollout, investigar
3. **Staged > 25% afectados:** Revertir a versión anterior (rollback manual en Google Play)

## Velocity de Releases

- **Hotfixes:** Tag v1.0.1 → internal (1h) → production staged (48h per stage)
- **Features:** Merge main → internal (1h) → wait QA sign-off → tag & production
- **Major versions:** v2.0.0 → internal test → closed beta → production staged

## Estado Actual (v0.1.0-debug)

```
✅ CI/CD setup completo
✅ Secrets configurados en GitHub
✅ Pipelines testeados
⏳ APK disponible en ~/.savia/bridge/apk/ (descargable via bridge web)
⏳ Primer release interno pendiente (cuando features MVP completo)
```
