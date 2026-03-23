# SPEC-030: Nuclei Scanner Integration

> Status: **DRAFT** · Fecha: 2026-03-23 · Score: 4.50
> Origen: Analisis de usestrix/strix — scanner de vulnerabilidades
> Impacto: Complementa analisis LLM con deteccion de CVEs conocidos

---

## Problema

Nuestros agentes de seguridad (security-attacker, pentester) analizan codigo
mediante LLM. Son excelentes para vulnerabilidades logicas y contextuales,
pero pueden pasar por alto CVEs conocidos, misconfiguraciones estandar y
paneles expuestos que un scanner basado en templates detectaria en segundos.

Nuclei (projectdiscovery.io) tiene +8000 templates comunitarios y es el
scanner mas usado en pentesting moderno. Strix lo preinstala como herramienta
base.

## Solucion

Crear un skill `nuclei-scanning` que integre Nuclei como fuente complementaria
de hallazgos para el pipeline adversarial, con degradacion graceful si Nuclei
no esta instalado.

## Arquitectura

```
/security-pipeline
  |
  +-- security-attacker (LLM, analisis de codigo)
  |
  +-- nuclei-scanning (scanner, analisis de superficie)  <-- NUEVO
  |
  +-- Merge hallazgos (dedup por CWE/CVE)
  |
  +-- security-defender (fixes para hallazgos combinados)
  |
  +-- security-auditor (evaluacion final)
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
# 1. Verificar instalacion
which nuclei || echo "Nuclei no instalado — degradacion graceful"

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

# 5. Hallazgos unicos de Nuclei se anaden al informe
```

### Degradacion graceful

| Nuclei instalado | Target accesible | Resultado |
|-----------------|------------------|-----------|
| Si | Si | Scan completo |
| Si | No | Solo templates de config (sin red) |
| No | - | Skip con aviso: "Instala nuclei para scan complementario" |

## Instalacion de Nuclei

```bash
# Go install
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest

# O binario directo
curl -sL https://github.com/projectdiscovery/nuclei/releases/latest/download/nuclei_linux_amd64.zip -o nuclei.zip
unzip nuclei.zip && mv nuclei /usr/local/bin/
```

## Templates curados

Mantener subset en `templates/` para uso offline:
- `cves/` — CVEs criticos recientes (top 50)
- `misconfigurations/` — CORS, headers, TLS
- `exposed-panels/` — Admin panels, debug endpoints
- `default-logins/` — Credenciales por defecto

Total: ~200 templates vs +8000 del repo completo. Actualizacion trimestral.

## Integracion con scoring

Los hallazgos de Nuclei usan el mismo scoring:
`score = 100 - (critical x 25 + high x 10 + medium x 3 + low x 1)`

Se marcan con `source: nuclei` para distinguirlos de `source: llm`.

## Restricciones

- NUNCA ejecutar Nuclei contra produccion sin confirmacion explicita
- Respetar rate-limit (50 req/s por defecto)
- Respetar reglas por entorno del pentester (DEV: todo, PRE: sin DoS, PROD: pasivo)
- Templates custom solo en `templates/` del skill, no descargar automaticamente

## Esfuerzo estimado

Bajo — 1 dia. Nuclei es un binario standalone. El skill solo invoca y parsea.
