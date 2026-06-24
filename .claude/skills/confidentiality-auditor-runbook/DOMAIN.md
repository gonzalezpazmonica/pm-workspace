# confidentiality-auditor-runbook — Domain

Auxiliar del agente `confidentiality-auditor`. Contiene el protocolo
de descubrimiento dinamico de contexto sensible (Fase 1b), los criterios
de auditoria por nivel (N1/N4-SHARED/N4-SUPPLIER/N4b-PM) y las reglas
de variantes y exclusiones.

## Uso

Cargar cuando `confidentiality-auditor` necesita construir el diccionario
de datos sensibles o verificar los criterios CRITICAL/WARNING/exclusion
para un nivel especifico de repo.

## Relacion con el agente

- Agente: `.opencode/agents/confidentiality-auditor.md`
- Este skill: Fase 1b discovery, criterios por nivel, variantes, exclusiones
- Firma de auditoria: `scripts/confidentiality-sign.sh`
