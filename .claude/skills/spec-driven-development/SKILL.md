---
name: spec-driven-development
description: Specs ejecutables para desarrolladores humanos y agentes Claude
context: fork
context_cost: high
agent: business-analyst
---

# Skill: Spec-Driven Development (SDD)

Transforma Tasks de Azure DevOps en Specs ejecutables por un Developer humano **o** un agente Claude.

**Prerequisitos:** `../azure-devops-queries/SKILL.md`, `../pbi-decomposition/SKILL.md`

---

## Concepto Central

```
PBI → Tasks → Specs (SDD) → Implementación (Human | Agent) → Code Review → Done
```

Un **Developer** puede ser:

| Tipo | Cuándo usar |
|---|---|
| `human` | Lógica compleja, decisiones arquitectónicas, ambigüedad alta |
| `agent-single` | Tasks bien definidas, patrones repetitivos, boilerplate |
| `agent-team` | Tasks grandes (>6h) que benefician de paralelización |

---

## Fase 1 — Determinar Developer Type

### Factores que favorecen agente:
- Patrón claro y repetible
- Output determinístico (tests, DTOs, validators)
- Ejemplos similares en el código
- Reglas de negocio completamente especificadas

### Factores que favorecen humano:
- Lógica de dominio novedosa
- Trade-offs arquitectónicos
- Sistemas externos sin documentación
- Criterios de aceptación incompletos
- Task E1 (Code Review) → **siempre humano**

---

## Fase 2 — Generar Spec

### 2.1 Obtener información

```bash
curl -s -u ":$PAT" "$AZURE_DEVOPS_ORG_URL/{proyecto}/_apis/wit/workitems/{id}?api-version=7.1" | jq .
```

### 2.2 Inspeccionar código existente

```bash
find src -name "*{patrón}*" | head -5
```

### 2.3 Construir Spec

Guardar en: `projects/{proyecto}/specs/{sprint}/AB{id}-{tipo}-{desc}.spec.md`
Usar plantilla: `references/spec-template.md`

### 2.4 Criterios de calidad

Una Spec es ejecutable cuando:
- [ ] Contrato (interface) definido exactamente
- [ ] Tipos de entrada/salida definidos
- [ ] Reglas de negocio inequívocas
- [ ] Test scenarios cubren casos normales y edge
- [ ] Ficheros a crear/modificar listados
- [ ] Ejemplos de código similar del proyecto
- [ ] Criterios de aceptación verificables

Si NO cumple → `developer_type: human`

### 2.5 Agent-Note del análisis

Escribir: `projects/{proyecto}/agent-notes/{ticket}-legacy-analysis-{fecha}.md`
Con: análisis de código, patrones, decisiones, dependencias.

---

## Fase 2.5 — Security Review Pre-Implementación

Ejecutar `/security-review {spec}`:
1. `security-guardian` revisa contra OWASP Top 10
2. Produce: `projects/{proyecto}/agent-notes/{ticket}-security-checklist-{fecha}.md`
3. Si issues 🔴 → corregir spec antes de implementar

**Obligatorio** para: auth, pagos, datos personales, APIs públicas, infraestructura.

---

## Fase 2.6 — TDD Gate: Tests Antes de Implementar

1. `test-engineer` escribe tests que fallan (Red)
2. Produce: `projects/{proyecto}/agent-notes/{ticket}-test-strategy-{fecha}.md`
3. **GATE**: developer NO puede editar código sin tests existentes

---

## Fase 3 — Ejecutar con Agente Claude

Detalles: **`references/agent-invocation.md`**
- Preparar contexto del agente
- Prompt para `agent-single` y `agent-team`
- Logging y manejo de errores
- Agent-Note post-implementación

---

## Fases 4-5 — Review, Métricas e Iteración

Detalles: **`references/review-metrics.md`**
- Checklist de review para Tech Lead
- Actualizar Azure DevOps
- Métricas de SDD (tasa éxito, deuda técnica)
- Mejora continua de Specs

---

## §2.7 Delta Specs (cambios incrementales)

Cuando una spec existente necesita modificaciones, usar formato delta en lugar de reescribir:

### Secciones delta
- **ADDED**: nuevos requisitos, escenarios o ficheros
- **MODIFIED**: cambios a requisitos existentes (mostrar antes → después)
- **REMOVED**: requisitos eliminados con justificación

### Consolidación
Al cerrar sprint, ejecutar `/spec-verify` para confirmar compliance y archivar deltas consolidados.

> Detalle: @references/compliance-matrix.md

---

## Referencias

- Spec template: `references/spec-template.md` · Layer assignment: `references/layer-assignment-matrix.md`
- Agent invocation: `references/agent-invocation.md` · Review & metrics: `references/review-metrics.md`
- Compliance matrix: `references/compliance-matrix.md`
- Comandos: `/spec-generate`, `/spec-implement`, `/spec-review`, `/spec-explore`, `/spec-design`, `/spec-verify`
