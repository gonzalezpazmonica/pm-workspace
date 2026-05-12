---
name: nuclei-scanning-domain
description: "Conceptos de dominio del skill nuclei-scanning"
type: domain
---

# Nuclei Scanning — Dominio

## Por que existe esta skill

El analisis de seguridad via LLM es excelente para vulnerabilidades logicas
y contextuales, pero puede pasar por alto CVEs conocidos y misconfiguraciones
estandar que un scanner basado en templates detecta en segundos. Nuclei tiene
+8000 templates comunitarios mantenidos por ProjectDiscovery. Esta skill
cierra ese gap sin reemplazar el analisis LLM.

## Conceptos de dominio

- **Template**: fichero YAML que describe una vulnerabilidad conocida y como
  detectarla (request HTTP + matcher de respuesta)
- **CVE**: vulnerabilidad catalogada con identificador estandar (CVE-YYYY-NNNN)
- **CWE**: categoria de debilidad (CWE-89 = SQL Injection). Usado para
  deduplicar hallazgos entre Nuclei y el LLM
- **Rate limiting**: control de velocidad de requests para no saturar el target
- **Degradacion graceful**: si Nuclei no esta instalado, el pipeline continua
  sin el — nunca bloquea

## Reglas de negocio que implementa

- Scoring de seguridad: `score = 100 - (critical*25 + high*10 + medium*3)`
  (misma formula que adversarial-security.md)
- Restricciones por entorno: DEV libre, PRE sin DoS, PROD solo pasivo
  (alineado con pentester agent)
- Confirmacion obligatoria antes de scan en produccion

## Relacion con otros skills

- **Upstream**: security-attacker (hallazgos LLM) — Nuclei corre en paralelo
- **Downstream**: security-defender (recibe hallazgos combinados para proponer fixes)
- **Paralelo**: adversarial-security (pipeline completo que orquesta ambos)
- **Dependiente**: SPEC-032 security-benchmarks (usa Nuclei para medir detection rate)

## Decisiones clave

- **Complementario, no sustituto**: Nuclei no reemplaza el analisis LLM.
  Ambos cubren espacios diferentes (conocido vs logico)
- **Binario externo, no libreria**: Nuclei se invoca como CLI, no como
  dependencia Python/Node. Esto simplifica instalacion y mantenimiento
- **Degradacion graceful**: sin Nuclei el pipeline funciona igual que antes.
  Nuclei es un bonus, no un requisito
