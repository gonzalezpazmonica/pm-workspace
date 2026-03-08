# Savia Mobile — CI/CD Pipelines

## Pipeline 1: PR Validation (en cada Pull Request)

```yaml
# .github/workflows/pr-validation.yml
name: PR Validation

on:
  pull_request:
    branches: [main, develop]

concurrency:
  group: pr-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  lint:
    name: Lint & Static Analysis
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
      - uses: gradle/actions/setup-gradle@v4
      - run: ./gradlew lintDebug
      - run: ./gradlew detekt
      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: lint-reports
          path: '**/build/reports/lint-results-*.html'

  unit-tests:
    name: Unit Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
      - uses: gradle/actions/setup-gradle@v4
      - run: ./gradlew testDebugUnitTest
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-reports
          path: '**/build/reports/tests/'
      - name: Coverage report
        run: ./gradlew jacocoTestReport
      - name: Check minimum coverage (80%)
        run: |
          COVERAGE=$(cat app/build/reports/jacoco/jacocoTestReport/html/index.html \
            | grep -oP 'Total.*?(\d+)%' | grep -oP '\d+' | head -1)
          echo "Coverage: ${COVERAGE}%"
          [ "${COVERAGE:-0}" -ge 80 ] || { echo "FAIL: Coverage below 80%"; exit 1; }

  security-scan:
    name: Dependency Security
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
      - uses: gradle/actions/setup-gradle@v4
      - run: ./gradlew dependencyCheckAnalyze
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: dependency-check
          path: 'build/reports/dependency-check-report.html'

  build:
    name: Build Debug APK
    needs: [lint, unit-tests]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
      - uses: gradle/actions/setup-gradle@v4
      - run: ./gradlew assembleDebug
      - uses: actions/upload-artifact@v4
        with:
          name: debug-apk
          path: app/build/outputs/apk/debug/*.apk
```

## Pipeline 2: Main Build & Deploy (en merge a main)

```yaml
# .github/workflows/release.yml
name: Release Pipeline

on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  build-release:
    name: Build Release Bundle
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
      - uses: gradle/actions/setup-gradle@v4

      - name: Decode keystore
        run: echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 -d > app/release.keystore

      - name: Build release AAB
        run: ./gradlew bundleRelease
        env:
          SIGNING_STORE_FILE: release.keystore
          SIGNING_STORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
          SIGNING_KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
          SIGNING_KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}

      - uses: actions/upload-artifact@v4
        with:
          name: release-bundle
          path: app/build/outputs/bundle/release/*.aab

  deploy-internal:
    name: Deploy to Internal Testing
    needs: build-release
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: release-bundle
      - uses: r0adkll/upload-google-play@v1.1.3
        with:
          serviceAccountJsonPlainText: ${{ secrets.PLAY_SERVICE_ACCOUNT }}
          packageName: com.savia.mobile
          releaseFiles: '*.aab'
          track: internal
          status: completed

  deploy-production:
    name: Deploy to Production (staged)
    needs: build-release
    if: startsWith(github.ref, 'refs/tags/v')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: release-bundle
      - uses: r0adkll/upload-google-play@v1.1.3
        with:
          serviceAccountJsonPlainText: ${{ secrets.PLAY_SERVICE_ACCOUNT }}
          packageName: com.savia.mobile
          releaseFiles: '*.aab'
          track: production
          userFraction: 0.1
          status: inProgress
```

## Pipeline 3: Nightly Quality (programada)

```yaml
# .github/workflows/nightly.yml
name: Nightly Quality Check

on:
  schedule:
    - cron: '0 3 * * 1-5'  # Lun-Vie a las 3:00 AM
  workflow_dispatch:

jobs:
  instrumented-tests:
    name: Instrumented Tests (Emulator)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
      - uses: gradle/actions/setup-gradle@v4
      - name: Run instrumented tests
        uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: 34
          target: google_apis
          arch: x86_64
          script: ./gradlew connectedAndroidTest

  performance-baseline:
    name: Baseline Profile Generation
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
      - uses: gradle/actions/setup-gradle@v4
      - name: Generate baseline profiles
        uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: 34
          target: google_apis
          arch: x86_64
          script: ./gradlew :app:generateBaselineProfile

  size-check:
    name: APK Size Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
      - uses: gradle/actions/setup-gradle@v4
      - run: ./gradlew assembleRelease
      - name: Check APK size (max 20MB)
        run: |
          SIZE=$(stat -f%z app/build/outputs/apk/release/*.apk 2>/dev/null \
            || stat --printf='%s' app/build/outputs/apk/release/*.apk)
          SIZE_MB=$((SIZE / 1048576))
          echo "APK size: ${SIZE_MB}MB"
          [ "$SIZE_MB" -le 20 ] || { echo "FAIL: APK exceeds 20MB"; exit 1; }
```

## Secrets Requeridos en GitHub

| Secret | Descripción | Cuándo |
|--------|-------------|--------|
| `KEYSTORE_BASE64` | Keystore de firma (base64) | Release builds |
| `KEYSTORE_PASSWORD` | Password del keystore | Release builds |
| `KEY_ALIAS` | Alias de la key | Release builds |
| `KEY_PASSWORD` | Password de la key | Release builds |
| `PLAY_SERVICE_ACCOUNT` | Service account JSON de Google Play | Deploy |

## Flujo de Releases

```
develop → PR → main (CI + internal track)
                ↓
         tag v1.0.0 → production (staged 10%)
                       ↓ (48h, metrics OK)
                     staged 25%
                       ↓ (48h)
                     staged 50%
                       ↓ (48h)
                     staged 100%
```
