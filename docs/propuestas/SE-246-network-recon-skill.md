---
id: SE-246
title: "Network recon skill — nmap/RustScan + httpx + Masscan para proyectos con infraestructura propia"
status: PROPOSED
priority: P2
effort: M (12h — S1 3h + S2 4h + S3 5h)
origin: Análisis defensivo hackingtool-plugin (AKCodez, 2026-06-28)
author: Savia
related:
  - SE-243 (attack-surface-mapping — dominios/OSINT, previo al recon de red)
  - SE-245 (dynamic-web-security-testing — testing de endpoints descubiertos)
  - pentesting skill (usa network recon como Fase 1)
  - security-attacker agent
proposed_at: "2026-06-28"
era: 237
tools_from_hackingtool:
  - nmap
  - RustScan
  - httpx
  - Masscan
---

# SE-246 — Network recon skill

## Problema

Los proyectos generados por Savia con infraestructura propia (servidores, contenedores,
VMs) no tienen ningún mecanismo de reconocimiento de red para verificar qué superficie
de ataque exponen a nivel de puertos y servicios:

- Un servidor puede tener puertos administrativos abiertos (SSH, MySQL, PostgreSQL)
  accesibles desde internet por misconfiguration del firewall
- Los manifiestos de infraestructura del `infrastructure-agent` pueden generar
  configuraciones que exponen más puertos de los necesarios
- El `terraform-developer` puede generar security groups con reglas de ingress permisivas
  que Trivy (SE-241) detecta en el código pero que luego no se verifican contra la
  infraestructura real desplegada
- httpx permite verificar qué URLs responden en los hosts que SE-243 descubre, pero
  SE-243 no hace verificación de red directa

No existe un skill de reconocimiento de red para verificar la postura de seguridad
de la infraestructura de los proyectos que Savia gestiona.

## Tesis

Un skill `network-recon` que ejecuta reconocimiento de red controlado sobre rangos de
IPs o hosts del propio proyecto: RustScan/Masscan para descubrimiento rápido de puertos,
nmap para fingerprinting de servicios, y httpx para verificación de servicios HTTP/HTTPS.
Actúa sobre infraestructura propia con autorización, alimenta al `pentesting` skill.

## Herramientas

| Herramienta | Qué hace | Modo de uso en Savia | Offline |
|---|---|---|---|
| nmap | Port scanning + service fingerprinting + OS detection | `nmap -sV -sC --top-ports 1000 -oJ <output> <target>` | Sí (binario local) |
| RustScan | Port scanning ultra-rápido (3000 ports/sec); pasa resultados a nmap | `rustscan -a <target> -- -sV -sC` | Sí (binario local) |
| Masscan | Scanning masivo de rangos de red amplios | `masscan <range> -p 80,443,22,3306 --rate 1000 -oJ <output>` | Sí (binario local) |
| httpx | Verifica servicios HTTP/HTTPS activos en lista de hosts/IPs | `httpx -l hosts.txt -json -o httpx.json -status-code -title -tech-detect` | Sí (Go binary local) |

**Elección por escenario**:
- Target único (1-10 hosts): RustScan → nmap (rápido + detallado)
- Rango de IPs amplio: Masscan → nmap sólo en puertos abiertos
- Verificación HTTP: httpx siempre, sobre output de RustScan/Masscan

## Diseño

### Principio fundamental

NUNCA escanear IPs de terceros sin autorización explícita.
Gate de autorización idéntico al de SE-243 y SE-245.

### Integración en pipeline Savia

```
Fase: Post-deploy verification | Pre-pentest recon | Auditoría periódica
Trigger: /network-recon <target> | pentesting skill Fase 1 | post-deploy
```

### Gate de autorización

Fichero `output/security/authorization-{target}.txt` con scope (hostname o descripción
del rango), fecha y firma. Sin este fichero, el script aborta. El target se referencia
por hostname o alias — nunca se almacena el rango IP en ficheros versionados.

