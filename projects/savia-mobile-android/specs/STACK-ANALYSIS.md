# Savia Mobile — Stack Technology Analysis

> Investigación realizada: Marzo 2026. Todas las decisiones basadas en estado actual del ecosistema.

## 1. Decisión: Kotlin Nativo vs KMP

| Criterio | Kotlin Nativo | Kotlin Multiplatform |
|----------|--------------|---------------------|
| Madurez | Plena | Estable desde 2023 |
| Necesidad de iOS | No (solo Android) | Sí |
| Complejidad | Baja | Media-Alta |
| Velocidad de desarrollo | Alta | Media |
| Jetpack completo | Sí | Parcial |

**Decisión: Kotlin Nativo (Android puro)**
Razón: Savia Mobile es Android-first. KMP añade complejidad sin beneficio inmediato. Si en el futuro necesitamos iOS, la capa domain/ está diseñada para ser portable a KMP sin reescritura.

## 2. Decisión: UI Framework

| Opción | Estado 2026 | Pros | Contras |
|--------|------------|------|---------|
| Jetpack Compose | Default, estable | Declarativo, Hot Reload estable | — |
| XML Views | Legacy | Más tutoriales antiguos | No recomendado para nuevos proyectos |
| Compose Multiplatform | 1.10.0 | iOS sharing | Innecesario sin iOS |

**Decisión: Jetpack Compose**
Razón: Es el estándar de facto para nuevos proyectos Android. Hot Reload estable desde 2026. Material 3 + Material You (dynamic colors) incluido.

## 3. Decisión: Cliente HTTP para Claude API

**Hallazgo crítico: No existe SDK oficial de Anthropic para Kotlin/Android.**

| Opción | Mantenimiento | Android-friendly | Streaming |
|--------|--------------|-------------------|-----------|
| Retrofit + OkHttp | Activo (v2.11.0 + v4.12.0) | Nativo | Via OkHttp SSE |
| Ktor Client | Activo (v2.3.12) | Sí (multiplataforma) | Via chunked |
| anthropic-sdk-kotlin (xemantic) | Comunitario | Sí | Sí |

**Decisión: Retrofit 2.11.0 + OkHttp 4.12.0**
Razón: Estándar de la industria Android, excelente soporte de streaming SSE con OkHttp, máxima documentación y comunidad. Ktor es buena alternativa si migramos a KMP en el futuro.

## 4. Decisión: Biblioteca SSH

**Hallazgo crítico: JSch original está abandonado (último release Nov 2025, deprecated).**

| Opción | Estado | Última versión | Android |
|--------|--------|---------------|---------|
| JSch (original) | Abandonado | Nov 2025 | Sí pero inseguro |
| mwiede/jsch (fork) | Activo | 2026 | Sí |
| Apache MINA SSHD | Activo (v1.18.0, Ene 2026) | Ene 2026 | Sí (pure Java) |

**Decisión: Apache MINA SSHD 1.18.0**
Razón: Mantenimiento activo, 100% Java puro (funciona en Android), arquitectura extensible, soporte SFTP robusto. El fork de JSch es alternativa válida pero MINA tiene mejor arquitectura.

## 5. Decisión: Seguridad y Almacenamiento de Secretos

**Hallazgo crítico: EncryptedSharedPreferences está DEPRECADO (security-crypto 1.1.0-alpha07).**

| Componente | Solución | Razón |
|-----------|----------|-------|
| API keys | Android Keystore + Tink 1.10.0 | Hardware-backed, Google estándar |
| SSH keys | Tink AEAD encrypt + Keystore | Nunca en texto plano |
| Preferencias | Jetpack DataStore | Reemplazo moderno de SharedPreferences |
| BD offline | Room + SQLCipher | Cifrado transparente de BD |
| Biometría | BiometricPrompt API | Lock opcional de app |

**Decisión: Tink 1.10.0 + Android Keystore**
Razón: Tink es la biblioteca criptográfica de Google (usada en Google Pay, Firebase). Reemplaza EncryptedSharedPreferences con API más robusta y mantenida.

## 6. Decisión: Persistencia Local

| Dato | Solución | Razón |
|------|----------|-------|
| Conversaciones | Room 2.7.0 | Relacional, queries complejas |
| Snapshots workspace | Room | Historial temporal |
| Preferencias usuario | DataStore 1.1.1 | Key-value moderno |
| Cache API responses | Room + expiración 30d | Offline mode |

**Decisión: Room 2.7.0 + DataStore 1.1.1**

## 7. Decisión: Inyección de Dependencias

| Opción | Complejidad | Performance | Estándar |
|--------|------------|-------------|----------|
| Hilt (Dagger) | Media | Compile-time | Google recomendado |
| Koin | Baja | Runtime | Popular comunidad |

**Decisión: Hilt 2.51**
Razón: Recomendación oficial de Google para Android, inyección en compile-time (mejor performance), integración nativa con ViewModel y Navigation.

## 8. Decisión: CI/CD

**Decisión: GitHub Actions**
Razón: El workspace pm-workspace ya usa GitHub. Mantener todo en el mismo ecosistema. Pipeline: lint → test → build → deploy a Play Store.

## 9. Decisión: Target SDK y Compatibilidad

| Parámetro | Valor | Razón |
|-----------|-------|-------|
| minSdk | 26 (Android 8.0) | 99%+ dispositivos |
| targetSdk | 35 (Android 15) | Requisito Play Store 2026 |
| compileSdk | 35 | Última API disponible |

## Stack Final Consolidado

```
┌─────────────────────────────────────────────────┐
│                 SAVIA MOBILE                     │
├─────────────────────────────────────────────────┤
│ UI        │ Jetpack Compose + Material 3        │
│ State     │ ViewModel + StateFlow               │
│ Navigation│ Navigation Compose                   │
│ DI        │ Hilt 2.51                           │
├─────────────────────────────────────────────────┤
│ HTTP      │ Retrofit 2.11.0 + OkHttp 4.12.0    │
│ SSH       │ Apache MINA SSHD 1.18.0            │
│ JSON      │ Kotlin Serialization 1.6.0          │
├─────────────────────────────────────────────────┤
│ Storage   │ Room 2.7.0 + DataStore 1.1.1        │
│ Security  │ Tink 1.10.0 + Android Keystore      │
│ Crypto DB │ SQLCipher 4.6.0                     │
├─────────────────────────────────────────────────┤
│ Testing   │ JUnit 5 + MockK + Turbine + Espresso│
│ CI/CD     │ GitHub Actions                       │
│ Target    │ SDK 26-35 (Android 8.0 → 15)        │
└─────────────────────────────────────────────────┘
```
