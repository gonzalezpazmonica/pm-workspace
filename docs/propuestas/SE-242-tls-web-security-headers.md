---
id: SE-242
title: "TLS/SSL y web security headers — testssl.sh + wafw00f + Nikto"
status: IMPLEMENTED
priority: P1
effort: M (10h — S1 3h + S2 3h + S3 4h)
origin: Análisis defensivo hackingtool-plugin (AKCodez, 2026-06-28)
author: Savia
related:
  - nuclei-scanning skill (CVEs, misconfigs — complementario)
  - adversarial-security skill
  - SE-245 (dynamic-web-security-testing — SQLi/XSS, no TLS)
  - security-auditor agent
proposed_at: "2026-06-28"
resolved_at: "2026-07-02"
implementation_pr: "#890"
era: 237
tools_from_hackingtool:
  - testssl.sh
  - wafw00f
  - Nikto
---

# SE-242 — TLS/SSL y web security headers

## Problema

Los proyectos web generados por Savia (savia-web, proyectos con endpoints HTTP) no tienen
verificación automatizada de su configuración TLS ni de sus security headers. Los gaps
concretos:

- Sin verificación de cipher suites débiles (RC4, DES, EXPORT), versiones TLS obsoletas
  (TLS 1.0/1.1), o certificados expirados/mal configurados
- Sin chequeo de security headers estándar: CSP, HSTS, X-Frame-Options, CORP, COOP,
  Permissions-Policy
- `nuclei-scanning` cubre CVEs conocidos pero no el hardening específico de TLS
- El `security-judge` del Court analiza código fuente, no la configuración del servidor en runtime
- No hay detección de WAF (sabiendo si hay WAF, se ajusta la estrategia de pentest)

Un proyecto con TLS 1.0 activo o sin HSTS puede superar el Code Review Court y
llegar a producción con configuración insegura.

## Tesis

Un skill `tls-web-security-scan` que ejecuta tres herramientas sobre una URL objetivo:
testssl.sh para análisis exhaustivo de TLS, wafw00f para detección de WAF, y Nikto para
escaneo rápido de misconfiguraciones HTTP. El skill es invocable pre-deploy, periódicamente,
o como parte de un pentest.

## Herramientas

| Herramienta | Qué hace | Modo de uso en Savia | Offline |
|---|---|---|---|
| testssl.sh | Análisis completo de TLS: cipher suites, protocolos, certificado, HSTS, HPKP | `testssl.sh --json --severity HIGH <URL>` | Sí (bash script + openssl) |
| wafw00f | Detecta y fingerprinta WAF delante del target | `wafw00f -o json <URL>` | Sí (Python, no requiere cloud) |
| Nikto | Escaneo HTTP: headers de seguridad, archivos sensibles, misconfiguraciones | `nikto -h <URL> -Format json -output <file>` | Sí (Perl script local) |

Las tres herramientas actúan en modo lectura/observación. No modifican el servidor target.
Requieren que el endpoint esté levantado (no son herramientas de análisis estático).

## Diseño

### Integración en pipeline Savia

```
Fase: Pre-deploy + auditoría periódica
Trigger: /tls-scan <URL> | CI post-deploy check | auditoría mensual
Prerequisito: endpoint accesible (staging o producción)
```

**Script principal**: `scripts/security/tls-web-security-scan.sh`
- Parámetro obligatorio: `--url <target>` (ej: `https://app.ejemplo.com`)
- Parámetro opcional: `--severity HIGH|MEDIUM|LOW` (default: HIGH)
- Ejecuta las tres herramientas secuencialmente
- Genera report consolidado en `output/security/tls-scan-YYYYMMDD-{host}.json`
- Summary a stdout: grade TLS (A/B/C/D/F), WAF detected (sí/no), headers missing

**Checks TLS (testssl.sh)**:
- Protocolos: TLS 1.2 mínimo requerido; TLS 1.0/1.1/SSLv3 → CRITICAL
- Cipher suites: prohibidos RC4, DES, EXPORT, NULL; ECDHE recomendado
- Certificado: expiración, CN match, cadena completa, OCSP stapling
- Headers TLS: HSTS con `max-age >= 31536000`, HPKP (informativo)

**Checks HTTP headers (Nikto + análisis custom)**:
- Requeridos: HSTS, X-Content-Type-Options, X-Frame-Options o CSP frame-ancestors
- Recomendados: CSP, CORP, COOP, Permissions-Policy
- Prohibidos: `Server: Apache/2.4.x` (versión expuesta), `X-Powered-By`

**WAF detection (wafw00f)**:
- Output: nombre del WAF si detectado, o "no WAF detected"
- No intenta bypass — sólo detección informativa

### Comando `/tls-scan`

`.opencode/commands/tls-scan.md` — acepta URL, ejecuta el script, muestra resumen.
Integración con `security-auditor` para incluir el grade TLS en auditorías de seguridad.

### Umbrales y grading

Grade TLS inspirado en SSL Labs (sin depender del servicio externo):
- A: TLS 1.3, ECDHE, HSTS, sin cipher suites débiles
- B: TLS 1.2 mínimo, cipher suites modernas, HSTS
- C: TLS 1.2 pero cipher suites débiles o sin HSTS
- D: TLS 1.1 o 1.0 activo
- F: SSLv3 o certificado inválido

### Confidencialidad

Los reports de TLS pueden contener información sobre la configuración del servidor
en producción — clasificados N3. No incluir en repos públicos.

## Slices

**S1 — testssl.sh integration (3h)**
- `scripts/security/tls-web-security-scan.sh` con sólo testssl.sh
- Parsing del JSON output → grade TLS
- BATS tests contra un servidor local de prueba (nginx con config conocida)

**S2 — wafw00f + Nikto integration (3h)**
- Añadir wafw00f y Nikto al script
- Report consolidado JSON unificando los tres outputs
- Checks de security headers en el parser

**S3 — Skill + comando + grading (4h)**
- `.opencode/skills/tls-web-security-scan/SKILL.md`
- Comando `/tls-scan [url]`
- Algoritmo de grading A/B/C/D/F
- Documentación de setup offline

## Criterios de aceptación

- [ ] testssl.sh detecta TLS 1.0 como CRITICAL en servidor de prueba con TLS 1.0 activo
- [ ] Nikto detecta ausencia de HSTS header en servidor de prueba sin HSTS
- [ ] wafw00f identifica correctamente un Cloudflare WAF en test conocido
- [ ] Report JSON generado en `output/security/` con naming `tls-scan-YYYYMMDD-{host}`
- [ ] Grade TLS A para servidor con TLS 1.3 + ECDHE + HSTS
- [ ] Grade F para servidor con certificado autofirmado vencido
- [ ] Las tres herramientas funcionan offline (sin conectividad a servicios externos de score)
- [ ] `output/security/` verificado en .gitignore antes de escribir
- [ ] El script completa en < 3 minutos por URL en condiciones normales

## Qué NO incluye

- Escaneo de vulnerabilidades CVE sobre el servidor — eso es `nuclei-scanning`
- Testing dinámico de endpoints (SQLi, XSS) — eso es SE-245
- Bypass de WAF ni evasión de detección — sólo detección informativa
- Monitorización continua de expiración de certificados — extensión futura
- Análisis de código fuente de configuración TLS (nginx.conf, etc.) — análisis de runtime
