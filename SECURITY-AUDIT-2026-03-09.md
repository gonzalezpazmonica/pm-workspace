# Auditoría de Seguridad Completa — pm-workspace
**Fecha:** 9 de marzo de 2026
**Auditor:** Savia (PM automatizada)
**Alcance:** Repositorio completo — Android app, Bridge, dotnet-microservices, CI/CD, 181 shell scripts, hooks, agents, instaladores
**Riesgo global: ALTO — 18 críticos, 22 altos, 15 medios**

---

## Resumen ejecutivo

pm-workspace tiene una base de seguridad sólida (Tink, Gitleaks, hooks de protección, CODEOWNERS). Sin embargo, la auditoría ha identificado vulnerabilidades explotables en **seis áreas**: la app Android acepta cualquier certificado TLS (MitM), el Bridge expone endpoints sin auth, los instaladores descargan binarios sin verificar integridad, Kubernetes no tiene RBAC ni network policies, los scripts de shell tienen variables sin comillas en traps, y las GitHub Actions no están pinneadas por SHA.

El factor atenuante principal es que la mayoría de servicios solo operan en red local. Pero un atacante en la misma WiFi/VPN podría comprometer el sistema completo.

---

## ÁREA 1: SAVIA MOBILE (Android App)

### C1. TrustAllCertificates — Man-in-the-Middle
**Archivo:** `projects/savia-mobile-android/app/.../di/NetworkModule.kt:84-99`
**Impacto:** Cualquier atacante en la misma red intercepta token Bearer y conversaciones con Claude.
**Detalle:** `X509TrustManager` acepta todo. `hostnameVerifier { _, _ -> true }`.
**Fix:** Certificate pinning con `CertificatePinner` de OkHttp usando fingerprint del Bridge.

### C2. Base de datos Room sin cifrar
**Archivo:** `projects/savia-mobile-android/app/.../di/DatabaseModule.kt:43-52`
**Impacto:** Dispositivo rooteado → conversaciones legibles en texto plano.
**Detalle:** SQLCipher comentado. Tink genera passphrase pero no se conecta.
**Fix:** Descomentar SQLCipher + `SupportFactory(passphrase)`.

### C6. HttpLoggingInterceptor en producción
**Archivo:** `projects/savia-mobile-android/app/.../di/NetworkModule.kt:103-107`
**Impacto:** Bearer token impreso en logcat (ADB, dispositivos rooteados).
**Fix:** Condicionar a `BuildConfig.DEBUG`.

### A11. Encoding passphrase SQLCipher incorrecto
**Archivo:** `projects/savia-mobile-android/data/.../SecurityRepositoryImpl.kt:303-314`
**Fix:** `Base64.decode()` en vez de `toByteArray(UTF_8)`.

---

## ÁREA 2: SAVIA BRIDGE (Python Server)

### C3. Inyección de comandos en PUT /git-config
**Archivo:** `scripts/savia-bridge.py:1725-1741`
**Impacto:** Atacante autenticado ejecuta comandos vía campo `name`/`email`.
**Fix:** Validar con regex `^[a-zA-Z0-9 ._@-]+$`.

### C4. GitHub PAT almacenado en Base64 (no cifrado)
**Archivo:** `scripts/savia-bridge.py:1745-1754`
**Impacto:** `base64 -d` recupera el token.
**Fix:** `cryptography.fernet.Fernet` o variable de entorno.

### C5. Endpoints sensibles sin autenticación
**Archivo:** `scripts/savia-bridge.py:1134-1308`
**Impacto:** `/profile`, `/company`, `/git-config`, `/team` devuelven datos sin Bearer.
**Fix:** `_check_auth()` en todos los endpoints sensibles.

### A1. Path traversal en descarga de APK
**Archivo:** `scripts/savia-bridge.py:1119-1132`
**Fix:** Verificar `apk.resolve()` dentro de `APK_DIR.resolve()`.

