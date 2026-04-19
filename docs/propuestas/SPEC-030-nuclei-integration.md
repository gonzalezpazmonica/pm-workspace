---
id: SPEC-030
title: SPEC-030: Nuclei Scanner Integration
status: Proposed
origin_date: "2026-03-23"
migrated_at: "2026-04-19"
migrated_from: body-prose
---

# SPEC-030: Nuclei Scanner Integration

> Status: **DRAFT** · Fecha: 2026-03-23 · Score: 4.50
> Origen: Análisis de usestrix/strix — scanner de vulnerabilidades
> Impacto: Complementa análisis LLM con detección de CVEs conocidos

---

## Problema

Nuestros agentes de seguridad (security-attacker, pentester) analizan código
mediante LLM. Son excelentes para vulnerabilidades lógicas y contextuales,
pero pueden pasar por alto CVEs conocidos, misconfiguraciones estándar y
paneles expuestos que un scanner basado en templates detectaría en segundos.

Nuclei (projectdiscovery.io) tiene +8000 templates comunitarios y es el
scanner más usado en pentesting moderno. Strix lo preinstala como herramienta
base.

## Solución

Crear un skill `nuclei-scanning` que integre Nuclei como fuente complementaria
de hallazgos para el pipeline adversarial, con degradación graceful si Nuclei
no está instalado.

## Arquitectura

```
/security-pipeline
  |
  +-- security-attacker (LLM, análisis de código)
  |
  +-- nuclei-scanning (scanner, análisis de superficie)  <-- NUEVO
  |
  +-- Merge hallazgos (dedup por CWE/CVE)
  |
  +-- security-defender (fixes para hallazgos combinados)
  |
  +-- security-auditor (evaluación final)
```

## Skill: nuclei-scanning

```
.claude/skills/nuclei-scanning/
  SKILL.md        -- Instrucciones de uso
  DOMAIN.md       -- Por que existe, conceptos
  templates/      -- Subset curado de templates (opcional)
```

### Flujo del skill

```bash
# 1. Verificar instalación
which nuclei || echo "Nuclei no instalado — degradación graceful"

# 2. Si existe, ejecutar scan
nuclei -u {target_url} \
  -severity critical,high,medium \
  -silent -json \
  -rate-limit 50 \
  -timeout 10 \
  -o output/security/nuclei-{fecha}.json

# 3. Parsear resultados JSON
# Cada hallazgo tiene: template-id, severity, matched-at, curl-command

# 4. Deduplicar contra hallazgos del security-attacker
# Mapeo: nuclei template-id -> CWE -> hallazgo LLM

# 5. Hallazgos únicos de Nuclei se añaden al informe
```

### Degradación graceful

| Nuclei instalado | Target accesible | Resultado |
|-----------------|------------------|-----------|
| Sí | Sí | Scan completo |
| Sí | No | Solo templates de config (sin red) |
| No | - | Skip con aviso: "Instala nuclei para scan complementario" |

## Instalación de Nuclei

```bash
# Go install
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest

# O binario directo
curl -sL https://github.com/projectdiscovery/nuclei/releases/latest/download/nuclei_linux_amd64.zip -o nuclei.zip
unzip nuclei.zip && mv nuclei /usr/local/bin/
```

## Templates curados

Mantener subset en `templates/` para uso offline:
- `cves/` — CVEs críticos recientes (top 50)
- `misconfigurations/` — CORS, headers, TLS
- `exposed-panels/` — Admin panels, debug endpoints
- `default-logins/` — Credenciales por defecto

Total: ~200 templates vs +8000 del repo completo. Actualización trimestral.

## Integración con scoring

Los hallazgos de Nuclei usan el mismo scoring:
`score = 100 - (critical x 25 + high x 10 + medium x 3 + low x 1)`

Se marcan con `source: nuclei` para distinguirlos de `source: llm`.

## Restricciones

- NUNCA ejecutar Nuclei contra produccion sin confirmación explícita
- Respetar rate-limit (50 req/s por defecto)
- Respetar reglas por entorno del pentester (DEV: todo, PRE: sin DoS, PROD: pasivo)
- Templates custom solo en `templates/` del skill, no descargar automáticamente

## Esfuerzo estimado

Bajo — 1 día. Nuclei es un binario standalone. El skill solo invoca y parsea.
