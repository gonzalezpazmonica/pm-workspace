# SPEC-032: Security Benchmarks — Evaluación Objetiva de Agentes

> Status: **DRAFT** · Fecha: 2026-03-23 · Score: 4.70
> Origen: Análisis de usestrix/strix — benchmark XBEN (96% en 104 CTFs)
> Impacto: Sin benchmarks no podemos medir ni mejorar nuestros agentes

---

## Problema

pm-workspace tiene 4 agentes de seguridad (attacker, defender, auditor,
pentester) pero no hay forma objetiva de medir su efectividad. No sabemos:

- Qué % de vulnerabilidades detectan vs las que existen
- Cuántos falsos positivos generan
- Si un cambio de prompt mejora o empeora la detección
- Como comparamos contra herramientas como Strix (96% en XBEN)

Sin benchmarks, cualquier mejora es anecdótica.

## Solución

Framework de benchmarks con aplicaciones vulnerables de referencia,
métricas estandarizadas y ejecución periódica.

## Targets de referencia

| App | Vulnerabilidades | Stack | Docker |
|-----|-----------------|-------|--------|
| OWASP Juice Shop | 100+ challenges | Node.js/Angular | `bkimminich/juice-shop` |
| DVWA | 14 categorías | PHP/MySQL | `vulnerables/web-dvwa` |
| WebGoat | 30+ lecciones | Java/Spring | `webgoat/webgoat` |

Empezar con Juice Shop (la mas completa y mantenida).

## Métricas

### Detection Rate (principal)
```
detection_rate = vulns_encontradas / vulns_conocidas * 100
```

Por severidad: critical, high, medium, low.
Por categoria: injection, auth, xss, ssrf, config, crypto.

### False Positive Rate
```
fpr = falsos_positivos / total_hallazgos * 100
```

Un hallazgo es falso positivo si no se puede reproducir contra la app.

### Tiempo de ejecución
```
tiempo_total = tiempo_attacker + tiempo_defender + tiempo_auditor
```

### Calidad del reporte
Evaluación manual (por ahora): claridad, accionabilidad, precisión.

## Estructura

```
tests/security-benchmarks/
  README.md                    -- Como ejecutar
  docker-compose.yml           -- Levanta apps vulnerables
  targets/
    juice-shop/
      known-vulns.yaml         -- Lista de vulns conocidas con CWE
      expected-findings.yaml   -- Lo que nuestros agentes deberian encontrar
    dvwa/
      ...
  results/
    {YYYYMMDD}-{target}.json   -- Resultados por ejecucion
  scripts/
    run-benchmark.sh           -- Orquesta: up -> scan -> compare -> report
    compare-results.sh         -- Diff entre dos ejecuciones
```

## Formato known-vulns.yaml

```yaml
- id: "JS-001"
  name: "SQL Injection in search"
  cwe: "CWE-89"
  severity: "critical"
  path: "/rest/products/search?q="
  description: "Union-based SQLi in product search"
  detectable_by: [attacker, pentester, nuclei]

- id: "JS-002"
  name: "Reflected XSS in track order"
  cwe: "CWE-79"
  severity: "high"
  path: "/track-result?id="
  description: "Reflected XSS via order tracking"
  detectable_by: [attacker, pentester]
```

## Flujo de ejecución

```bash
# 1. Levantar target
docker compose -f tests/security-benchmarks/docker-compose.yml up -d juice-shop

# 2. Esperar health check
curl --retry 10 --retry-delay 2 http://localhost:3000

# 3. Ejecutar pipeline contra target
# (Savia invoca security-attacker + pentester + nuclei contra localhost:3000)

# 4. Comparar hallazgos vs known-vulns.yaml
# Mapeo por CWE + path

# 5. Generar informe
# output/security-benchmarks/{fecha}-juice-shop.md

# 6. Tear down
docker compose down
```

## Comando

`/security-benchmark [--target juice-shop|dvwa|webgoat] [--compare {fecha}]`

- Sin `--compare`: ejecuta y muestra resultados
- Con `--compare`: ejecuta y diff contra ejecución anterior

## Informe de benchmark

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Security Benchmark — Juice Shop
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Detection Rate ........... 72% (36/50 vulns conocidas)
    Critical ............... 90% (9/10)
    High ................... 80% (12/15)
    Medium ................. 60% (12/20)
    Low .................... 60% (3/5)

  False Positive Rate ...... 8% (3/39 hallazgos)
  Tiempo total ............. 4m 32s

  Por agente:
    security-attacker ...... 28 hallazgos (2m 10s)
    pentester .............. 12 hallazgos (1m 50s)
    nuclei ................. 8 hallazgos (0m 32s)
    (overlap: 12 hallazgos detectados por 2+ agentes)

  vs última ejecución (2026-03-15):
    Detection rate: +5% (67% -> 72%)
    FPR: -2% (10% -> 8%)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Requisitos

- Docker instalado y corriendo
- Puertos 3000, 8080, 9090 disponibles
- Nuclei instalado (SPEC-030) para benchmark completo
- Sin Nuclei: benchmark parcial (solo agentes LLM)

## Esfuerzo estimado

Medio — 1 sprint. Requiere curar la lista de vulns conocidas,
crear docker-compose, script de orquestación y formato de reporte.

## Dependencias

- SPEC-030 (Nuclei) para benchmark completo
- SPEC-029 (Auto-remediation) para medir calidad de fixes