### A2. SSE sin límite de conexiones
**Archivo:** `scripts/savia-bridge.py:1609-1632`
**Fix:** MAX_CONCURRENT_STREAMS=10, timeout por inactividad.

### A3. Sin rate limiting en autenticación
**Fix:** Bloquear IP tras 5 intentos fallidos / 5 min.

### A4. Sin cabeceras de seguridad HTTP
**Fix:** X-Content-Type-Options, X-Frame-Options, HSTS, CSP.

### A5. CORS `Access-Control-Allow-Origin: *`
**Archivo:** `scripts/savia-bridge.py:995`
**Fix:** Restringir a orígenes conocidos.

### A6. Body JSON sin límite de tamaño
**Archivo:** `scripts/savia-bridge.py:1573-1574`
**Fix:** Rechazar Content-Length > 1MB.

### A7. Datos sensibles en logs
**Archivo:** `scripts/savia-bridge.py:805-809`
**Fix:** Sanitizar tokens antes de loguear.

### A10. Systemd service sin hardening
**Archivo:** `scripts/savia-bridge.service`
**Fix:** PrivateTmp, ProtectSystem, NoNewPrivileges, MemoryLimit.

---

## ÁREA 3: DOTNET-MICROSERVICES + KUBERNETES

### C7. Credenciales hardcodeadas en docker-compose.yml
**Archivo:** `projects/dotnet-microservices-home-lab/docker-compose.yml:8,19`
**Impacto:** `dev_password` para MongoDB y RabbitMQ en texto plano.
**Fix:** `.env` con `${MONGO_PASSWORD}`.

### C11. Secretos K8s en texto plano YAML
**Archivo:** `projects/dotnet-microservices-home-lab/k8s/secrets.yaml:8-11`
**Impacto:** Connection strings con `admin:CAMBIAR` en el repositorio.
**Fix:** Sealed-secrets, Azure Key Vault, o external-secrets operator.

### C12. CORS `AllowAnyOrigin()` en API .NET
**Archivo:** `projects/dotnet-microservices-home-lab/src/Project.Api/Program.cs:62-66`
**Impacto:** Cualquier dominio puede hacer requests a la API.
**Fix:** `WithOrigins("https://yourdomain.com")`.

### C13. JWT Secret placeholder en appsettings.json
**Archivo:** `projects/dotnet-microservices-home-lab/src/Project.Api/appsettings.json:10-15`
**Fix:** Cargar desde user-secrets o variable de entorno.

### A14. Sin Network Policies en K8s
**Impacto:** Cualquier pod compromiso puede atacar todos los demás.
**Fix:** NetworkPolicy con ingress/egress whitelist.

### A15. Sin RBAC en K8s
**Impacto:** Pods usan default ServiceAccount (permisos excesivos).
**Fix:** ServiceAccounts dedicados + Roles restrictivos.

### A16. Sin Pod Security Standards
**Impacto:** Containers corren como root.
**Fix:** `runAsNonRoot: true`, `allowPrivilegeEscalation: false`, `drop: ["ALL"]`.

### A17. Sin TLS inter-servicio
**Archivo:** `k8s/api-deployment.yaml:51` — `http://` para OpenTelemetry.
**Fix:** mTLS para MongoDB, RabbitMQ, OTEL.

### A18. Docker images con tag `latest`
**Archivo:** `k8s/api-deployment.yaml:18`
**Fix:** Versiones fijas + digest SHA256.

---

## ÁREA 4: SHELL SCRIPTS (181 archivos auditados)

### C10. `bash -c "$1"` en test scripts
**Archivos:** `scripts/test-scale-optimizer.sh:8`, `test-rbac-manager.sh:8`, `test-savia-index.sh:9`
**Impacto:** Ejecución de código arbitrario si el argumento contiene `$(...)`.
**Fix:** Funciones en vez de strings evaluados.

