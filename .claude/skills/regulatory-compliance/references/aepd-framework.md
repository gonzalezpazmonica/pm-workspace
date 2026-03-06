# Framework AEPD — IA Agéntica y Protección de Datos

> Basado en: Orientaciones AEPD sobre IA Agéntica (febrero 2026)
> Fuente: aepd.es — Agencia Española de Protección de Datos

---

## Principio

La AEPD distingue IA agéntica (autónoma, con objetivos, capaz de
actuar sin supervisión continua) de IA conversacional simple.
Los agentes autónomos requieren controles adicionales de protección
de datos y gobernanza.

---

## Framework de 4 Fases

### Fase 1 — Descripción Tecnológica (peso: 25%)

Documentar para cada agente autónomo:
- Modelo base utilizado (Claude, GPT, Gemini, local)
- Capacidades: lectura, escritura, ejecución, acceso a red
- Datos que procesa: personales, sensibles, confidenciales
- Alcance de autonomía: supervisado, semi-autónomo, autónomo
- Herramientas disponibles (tools/MCP) y sus permisos

### Fase 2 — Análisis de Cumplimiento (peso: 30%)

| Requisito | Criterio | Severidad |
|---|---|---|
| Base jurídica | Consentimiento o interés legítimo documentado | CRITICAL |
| Minimización | Solo datos necesarios para la tarea | HIGH |
| Transparencia | Usuario informado de que interactúa con IA | HIGH |
| Limitación finalidad | Agente solo actúa dentro de scope definido | CRITICAL |
| Exactitud | Mecanismos de verificación de outputs | MEDIUM |
| Limitación conservación | Datos temporales eliminados tras tarea | HIGH |
| Seguridad | Cifrado, control acceso, audit trail | CRITICAL |

### Fase 3 — Evaluación de Vulnerabilidades (peso: 25%)

| Vulnerabilidad | Descripción | Mitigación |
|---|---|---|
| Prompt injection | Agente manipulado por input malicioso | Sanitización, scope guard |
| Data leakage | Agente expone datos a contextos no autorizados | Aislamiento, permisos mínimos |
| Scope creep | Agente actúa fuera de su alcance definido | Scope guard hook, plan-gate |
| Hallucination | Agente genera datos falsos como reales | Verificación contra fuentes |
| Chain escalation | Cadena de agentes amplifica errores | Checkpoints entre agentes |
| Persistence abuse | Agente almacena datos sin consentimiento | Política de retención |

### Fase 4 — Medidas Protectoras (peso: 20%)

| Medida | Implementación | Verificable |
|---|---|---|
| Privacy by design | EIPD antes de desplegar agente | Documento EIPD |
| Supervisión humana | Human-in-the-loop para acciones críticas | Logs de aprobación |
| Trazabilidad | Audit trail de todas las acciones | action-log.jsonl |
| Derecho de oposición | Usuario puede detener agente | Kill switch |
| Evaluación periódica | Revisión trimestral de cumplimiento | governance-audit |
| Notificación brechas | Protocolo 72h AEPD si brecha | incident-postmortem |

---

## Scoring AEPD

```
score = (fase1 × 0.25) + (fase2 × 0.30) + (fase3 × 0.25) + (fase4 × 0.20)
```

| Score | Nivel | Acción |
|---|---|---|
| ≥ 80% | Conforme | Documentar y archivar |
| 60-79% | Parcialmente conforme | Plan corrección ≤30 días |
| 40-59% | No conforme | Corrección inmediata requerida |
| < 40% | Riesgo crítico | Suspender agente hasta corrección |

---

## Mapeo pm-workspace → AEPD

| Control AEPD | Implementación en pm-workspace |
|---|---|
| Transparencia | Savia se identifica como IA al usuario |
| Scope guard | Hook `scope-guard.sh` + `plan-gate.sh` |
| Audit trail | `action-log.jsonl` + `agent-trace-log.sh` |
| Minimización | `agent-context-budget.md` (tokens mínimos) |
| Supervisión | Regla 10 (NUNCA apply sin aprobación) |
| Privacy by design | `confidentiality-config.md` + `security-guardian` |
| Trazabilidad | Agent notes protocol + trace-analyze |
| EIPD | `/aepd-compliance` genera evaluación de impacto |

---

## Integración con Marcos Existentes

| Marco | Relación con AEPD |
|---|---|
| EU AI Act | AEPD complementa con foco en datos personales |
| NIST AI RMF | AEPD aporta perspectiva europea de privacidad |
| ISO 42001 | AEPD añade requisitos RGPD específicos |
| RGPD | AEPD es la interpretación española del RGPD para IA |
