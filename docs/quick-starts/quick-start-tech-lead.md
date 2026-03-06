# Quick Start — Tech Lead

> 🦉 Hola, Tech Lead. Soy Savia. Te ayudo con la salud de la arquitectura, la deuda técnica, las code reviews y la coordinación técnica del equipo. Aquí tienes lo esencial.

---

## Primeros 10 minutos

```
/arch-health --drift --coupling
```
Analizo la arquitectura del proyecto: fitness functions, drift detection, métricas de acoplamiento.

```
/tech-radar MiProyecto
```
Mapeo el stack tecnológico con categorización adopt/trial/hold/retire.

```
/debt-analyze
```
Identifico hotspots de deuda técnica, coupling temporal y code smells, priorizados por impacto.

---

## Tu día a día

**Cada mañana** — `/pr-pending` para ver PRs esperando review. `/spec-status` para el progreso de specs SDD.

**Al revisar código** — `/pr-review {PR}` ejecuta análisis automático contra reglas de dominio. El hook pre-commit ya cachea SHA256 para no re-revisar ficheros sin cambios.

**Semanal** — `/arch-health` para verificar que no hay drift arquitectónico. `/team-skills-matrix --bus-factor` para detectar conocimiento concentrado en una persona.

**Ante incidentes** — `/incident-postmortem {desc}` estructura un postmortem blameless con timeline y root cause analysis.

**Cada sprint** — `/debt-budget` para asignar presupuesto de deuda técnica con proyección de impacto en velocity.

---

## Cómo hablarme

| Tú dices... | Yo ejecuto... |
|---|---|
| "¿Qué PRs están pendientes?" | `/pr-pending` |
| "Revisa este PR" | `/pr-review {PR}` |
| "¿Cómo está la arquitectura?" | `/arch-health` |
| "¿Qué deuda técnica priorizo?" | `/debt-prioritize` |
| "¿Quién sabe de este módulo?" | `/team-skills-matrix` |
| "Hubo un incidente en producción" | `/incident-postmortem` |
| "Genera un ADR para esta decisión" | `/adr-create {proy} {título}` |

---

## Dónde están tus ficheros

```
.claude/
├── agents/
│   ├── developer-*.md    ← agentes que implementan specs
│   ├── code-reviewer.md  ← agente de code review
│   └── architect.md      ← agente de arquitectura
├── rules/language/       ← reglas por lenguaje (auto-carga por extensión)
├── rules/domain/
│   ├── tool-discovery.md ← capability groups para los 360+ comandos
│   └── eval-criteria.md  ← criterios de evaluación de outputs
└── commands/
    ├── arch-*.md         ← comandos de arquitectura
    ├── debt-*.md         ← comandos de deuda técnica
    └── spec-*.md         ← comandos de SDD
```

Las reglas de lenguaje se cargan automáticamente cuando trabajo con ficheros de ese tipo. Si edito un `.cs`, se cargan las reglas de C#.

---

## Cómo se conecta tu trabajo

Las specs SDD que generas (`/spec-generate`) son el contrato que ejecutan los agentes developer. Cuando un agente implementa, el code review automático verifica contra las reglas de dominio. Los tests pasan, se mergea, y las métricas DORA se actualizan automáticamente. Si un ADR cambia la arquitectura, `/arch-health` lo detecta como drift hasta que se acepta. La deuda técnica que priorizas impacta directamente en la velocity que ve el PM.

---

## Siguientes pasos

- [Spec-Driven Development](../readme/05-sdd.md)
- [Architecture Intelligence](../readme/12-comandos-agentes.md)
- [Agent Teams SDD](../agent-teams-sdd.md)
- [Guía de flujo de datos](../data-flow-guide-es.md)