### C14. `curl | sh` sin verificación
**Archivo:** `scripts/emergency-setup.sh:82`
**Impacto:** Descarga y ejecuta Ollama installer sin checksum ni firma.
**Fix:** Descargar a archivo, verificar SHA-256, luego ejecutar.

### C15. Trap con variable sin comillas → rm de paths arbitrarios
**Archivos:** `scripts/rules-topology.sh:8`, `savia-travel-init.sh:108`, `test-company-repo.sh:36`, `test-memory-improvements.sh:10`
**Impacto:** `trap "rm -rf $TEMP_DIR" EXIT` — si TEMP_DIR está vacío o tiene espacios, borra paths inesperados.
**Fix:** `trap 'rm -rf "$TEMP_DIR"' EXIT` (comillas simples externas, dobles internas).

### C16. Grep fallback para JSON parsing en hooks
**Archivos:** `.claude/hooks/block-credential-leak.sh:12`, `block-force-push.sh:12`
**Impacto:** Si `jq` falla, grep extrae strings sin escapar que pueden contener metacaracteres shell.
**Fix:** Fallar gracefully si `jq` no está disponible. No usar grep como fallback.

### A8. Race conditions en scripts
**Archivos:** `scripts/memory-store.sh:49-50`, `context-tracker.sh:24-25`
**Fix:** `mv` atómico.

### A19. Temp dir con PID predecible
**Archivo:** `scripts/rules-topology.sh:8` — `TEMP_DIR="/tmp/rules-topology-$$"`
**Fix:** `mktemp -d`.

### A20. sudo sin validación
**Archivo:** `scripts/emergency-setup.sh:73`
**Fix:** Intentar primero `$HOME/.local/bin`, después `sudo` solo si disponible.

### A21. tar sin `--no-absolute-file-names`
**Archivo:** `scripts/emergency-setup.sh:85-86`
**Impacto:** Archive malicioso podría sobreescribir archivos fuera del directorio objetivo.
**Fix:** `tar xzf ... --no-absolute-file-names --strip-components=1`.

---

## ÁREA 5: CI/CD + GITHUB ACTIONS

### C8. Dependencias npm sin versión fija
**Archivo:** `scripts/package.json`
**Fix:** Pinear exacto. `npm ci` con lockfile.

### C9. GitHub Actions sin SHA pinning (10 instancias)
**Archivos:** Todos los workflows en `.github/workflows/`
**Fix:** `actions/checkout@<sha>` en vez de `@v4`.

### A9. Tag manipulation en release workflow
**Archivo:** `.github/workflows/release.yml:24`
**Fix:** Validar formato de tag con regex.

### A22. Workflows sin bloque `permissions:` explícito
**Archivos:** `.github/workflows/ci.yml`, `savia-e2e.yml`
**Impacto:** Permisos implícitos `read-all`.
**Fix:** `permissions: { contents: read }`.

### A13. Detección de secretos incompleta en hook
**Archivo:** `.claude/hooks/block-credential-leak.sh:20`
**Fix:** Añadir patrones K8s tokens, Vault tokens, Docker registry creds.

---

## ÁREA 6: INSTALADORES + AGENTES

### C17. `curl | bash` en install.sh para Claude Code
**Archivo:** `install.sh:162-167`
**Impacto:** Supply chain — sin verificación de integridad.
**Fix:** Descargar, verificar SHA-256, ejecutar.

### C18. `irm | iex` en install.ps1
**Archivo:** `install.ps1:148`
**Fix:** Descargar, verificar firma GPG/Authenticode.

### A23. 12.591 archivos group-writable (0664)
**Impacto:** Escalada de privilegios si otro usuario comparte grupo.
**Fix:** `chmod g-w` en archivos sensibles.

### A24. Agent de infraestructura sin límite de costes
**Impacto:** Puede crear recursos cloud caros sin control.
**Fix:** Añadir estimación de coste y confirmación.

---

## MEDIOS (Backlog)

