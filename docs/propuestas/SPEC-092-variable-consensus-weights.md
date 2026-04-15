---
spec_id: SPEC-092
title: Variable Consensus Weights — pesos por tipo de tarea
status: Implemented
origin: llmfit research (2026-04-08)
severity: Media
effort: ~1h
---

# SPEC-092: Variable Consensus Weights

## Problema

consensus-protocol.md usa pesos fijos para los 3 jueces:
- reflection-validator: 40%
- code-reviewer: 30%
- business-analyst: 30%

Pero no todas las specs tienen el mismo perfil de riesgo. Una spec de
seguridad debería ponderar más al code-reviewer. Una spec de UX debería
ponderar más al business-analyst.

llmfit parametriza pesos por caso de uso (Reasoning: Quality 55% + Speed 15%).

## Solución

Definir 4 perfiles de pesos en consensus-protocol.md:

```
| Perfil | reflection | code | business | Cuándo |
|--------|-----------|------|----------|--------|
| default | 0.40 | 0.30 | 0.30 | Specs genéricas, CRUD |
| security | 0.30 | 0.50 | 0.20 | Auth, pagos, PII, APIs públicas |
| business | 0.25 | 0.25 | 0.50 | Reglas de negocio complejas, cálculos |
| architecture | 0.50 | 0.30 | 0.20 | Infraestructura, migraciones, patrones |
```

Selección automática por keywords en la spec:
- auth|security|token|encrypt|PII → security
- rule|calculation|price|discount|tax → business
- migration|infrastructure|deploy|scale → architecture
- default si ninguno matchea

## Criterios de aceptación

- [ ] consensus-protocol.md actualizado con 4 perfiles
- [ ] Tabla de keywords → perfil documentada
- [ ] Si consensus-validation skill tiene lógica de pesos, actualizarla
- [ ] Detección automática por keywords del spec
