---
name: adversarial-security
description: Protocolo de seguridad adversarial — Red Team / Blue Team / Auditor
---

# Adversarial Security Protocol

## Principio

La seguridad se verifica mediante adversarialismo controlado: un agente ataca, otro defiende,
un tercero audita. Los tres son independientes entre sí.

## Cuándo ejecutar

- Antes de cada release major (vX.0.0)
- Cuando se añaden nuevas APIs o endpoints
- Cuando se modifican mecanismos de autenticación/autorización
- Cuando se añaden dependencias externas
- Bajo demanda con `/security-pipeline`

## Independencia de agentes

1. **security-attacker** (Red Team): solo lectura, encuentra vulnerabilidades
2. **security-defender** (Blue Team): propone correcciones, no las aplica
3. **security-auditor**: evalúa ambos, genera score final

Ningún agente ve el trabajo del otro antes de completar el suyo (excepto el auditor,
que ve ambos al final).

## Clasificación de severidad

- **Critical**: explotable remotamente, sin autenticación, acceso a datos sensibles
- **High**: explotable con baja complejidad, impacto significativo
- **Medium**: requiere condiciones específicas, impacto moderado
- **Low**: impacto menor, difícil de explotar
- **Info**: mejora recomendada, sin riesgo inmediato

## Score de seguridad

score = 100 - (critical×25 + high×10 + medium×3 + low×1)
Mínimo: 0. Cada fix verificado recupera los puntos de su VULN.

## Integración con compliance

- Los hallazgos critical/high bloquean merge a main (si compliance-gate está activo)
- Los informes se guardan en `projects/{proyecto}/security/`
- El security-guardian existente sigue operando en pre-commit (complementario)
