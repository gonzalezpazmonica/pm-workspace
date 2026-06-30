# Mobile Security Scanner — Dominio y Conocimiento

## Por que existe esta skill

Las aplicaciones móviles exponen superficie de ataque distinta a las web: almacenamiento local, comunicación con backends, claves embebidas en el binario, y configuraciones de componentes Android/iOS. Un APK o IPA puede analizarse estáticamente sin acceso al código fuente.

Este skill analiza APKs (Android) con MobSF en modo estático para detectar vulnerabilidades comunes en aplicaciones móviles.

---

## Vectores de ataque específicos de móvil

### Almacenamiento inseguro
- Datos sensibles en SharedPreferences sin cifrado
- SQLite databases sin SQLCipher
- Ficheros en almacenamiento externo (SD card) accesibles a otras apps
- Backups de Android habilitados (`android:allowBackup="true"`) con datos sensibles

### Comunicaciones inseguras
- HTTP en lugar de HTTPS para APIs
- Certificate pinning ausente (susceptible a MitM con proxy instalado)
- Validación de certificados deshabilitada en código (TrustAllCerts pattern)
- WebViews con `setJavaScriptEnabled(true)` y `addJavascriptInterface`

### Criptografía débil
- AES en modo ECB (no IV, mismo bloque → mismo cifrado)
- Claves hardcodeadas en código o recursos
- Random no criptográfico (`java.util.Random` en lugar de `SecureRandom`)
- MD5/SHA1 para integridad (colisiones conocidas)

### Componentes Android expuestos
- Activities, Services, Broadcast Receivers y Content Providers con `exported="true"` sin permisos
- Deep links sin validación de origen
- Implicit Intents para datos sensibles

---

## OWASP Mobile Top 10 (2024)

| ID | Riesgo | Descripción breve |
|---|---|---|
| M1 | Improper Credential Usage | Credenciales hardcodeadas, sin rotación |
| M2 | Inadequate Supply Chain Security | Dependencias móviles vulnerables |
| M3 | Insecure Authentication/Authorization | Tokens débiles, falta de MFA |
| M4 | Insufficient Input/Output Validation | SQLi, XSS en WebViews |
| M5 | Insecure Communication | HTTP, certificate validation bypass |
| M6 | Inadequate Privacy Controls | PII logging, analytics excesivo |
| M7 | Insufficient Binary Protections | Sin obfuscación, root detection ausente |
| M8 | Security Misconfiguration | Backups, exported components |
| M9 | Insecure Data Storage | SharedPreferences, logs, SQLite |
| M10 | Insufficient Cryptography | ECB, hardcoded keys, weak RNG |

---

## Nivel de análisis vs. riesgo real

El análisis estático (MobSF) detecta patrones conocidos pero no puede determinar:
- Si una vulnerabilidad es realmente alcanzable en el flujo de la app
- Si un componente exported tiene validación de permisos en otro nivel
- El impacto real de datos expuestos sin conocer la clasificación de los datos

El análisis dinámico (en dispositivo) es necesario para confirmar explotabilidad. Este skill cubre el análisis estático; el skill `android-autonomous-debugger` cubre testing en dispositivo.

---

## Autorización explícita requerida

El análisis de APKs de terceros o de producción requiere fichero de autorización en `output/security/authorization-mobile-{app}.txt` firmado por el propietario de la aplicación. El skill no analiza APKs sin ese fichero presente.
