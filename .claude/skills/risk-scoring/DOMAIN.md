---
name: risk-scoring-domain
context: domain-knowledge
---

# Risk Scoring — Dominio de Negocio

## Por qué existe esta skill

El riesgo en cambios de código es multidimensional. Esta skill cuantifica ese riesgo para automatizar la escalación de reviews sin depender de juicio humano subjetivo.

## Conceptos de dominio

- **Risk Score (0-100)**: Medida normalizada de complejidad + riesgo
- **Review Level**: Intensidad requerida (auto-merge, standard, enhanced, critical)
- **Signal**: Factor observable en metadata de tarea
- **Escalation**: Enrutamiento automático basado en score
- **Override**: Decisión PM para ajustar ±1 nivel (auditable)

## Reglas de negocio

- Code reviews proporcionales al riesgo
- PM puede override automática con justificación
- Cambios de seguridad elevan riesgo automáticamente
- Contribuidores nuevos al módulo = mayor escrutinio

## Decisiones clave

1. 8 factores para capturar riesgo multidimensional
2. Escala 0-100 para granularidad
3. PM override para contexto empresarial
4. Audit trail regulatorio (GDPR, AEPD)
