# Knowledge Graph — Domain Context

## Por qué existe esta skill

Los PMs gestiona múltiples dimensiones: proyectos, tareas, personas, skills, riesgos, decisiones. Sin un modelo de relaciones, estas dimensiones quedan aisladas. Un grafo conecta todo: "¿quién puede resolver esto?", "¿qué falla si cambio esto?", "¿cuál es el impacto en cascada?" — sin grafo, son preguntas sin respuesta rápida.

## Conceptos de dominio

- **Entidad**: objeto con atributos (Project, Task, Member, Skill, Risk)
- **Relación**: conexión dirigida entre dos entidades (HAS_PBI, ASSIGNED_TO, HAS_SKILL)
- **Traversal**: camino por el grafo para responder una pregunta (Member → HAS_SKILL → Skill)
- **JSONL**: almacenamiento durable, append-only, sin locks (perfecto para concurrencia)
- **Consulta NL**: pregunta en lenguaje natural traducida a traversal automáticamente

## Reglas de negocio que implementa

- **RN-SKILL-01**: Cada miembro debe tener ≥1 skill para visibilidad de capacidades
- **RN-TASK-02**: Tareas sin asignar no pueden tener riesgo explícito (¿a quién le importa?)
- **RN-DECISION-01**: Decisiones ADR deben referenciar tareas impactadas
- **RN-RISK-02**: Riesgos con impacto ≥4 deben tener mitigación documentada

## Relaciones a otras skills

**Upstream:** azure-devops-queries (fuente de work items), team-onboarding (source de miembros)
**Downstream:** `/graph-query` (consultas), `/graph-impact` (análisis), `/project-audit` (auditoría)
**Paralelo:** spec-driven-development (decisiones → tareas)

## Decisiones clave

- **JSONL no RDF/Turtle**: JSONL es más simple de versionear en Git que triples RDF
- **Consultas NL vs SPARQL**: NL es más accesible que SPARQL, traducido internamente
- **Construcción on-demand vs tiempo real**: Build con `/graph-build` (batch), no siempre live
