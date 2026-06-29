---
context_tier: L2
token_budget: 1200
resource: internal://docs/rules/domain/skill-families-registry.md
updated_at: "2026-06-28"
---

# Registro de Familias de Skills (skill-families-registry)

> Catálogo oficial de familias de skills organizadas por dominio.
> Fuente de verdad para selección de skills y auditoría de cobertura.
> Actualizado por: SE-233 (2026-06-28)

## Convenciones

- **Tier STANDARD**: skills de uso general, sin requisitos especiales de validación
- **Tier ADVANCED**: skills de dominio especializado, requieren validación humana
- **Disclaimer profesional**: OBLIGATORIO = aparece en todos los outputs sin excepción
- **Requiere validación humana**: SIEMPRE = no usar output directamente sin revisión profesional

---

## org-intelligence (SE-232, v1.0.0, 2026-06-28)

Skills: org-stakeholder-mapper, org-political-landscape, org-meeting-capture
Dominio: conocimiento organizativo tácito
Tier: ADVANCED | Requiere validación humana: SIEMPRE

**Descripción**: Mapeo de poder organizativo, análisis del paisaje político de iniciativas
y extracción de conocimiento tácito de reuniones. Los outputs son sensibles y no deben
compartirse sin autorización.

**Schema de nodos**: DECISOR / INFORMAL_AGREEMENT / POLITICAL_CONTEXT

**Estado**: PROPOSED (SE-232) — pendiente de implementación

---

## professional-domain (SE-233, v1.0.0, 2026-06-28)

Sub-familias: sales (4), legal (3), controlling (3), finance (3), labour (4)
Total skills: 17
Dominio: habilidades profesionales no técnicas
Tier: ADVANCED | Disclaimer profesional: OBLIGATORIO en todos los outputs

**Descripción**: Skills especializadas para profesionales no técnicos (ventas, legal,
controlling, finanzas, RRHH). Cada sub-familia carga contexto de dominio pre-cargado
con marco legal o estándar del sector. Todos los outputs incluyen disclaimer profesional
obligatorio y marcadores [DATO PENDIENTE] cuando falta información crítica.

**Principios transversales**:
- Disclaimer profesional obligatorio en cada output
- No inventar artículos, cifras ni fechas no proporcionadas
- Marcadores [DATO PENDIENTE] para información faltante
- Gradación de riesgo: ALTO (legal/labour) / MEDIO (finance/controlling) / BAJO (sales)

**Estado por sub-familia**:

| Sub-familia | Skills | Estado | Sprint |
|---|---|---|---|
| labour | 4 | IMPLEMENTED (2026-06-28) | Sprint actual |
| legal | 3 | IMPLEMENTED (en nido) | Sprint anterior |
| sales | 4 | IMPLEMENTED (en nido) | Sprint anterior |
| controlling | 3 | IMPLEMENTED (en nido) | Sprint anterior |
| finance | 3 | IMPLEMENTED (en nido) | Sprint anterior |

**Reglas de dominio**:
- `docs/rules/domain/professional-domain-disclaimer.md` — disclaimers por sub-familia
- `docs/rules/domain/org-intelligence-protocol.md` — schemas y protocolo org-intelligence

**Guía de adopción**: `docs/guides_es/domain-skills-adoption-guide.md`

---

## Familias de skills del workspace principal

> Las familias anteriores se referencian aquí por completitud.
> Las familias del workspace principal (pm-workspace) se gestionan en
> `.opencode/skills/` raíz y están documentadas en `SKILLS.md`.

Familias activas en el workspace principal (referencia):
- `adversarial-security` — auditoría Red Team / Blue Team
- `codebase-memory` — grafo de conocimiento de código
- `spec-driven-development` — desarrollo guiado por specs ejecutables
- `tdd-vertical-slices` — TDD con ciclos red-green-refactor
- `savia-memory` — memoria persistente entre sesiones
- `knowledge-graph` — grafo de conocimiento de entidades del proyecto