| # | Hallazgo | Ubicación |
|---|----------|-----------|
| M1 | YAML frontmatter injection en Bridge | savia-bridge.py:1204-1212 |
| M2 | Session ID sin validación de formato | savia-bridge.py:1599-1603 |
| M3 | TLS sin cipher suite mínima | savia-bridge.py:2130-2132 |
| M4 | Cleartext traffic en debug | network_security_config.xml:10-15 |
| M5 | Temp files sin cleanup trap | scripts/add-maturity-levels.sh:80 |
| M6 | BATS clonado sin verificación | .github/workflows/ci.yml:114 |
| M7 | Secret regex loose en CI | .github/workflows/ci.yml:44-50 |
| M8 | Variables sin comillas en 70+ test scripts | scripts/test-*.sh |
| M9 | Worker pod sin health checks | k8s/worker-deployment.yaml |
| M10 | Secrets como env vars (no volume mount) | k8s/api-deployment.yaml:25-49 |
| M11 | Docker frontend sin `npm ci --production` | dotnet.../frontend/Dockerfile |
| M12 | JWT silent failures (bare catch) | JwtService.cs:56 |
| M13 | Sin policy de rotación de secretos | Infraestructura general |
| M14 | appsettings.Production.json con templates | appsettings.Production.json:3-5 |
| M15 | Hook plan-gate.sh sin timeout explícito | .claude/hooks/plan-gate.sh |

---

## Lo que ya está bien hecho

- .gitignore exhaustivo (`.env*`, `*.pem`, `*.key`, `*.p12`, `*.pat`, `projects/*`)
- Gitleaks activo en cada PR
- Bearer token con `secrets.token_urlsafe(32)` + comparación constant-time
- Tink AES-256-GCM + Android Keystore (hardware-backed)
- `android:allowBackup="false"`, sin WebViews, ProGuard/R8
- CODEOWNERS protegiendo workflows, hooks, CLAUDE.md
- Hook block-credential-leak.sh detecta 9+ tipos de secretos
- Hook block-force-push.sh previene force push
- Hook validate-bash-global.sh bloquea sudo, chmod 777, curl|bash
- Protect-project-privacy.sh con default deny-all
- Sin self-hosted runners (todos GitHub-hosted)
- Sin inyección de `github.event` en workflows
- Cleartext traffic bloqueado en producción Android

---

## Plan de remediación

### Semana 1 — Críticos urgentes (impacto alto, esfuerzo bajo)
| ID | Qué | Esfuerzo |
|----|-----|----------|
| C1 | Certificate pinning OkHttp | 2h |
| C5 | Auth en endpoints Bridge | 1h |
| C6 | Logging solo en DEBUG | 15min |
| C15 | Comillas en traps de shell | 30min |
| C16 | Eliminar grep fallback en hooks | 30min |

### Semana 2 — Críticos + Altos prioritarios
| ID | Qué | Esfuerzo |
|----|-----|----------|
| C2 | Activar SQLCipher | 2h |
| C3 | Validación input Bridge | 1h |
| C7 | Docker .env | 30min |
| C9 | SHA pinning en Actions | 30min |
| C11 | Sealed-secrets K8s | 4h |
| A1-A4 | Path traversal, rate limit, headers, SSE limit | 4h |

### Semana 3 — Altos restantes
| ID | Qué | Esfuerzo |
|----|-----|----------|
| C4 | Cifrar PAT (Fernet o env var) | 1h |
| C8 | Pinear npm | 15min |
| C10 | Eliminar bash -c | 1h |
| C14 | Checksum en curl installers | 1h |
| A14-A18 | K8s hardening (RBAC, NetworkPolicy, PodSecurity, TLS) | 8h |

### Sprint siguiente — Medios
M1-M15, esfuerzo total estimado: 12h

---

**Total hallazgos: 55** (18 críticos, 22 altos, 15 medios)
**Esfuerzo estimado total: ~50 horas**
**Próxima auditoría recomendada: 9 de junio de 2026**
