# SPEC-SE-006 — Governance & Compliance Pack

> **Prioridad:** P1 · **Estima:** 8 días · **Tipo:** compliance regulatorio

## Objetivo

Convertir Savia Enterprise en una plataforma **auditable** frente a las
regulaciones europeas vigentes (AI Act, NIS2, DORA, GDPR, Cyber Resilience
Act) sin depender de herramientas de compliance propietarias. Todo el
material de auditoría debe generarse desde el propio `.md` y ser legible
por un auditor humano sin software específico.

## Principios afectados

- #3 Honestidad radical (audit trail completo, no editable)
- #5 El humano decide (gates de compliance antes de merge/deploy)

## Diseño

### Frameworks cubiertos

| Framework | Capa | Artefactos generados |
|-----------|------|----------------------|
| **EU AI Act** | alta | Model cards, risk assessment, EIPD |
| **NIS2** | alta | Security posture, incident log |
| **DORA** | alta | ICT risk register, outsourcing |
| **GDPR** | media | DPIA, RoPA, consent log |
| **CRA** | media | SBOM, vuln disclosure, lifecycle |
| **ISO 42001** | opcional | AI governance policy |

### Audit trail firmado

Cada acción Enterprise (commit, deploy, spec approval, agent run) genera
una entrada en audit log append-only con firma criptográfica:

```jsonl
{"ts":"2026-04-11T10:00:00Z","tenant":"banca","actor":"architect","action":"spec_approved","spec":"SE-042","hash":"sha256:abc...","sig":"ed25519:..."}
```

- Firma con clave Ed25519 del tenant
- Chain hash: cada entrada incluye hash de la anterior (blockchain simple)
- Export a PDF firmado para auditores

### Model cards automáticas

Para cada agente registrado, `/ai-model-card` genera un documento MD con:
- Propósito, capacidades, limitaciones
- Modelo LLM usado, token budget, permission level
- Conjunto de entrenamiento (cuando aplique)
- Tests de sesgo (vía Equality Shield)
- Evaluación contra AI Act Annex III

### Gates de compliance

Extension point #6 de SE-001. Validadores opcionales:

- `compliance-gate-ai-act.sh` — bloquea si spec toca alto riesgo sin EIPD
- `compliance-gate-nis2.sh` — verifica security-review antes de merge infra
- `compliance-gate-dora.sh` — verifica ICT risk entry en releases

### Integración con `legal-compliance`

El agente `legal-compliance` existente cruza reglas de negocio contra
legalize-es. En Enterprise se amplía con:
- Normativa UE (EUR-Lex offline snapshot)
- Matriz de trazabilidad regla → artículo → spec → test

## Criterios de aceptación

1. Audit log append-only con firma Ed25519 y chain hash
2. Export PDF firmado para auditor externo
3. `/ai-model-card` genera ficha para los 46 agentes
4. Gate AI Act integrado en `/pr-plan`
5. Matriz de trazabilidad para 1 proyecto piloto del sector bancario
6. Documento "Savia Enterprise & EU AI Act compliance" en inglés

## Out of scope

- Certificación formal ISO (requiere auditor externo humano)
- Consultoría legal (Savia no suplanta al abogado)

## Dependencias

- SE-001 (extension points)
- SE-002 (audit log por tenant)

## Impacto estratégico

El AI Act entró en plena vigencia en agosto 2026. Bancos, hospitales y
energéticas **no pueden** enviar datos a modelos americanos sin auditoría.
Esta spec es la palanca que convierte Savia Enterprise en producto
comercializable al IBEX 35.