### Script principal: `scripts/security/network-recon.sh`

- Parámetro: `--target <hostname|alias>` (alias resuelto desde config local git-ignorada)
- Parámetro: `--mode quick|standard|full` (default: standard)
- Modo quick: RustScan top-1000 puertos (< 2 min para un host)
- Modo standard: RustScan + nmap -sV top-1000 (< 5 min)
- Modo full: Masscan all-ports + nmap -sV -sC en puertos abiertos (puede tardar > 30 min)
- Parámetro: `--http-check` activa httpx sobre hosts con puertos web abiertos
- Rate limiting: `--rate <n>` (default: 1000 pps — conservador para no saturar)

La resolución del target a IP se hace en runtime desde configuración local git-ignorada
(`.claude/rules/pm-config.local.md`). Las IPs nunca se hardcodean en scripts versionados.

### Output

```
output/security/network-recon-{alias}-YYYYMMDD/
  ports-open.txt          # lista de host:puerto abiertos (sin IPs en el nombre)
  services.json           # servicios identificados por nmap
  http-services.json      # URLs HTTP/HTTPS activas (httpx)
  summary.md              # resumen: X hosts, Y puertos, Z servicios críticos
```

**Servicios críticos**: alertas si se detectan puertos de base de datos o administración
accesibles desde interfaces de red no esperadas. Los puertos específicos se configuran
en `.savia-critical-ports.txt` (no hardcodeados en el script).

### Integración con pentesting skill

El `pentesting` skill usa `network-recon.sh` en Fase 1 (reconocimiento). El output
`services.json` alimenta directamente la Fase 2 (enumeración de servicios).

### Rate limiting conservador

Para prevenir DoS accidental en la propia infraestructura:
- Masscan: `--rate 1000` por defecto, máximo configurable 10000
- nmap: `-T3` (normal) por defecto; sin `-T5` (agresivo)
- RustScan: `--batch-size 2500` por defecto

## Slices

**S1 — RustScan + nmap (modo standard) (3h)**
- `scripts/security/network-recon.sh` modo standard
- Gate de autorización
- Output `ports-open.txt` + `services.json`
- BATS tests contra localhost con puertos conocidos

**S2 — Masscan (modo full) + httpx (4h)**
- Modo full con Masscan
- httpx para detección de servicios HTTP
- Rate limiting configurable
- `.savia-critical-ports.txt` configurable

**S3 — Skill + integración pentesting + alertas de servicios críticos (5h)**
- `.opencode/skills/network-recon/SKILL.md`
- Comando `/network-recon [target-alias]`
- Alertas de servicios críticos
- Integración con pentesting skill (export services.json)
- Documentación de rate limiting y riesgo de DoS

## Criterios de aceptación

- [ ] El script aborta sin `authorization-{target}.txt`
- [ ] RustScan + nmap descubren puertos abiertos en localhost (los activos en el momento)
- [ ] httpx detecta servicios HTTP activos en lista de hosts provista
- [ ] Alerta generada cuando un puerto crítico está abierto en interfaz inesperada
- [ ] Rate Masscan limitado a 1000 pps por defecto (verificable en logs)
- [ ] nmap usa `-T3` por defecto
- [ ] Report en `output/security/network-recon-*/` con estructura documentada
- [ ] `output/security/` verificado en .gitignore antes de escribir
- [ ] Skill invocable con `/network-recon staging-server`
- [ ] Modo quick completa en < 2 minutos para un único host

## Qué NO incluye

- Explotación de servicios descubiertos — sólo reconocimiento y fingerprinting
- Escaneo de IPs de terceros sin autorización
- NSE scripts de nmap agresivos (brute force, exploit) — sólo `-sV -sC`
- Monitorización continua de puertos — extensión futura
- Reconocimiento de subdominios o OSINT — eso es SE-243
- Testing de vulnerabilidades en servicios descubiertos — eso es SE-245
