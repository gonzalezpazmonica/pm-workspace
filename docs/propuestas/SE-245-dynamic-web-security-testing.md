---
id: SE-245
title: "Dynamic web security testing — sqlmap + DalFox para endpoints generados por agentes"
status: IMPLEMENTED
priority: P2
effort: L (16h — S1 4h + S2 4h + S3 4h + S4 4h)
origin: Análisis defensivo hackingtool-plugin (AKCodez, 2026-06-28)
author: Savia
related:
  - nuclei-scanning skill (CVEs/misconfigs — complementario, no duplica)
  - adversarial-security skill (Red Team pipeline)
  - security-attacker/defender agents
  - SE-242 (tls-web-security-headers — TLS/headers, no SQLi/XSS)
  - SE-243 (attack-surface-mapping — reconocimiento previo)
proposed_at: "2026-06-28"
resolved_at: "2026-07-02"
implementation_pr: "#890"
era: 237
tools_from_hackingtool:
  - sqlmap
  - DalFox
---

# SE-245 — Dynamic web security testing

## Problema

El `security-judge` del Code Review Court realiza análisis estático del código fuente para
detectar patrones de SQLi, XSS y otras vulnerabilidades. Este análisis tiene límites
inherentes:

- No detecta vulnerabilidades introducidas por el ORM o framework (ej: una query string
  mal construida que el ORM genera, no el desarrollador)
- No verifica el comportamiento real del endpoint en runtime
- No detecta reflected XSS en respuestas dinámicas generadas por templating
- No prueba endpoints de terceros integrados ni la lógica de autorización real
- `nuclei-scanning` cubre CVEs conocidos de tecnologías pero no vulnerabilidades
  específicas de la lógica de negocio de la aplicación

Los proyectos generados por dotnet-developer, python-developer y typescript-developer
tienen endpoints HTTP que nunca se testean dinámicamente contra SQLi ni XSS antes de deploy.

## Tesis

Un skill `dynamic-web-security-test` que ejecuta testing dinámico controlado contra
endpoints web (en entorno de staging, nunca en producción directamente) usando sqlmap
para SQL injection y DalFox para XSS. El skill actúa sobre una instancia del proyecto
levantada localmente o en staging, con autorización explícita, y complementa — no reemplaza —
el análisis estático del Court.

## Herramientas

| Herramienta | Qué hace | Modo de uso en Savia | Offline |
|---|---|---|---|
| sqlmap | Detección y explotación automática de SQL injection en parámetros HTTP | `sqlmap -u <url> --forms --batch --level=2 --risk=1 --output-dir=<dir>` | Sí (Python local) |
| DalFox | Detección de XSS (reflected, DOM, stored) en endpoints web | `dalfox url <url> --output <file> --format json --silence` | Sí (Go binary local) |

**Parámetros conservadores**:
- sqlmap `--level=2 --risk=1`: detecta SQLi obvias sin payloads destructivos
- sqlmap `--technique=B,E,U`: blind, error-based, union — NO time-based ni stacked (riesgo de DoS)
- DalFox `--silence`: sólo findings, sin output verbose

## Diseño

### Principio fundamental

**NUNCA ejecutar contra producción directamente.** El gate de autorización y el gate
de entorno son bloqueantes. El skill está diseñado para staging o entorno local.

### Integración en pipeline Savia

```
Fase: Pre-deploy (staging) | Auditoría de seguridad explícita
Trigger: /dynamic-security-test <base_url> | adversarial-security skill fase dinámica
Prerequisito: autorización explícita + entorno staging confirmado
```

### Gates de seguridad (doble)

**Gate 1 — Autorización**: fichero `output/security/authorization-{host}.txt`
con scope, fecha y firma (igual que SE-243).

**Gate 2 — Entorno**: el script verifica que la URL no es un dominio de producción
conocido. Lista configurable en `.savia-prod-domains.txt`. Si el host coincide, aborta.
Para override explícito: flag `--i-know-this-is-staging` con registro en audit log.

### Script principal: `scripts/security/dynamic-web-security-test.sh`

- Parámetros: `--url <base_url>` (ej: `http://localhost:8080`)
- Parámetro: `--endpoints <file>` (lista de endpoints a testear, uno por línea)
- Parámetro: `--tools sqlmap|dalfox|both` (default: both)
- Ejecuta ambas herramientas con parámetros conservadores
- Genera report en `output/security/dynamic-test-YYYYMMDD-{host}/`
- Summary: N endpoints testeados, X vulnerabilidades encontradas por tipo

### Modo de descubrimiento de endpoints

Si no se provee `--endpoints`, el script invoca `dalfox --crawl` para descubrir
formularios y parámetros automáticamente. sqlmap usa `--crawl=2` para formularios.
El crawling es limitado (depth=2, max 50 URLs) para evitar DoS accidental.

### Integración con adversarial-security skill

El `adversarial-security` skill puede invocar `dynamic-web-security-test.sh` en su
fase de testing dinámico. Los findings se consolidan en el report Red Team del skill.

### Integración con security-attacker agent

El `security-attacker` agent puede invocar el script con los endpoints descubiertos
por SE-243 (attack-surface-mapping) para una cobertura end-to-end del pentest.

### Confidencialidad

Los reports de dynamic testing son N3: contienen exploits y evidencias de vulnerabilidades.
Bajo ninguna circunstancia incluir en repos públicos.

## Slices

**S1 — sqlmap integration + gates (4h)**
- `scripts/security/dynamic-web-security-test.sh` con sólo sqlmap
- Gate de autorización (fichero)
- Gate de entorno (no-producción)
- BATS tests contra DVWA local (Damn Vulnerable Web App)

**S2 — DalFox integration (4h)**
- Añadir DalFox al script
- Report consolidado JSON
- Tests contra DVWA endpoints XSS conocidos

**S3 — Crawling + endpoint discovery (4h)**
- Modo `--crawl` para descubrimiento automático de endpoints
- Limitación de profundidad y URLs
- Integración con output de SE-243 (subdomains.txt)

**S4 — Skill + comando + integración adversarial-security (4h)**
- `.opencode/skills/dynamic-web-security-test/SKILL.md`
- Comando `/dynamic-security-test [url]`
- Integración con `adversarial-security` skill
- Documentación del doble gate y entorno DVWA de prueba

## Criterios de aceptación

- [ ] El script aborta sin `authorization-{host}.txt`
- [ ] El script aborta si el host está en `.savia-prod-domains.txt`
- [ ] sqlmap detecta SQLi en DVWA login endpoint (SQLi conocido)
- [ ] DalFox detecta reflected XSS en DVWA XSS reflected endpoint
- [ ] Parámetros conservadores aplicados: `--level=2 --risk=1` para sqlmap
- [ ] Report JSON en `output/security/dynamic-test-*/`
- [ ] `output/security/` verificado en .gitignore
- [ ] El crawl automático no supera 50 URLs (verificable en logs)
- [ ] Skill invocable con `/dynamic-security-test http://localhost:8080`

## Qué NO incluye

- Testing en producción sin override explícito + audit log
- Explotación de vulnerabilidades encontradas (extracción de datos, shell) — detección sólo
- Testing de autenticación/autorización avanzada (IDOR, JWT attacks) — extensión futura
- Fuzzing de APIs REST/GraphQL — extensión futura
- Integración con Burp Suite — herramienta propietaria, fuera de principio provider-agnostic
- nuclei templates (CVEs conocidos de tech stack) — ya cubierto por `nuclei-scanning` skill
