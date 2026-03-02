# Role Evolution — Roles en la Era AI

> Los roles evolucionan de ejecutores a orquestadores. El equipo no crece en personas, crece en capacidad amplificada por AI.

## 6 categorías de roles AI-era (aplicadas a Savia Flow)

### 1. AI Orchestrators — Quienes dirigen agentes
- **En Savia**: Flow Facilitator (Mónica), AI Product Manager (Elena)
- **Competencia clave**: diseñar prompts, evaluar output de agentes, orquestar workflows
- **Medición**: calidad de specs generadas, reducción de rework rate

### 2. Domain Translators — Quienes conectan negocio con AI
- **En Savia**: Product Manager (Elena cuando escribe outcomes/specs)
- **Competencia**: traducir necesidades de usuario a specs ejecutables por agentes
- **Medición**: spec-to-built time, outcome validation rate

### 3. Quality Guardians — Quienes validan output AI
- **En Savia**: Quality Architect (Elena en QA), Human Reviewer (Mónica en Gate 5)
- **Competencia**: detectar alucinaciones, validar correctness, security review
- **Medición**: change failure rate, defects escapados post-gate

### 4. Augmented Builders — Quienes construyen con AI
- **En Savia**: Pro Builders (Ana, Isabel) usando Claude Code para implementar
- **Competencia**: pair programming con AI, code review de output AI, testing
- **Medición**: velocity con AI vs sin AI, code quality metrics

### 5. Context Engineers — Quienes mantienen el conocimiento
- **En Savia**: Quien mantiene CLAUDE.md, priming docs, memory system
- **Competencia**: knowledge priming, context optimization, documentation
- **Medición**: tokens ahorrados, calidad de respuestas AI con/sin priming

### 6. Ethics & Governance — Quienes supervisan el uso responsable
- **En Savia**: AI Safety Config, AI Audit Log, AI Boundary commands
- **Competencia**: bias detection, responsible AI, compliance
- **Medición**: incidents reportados, compliance score, audit trail coverage

## Mapping roles equipo SocialApp

| Persona | Roles AI-era | Savia Role | Evolución |
|---------|-------------|------------|-----------|
| Mónica | Orchestrator + Context Engineer | Flow Facilitator | De PM manual a directora de agentes |
| Elena | Domain Translator + Quality Guardian | AI PM + Quality Arch | De PO a traductora negocio→specs ejecutables |
| Ana | Augmented Builder | Pro Builder Front | De junior a builder amplificada por AI |
| Isabel | Augmented Builder + Context Engineer | Pro Builder Back + Arch | De senior a arquitecta con AI pair |

## Métricas de madurez por categoría

| Nivel | Descripción | Indicador |
|-------|-------------|-----------|
| L1 | Usa AI puntualmente | <20% tareas asistidas |
| L2 | Integra AI en workflow diario | 20-50% tareas asistidas |
| L3 | Orquesta múltiples agentes | >50% tareas, métricas automáticas |
| L4 | AI-first: diseña para agentes | Specs ejecutables por agentes sin intervención |

## Implicaciones para Savia Flow

1. **Onboarding**: evaluar en qué categoría está cada miembro → `/team-skills-matrix`
2. **Asignación**: match builder + AI category → mejor intake en `/flow-intake`
3. **Retrospectiva**: medir evolución de roles AI → métricas en `/flow-metrics`
4. **Priming**: cada rol necesita priming docs distintos (builder≠orchestrator)
