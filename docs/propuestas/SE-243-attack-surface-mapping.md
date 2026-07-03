---
id: SE-243
title: "Attack surface mapping — Amass + Subfinder + theHarvester + SpiderFoot + dnstwist"
status: IMPLEMENTED
priority: P2
effort: M (12h — S1 3h + S2 4h + S3 5h)
origin: Análisis defensivo hackingtool-plugin (AKCodez, 2026-06-28)
author: Savia
related:
  - pentesting skill (pentest dinámico 5 fases)
  - adversarial-security skill
  - security-attacker agent
  - SE-246 (network-recon-skill — reconocimiento de red, complementario)
proposed_at: "2026-06-28"
resolved_at: "2026-07-02"
implementation_pr: "#890"
era: 237
tools_from_hackingtool:
  - Amass
  - Subfinder
  - theHarvester
  - SpiderFoot
  - dnstwist
---

# SE-243 — Attack surface mapping

## Problema

Savia ayuda a construir y auditar proyectos que tienen presencia en internet (dominios,
subdominios, APIs, servicios cloud), pero no tiene mecanismo para mapear qué superficie
de ataque expone un proyecto dado desde la perspectiva de un atacante externo:

- El `pentesting` skill asume que ya se conocen los endpoints objetivo — no los descubre
- El `security-attacker` agent opera sobre código fuente, no sobre la infraestructura real
- No hay enumeración de subdominios (un subdominio olvidado puede ser el vector de entrada)
- No hay detección de dominios typosquatting que imiten los proyectos de Savia (riesgo de
  phishing contra usuarios finales)
- theHarvester tipo OSINT sobre emails, personas y tecnologías del proyecto no está integrado

Sin este mapeo previo, un pentest de Savia es incompleto: ataca lo que conoce, no
necesariamente lo que está expuesto.

## Tesis

Un skill `attack-surface-mapping` que ejecuta OSINT y enumeración pasiva/activa sobre
un dominio objetivo antes de un pentest o auditoría de seguridad. Las herramientas operan
en modo reconocimiento (no explotación) y generan un mapa de superficie que alimenta
al `pentesting` skill y al `security-attacker` agent.

**Distinción crítica**: este skill actúa sobre dominios/infraestructura del propio proyecto
bajo auditoría, con autorización explícita del propietario. No es para reconocimiento
de terceros sin autorización.

## Herramientas

| Herramienta | Qué hace | Modo de uso en Savia | Offline |
|---|---|---|---|
| Amass | Enumeración de subdominios con resolución DNS activa + fuentes OSINT | `amass enum -d ejemplo.com -json amass.json` | Parcial (DNS activo, OSINT requiere APIs) |
| Subfinder | Enumeración pasiva de subdominios via múltiples fuentes | `subfinder -d ejemplo.com -o subs.txt` | Parcial (fuentes pasivas, sin API keys funciona limitado) |
| theHarvester | OSINT: emails, empleados, IPs, subdominios, tecnologías | `theHarvester -d ejemplo.com -b all -f harvest.html` | Parcial (sin API keys funciona con bing, baidu, certs) |
| SpiderFoot | Automatización OSINT avanzada: 200+ módulos, correlaciones | `sfcli.py -s ejemplo.com -t DOMAIN_NAME -q -o json` | Parcial (módulos sin API funcionan offline) |
| dnstwist | Detecta dominios typosquatting/phishing que imitan el dominio objetivo | `dnstwist --registered --format json ejemplo.com` | Sí (DNS lookup local) |

**Modo offline-first**: las herramientas con fuentes pasivas (dnstwist, Amass DNS,
Subfinder sin APIs) funcionan localmente. Las fuentes OSINT de theHarvester/SpiderFoot
requieren conectividad pero no API keys de pago para una cobertura básica.

## Diseño

### Integración en pipeline Savia

```
Fase: Pre-pentest (reconocimiento) | Auditoría periódica trimestral
Trigger: /map-attack-surface <domain> | inicio del pentesting skill
Prerequisito: Autorización explícita del propietario del dominio (gate obligatorio)
```

### Gate de autorización

**Paso obligatorio antes de cualquier ejecución**:
El script verifica que existe un fichero `output/security/authorization-{domain}.txt`
firmado con la fecha de autorización y el scope. Sin este fichero, el script aborta.
Esto previene uso accidental o malicioso contra dominios de terceros.

### Script principal: `scripts/security/map-attack-surface.sh`

- Parámetro: `--domain <target>` (ej: `ejemplo.com`)
- Parámetro: `--mode passive|active|full` (default: passive)
- Modo passive: sólo fuentes pasivas + DNS (sin envío de requests al target)
- Modo active: incluye Amass con resolución DNS directa al target
- Modo full: todo, incluyendo theHarvester + SpiderFoot
- Genera report consolidado en `output/security/attack-surface-{domain}-YYYYMMDD/`
- Output: subdominios descubiertos, emails encontrados, dominios typosquatting registrados,
  tecnologías identificadas, IPs asociadas

### Report structure

```
attack-surface-{domain}-YYYYMMDD/
  subdomains.txt          # lista deduplicada de subdominios
  emails.txt              # emails OSINT (sin secrets)
  technologies.json       # stack tecnológico detectado
  typosquatting.json      # dominios similares registrados (dnstwist)
  summary.md              # resumen ejecutivo para humano
  raw/                    # outputs raw de cada herramienta
```

### Integración con pentesting skill

El `pentesting` skill puede invocar `map-attack-surface.sh` en su Fase 1 (reconocimiento)
usando `subdomains.txt` como input para las fases posteriores.

### Confidencialidad

Los reports de attack surface son N3: contienen información de infraestructura del proyecto
que no debe exponerse públicamente.

## Slices

**S1 — dnstwist + Subfinder (passive) (3h)**
- `scripts/security/map-attack-surface.sh` con modo passive
- Gate de autorización
- dnstwist para typosquatting
- Subfinder sin API keys
- BATS tests con dominio de prueba propio

**S2 — Amass + theHarvester (active/full) (4h)**
- Modo active con Amass DNS enum
- theHarvester con fuentes gratuitas (bing, baidu, certs.sh)
- SpiderFoot en modo básico (sin API keys)
- Deduplicación y consolidación del report

**S3 — Skill + integración con pentesting + comando (5h)**
- `.opencode/skills/attack-surface-mapping/SKILL.md`
- Comando `/map-attack-surface [domain]`
- Integración con `pentesting` skill (export `subdomains.txt` como input)
- Documentación del gate de autorización
- Plantilla `authorization-{domain}.txt`

## Criterios de aceptación

- [ ] El script aborta si no existe `output/security/authorization-{domain}.txt`
- [ ] dnstwist detecta dominios typosquatting registrados para un dominio de prueba conocido
- [ ] Subfinder descubre subdominios de un dominio de prueba propio con registros públicos
- [ ] Report en `output/security/attack-surface-*/` con estructura documentada
- [ ] `summary.md` legible por humano no técnico
- [ ] Modo passive no envía requests directos al servidor target
- [ ] `output/security/` verificado en .gitignore antes de escribir
- [ ] Integración con pentesting skill: `subdomains.txt` es input válido para la fase 2
- [ ] Documentación incluye instrucciones de instalación de las 5 herramientas

## Qué NO incluye

- Explotación de subdominios descubiertos — sólo reconocimiento
- Reconocimiento de dominios de terceros sin autorización — gate explícito lo previene
- Monitorización continua de nuevos subdominios — auditoría puntual
- Scraping de redes sociales con credenciales — sólo fuentes públicas gratuitas
- Network reconnaissance (puertos, servicios) — eso es SE-246
