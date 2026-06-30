---
context_tier: L3
token_budget: 900
resource: internal://docs/rules/domain/security-benchmark-protocol.md
spec_ref: SPEC-032
---

# Security Benchmark Protocol — SPEC-032

> Framework de evaluacion objetiva para los agentes de seguridad de Savia.

## Cuando usar

- Antes y despues de cambiar prompts de security-attacker, security-guardian o pentester.
- En CI mensual para detectar regresiones.
- Al añadir un nuevo agente de seguridad.

## Como ejecutar

### Modo local (sin Docker)

```bash
# Benchmark rapido contra fixtures locales
bash scripts/security-benchmark-runner.sh --target local

# Modo mock explicito (identico, sin side effects)
bash scripts/security-benchmark-runner.sh --mock

# Con output a fichero
bash scripts/security-benchmark-runner.sh --mock --output /tmp/bench-results.json
```

### Modo Docker (requiere Docker corriendo)

```bash
# Juice Shop (recomendado — 100+ vulnerabilidades conocidas)
bash scripts/security-benchmark-runner.sh --target juice-shop

# DVWA
bash scripts/security-benchmark-runner.sh --target dvwa

# WebGoat
bash scripts/security-benchmark-runner.sh --target webgoat
```

### Comparar con ejecucion anterior

```bash
# Compara la ejecucion actual con la del 2026-06-01
bash scripts/security-benchmark-runner.sh --mock --compare 20260601
```

## Interpretar resultados

El runner produce un JSON con los siguientes campos:

| Campo | Descripcion |
|---|---|
| `detection_rate` | Vulnerabilidades detectadas / total conocidas |
| `false_positive_rate` | Falsos positivos / total hallazgos |
| `score` | `detection_rate * (1 - false_positive_rate)` |
| `pass` | `true` si cumple ambos thresholds |

### Thresholds minimos

| Metrica | Threshold | Razon |
|---|---|---|
| `detection_rate` | **>= 0.70** | Minimo aceptable: 7 de cada 10 vulns conocidas detectadas |
| `false_positive_rate` | **<= 0.30** | Maximo 30% de hallazgos son falsos positivos |

Un agente que baja de 0.70 en detection_rate o sube de 0.30 en FPR requiere revision del prompt.

### Metricas de precision/recall

```bash
# Primero genera un fichero de hallazgos reales del agente:
# (Este JSON debe ser generado por el agente de seguridad)
# Formato: {"findings": [{"id": "X", "cwe": "CWE-89", ...}]}

python3 scripts/security-benchmark-metrics.py \
    --actual /tmp/agent-findings.json \
    --expected tests/fixtures/security-benchmark/expected-findings.json
```

Metricas calculadas:

| Metrica | Formula | Meta |
|---|---|---|
| Precision | TP / (TP + FP) | > 0.70 |
| Recall | TP / (TP + FN) | > 0.70 |
| F1 | 2 * P * R / (P + R) | > 0.70 |
| False Negative Count | Total missed | < 2 en criticos |

## Anadir nueva app target

1. Añadir imagen Docker a `DOCKER_IMAGES` en `security-benchmark-runner.sh`.
2. Crear directorio `tests/security-benchmarks/targets/{app-name}/`.
3. Crear `known-vulns.yaml` con lista de CWEs y paths.
4. Actualizar `tests/fixtures/security-benchmark/expected-findings.json` si aplica.
5. Documentar el puerto en `DOCKER_PORTS`.

### Formato known-vulns.yaml

```yaml
- id: "JS-001"
  name: "SQL Injection in search"
  cwe: "CWE-89"
  severity: "critical"
  path: "/rest/products/search?q="
  description: "Union-based SQLi in product search"
  detectable_by: [security-attacker, pentester, nuclei]
```

## Resultados historicos

Los resultados se guardan en `output/security-benchmarks/` con formato
`YYYYMMDD-HHMMSS-{target}.json`.

Para ver el historial:

```bash
ls -la output/security-benchmarks/
```

## Dependencias

- Python 3.8+: para el runner y metrics script
- Docker (opcional): para targets remotos
- Nuclei (SPEC-030, opcional): benchmark completo con escaner de infraestructura
- Agentes Savia: security-attacker, security-guardian, pentester (para benchmarks LLM)

## Ver tambien

- `scripts/security-benchmark-runner.sh` — runner principal
- `scripts/security-benchmark-metrics.py` — calculo de precision/recall/F1
- `tests/fixtures/security-benchmark/` — fixtures locales
- `docs/propuestas/SPEC-032-security-benchmarks.md` — spec completa
