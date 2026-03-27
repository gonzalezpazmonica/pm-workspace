# Agent Notes — Protocolo de Memoria Inter-Agente

> Inspirado en el modelo de Miguel Palacios: bitácoras como memoria persistente entre sesiones y entre agentes.

---

## Concepto

Cada agente que produce un entregable durante un flujo SDD (o cualquier flujo multi-agente) escribe un fichero en `agent-notes/` del proyecto. El siguiente agente en la cadena **DEBE** leer las notas previas antes de actuar.

Las agent-notes son la memoria compartida del equipo de agentes. Sin ellas, cada sesión empieza de cero.

---

## Estructura

```
projects/{proyecto}/agent-notes/
├── {ticket}-legacy-analysis-{fecha}.md       ← @miguel.legacy / business-analyst
├── {ticket}-architecture-decision-{fecha}.md ← architect
├── {ticket}-test-strategy-{fecha}.md         ← test-engineer
├── {ticket}-security-checklist-{fecha}.md    ← security-guardian
├── {ticket}-implementation-log-{fecha}.md    ← {lang}-developer
└── {ticket}-review-findings-{fecha}.md       ← code-reviewer
```

### Convención de nombres

```
{ticket}-{tipo}-{fecha}.md

ticket  = AB1234 | PBI5678 | SPIKE-003 (referencia Azure DevOps)
tipo    = legacy-analysis | architecture-decision | test-strategy |
          security-checklist | implementation-log | review-findings |
          pm-validation | sprint-summary
fecha   = YYYY-MM-DD
```

---

## Metadata YAML (obligatoria)

Cada agent-note comienza con frontmatter YAML:

```yaml
---
ticket: AB#1234
phase: 2
agent: architect
status: completed          # draft | in-progress | completed | superseded
depends_on:                # notas que este agente leyó antes de producir esta
  - AB1234-legacy-analysis-2026-02-27.md
tags: [architecture, adr, clean-architecture]
created: 2026-02-27
---
```

---

## Flujo SDD con Agent Notes

```
1. business-analyst → escribe: {ticket}-legacy-analysis-{fecha}.md
       ↓ (lee: PBI padre, backlog, código existente)
2. architect        → escribe: {ticket}-architecture-decision-{fecha}.md
       ↓ (lee: legacy-analysis)
3. security-guardian → escribe: {ticket}-security-checklist-{fecha}.md
       ↓ (lee: architecture-decision, spec)
4. test-engineer    → escribe: {ticket}-test-strategy-{fecha}.md
       ↓ (lee: architecture-decision, security-checklist, spec)
5. {lang}-developer → escribe: {ticket}-implementation-log-{fecha}.md
       ↓ (lee: TODAS las notas previas + spec)
6. code-reviewer    → escribe: {ticket}-review-findings-{fecha}.md
       ↓ (lee: implementation-log, spec, test-strategy)
```

Cada agente documenta: qué leyó, qué decidió, qué produjo, y qué queda pendiente.

---

## Cuándo escribir agent-notes

- **Siempre** en flujo SDD (spec-generate → agent-run → spec-review)
- **Siempre** en flujo de infraestructura (infra-detect → infra-plan → infra-estimate)
- **Siempre** en auditorías (project-audit, legacy-assess, security audit por feature)
- **Opcional** en operaciones rutinarias (sprint-status, report-hours)

---

## Cuándo leer agent-notes

Antes de ejecutar, cada agente busca notas previas del mismo ticket:

```bash
ls projects/{proyecto}/agent-notes/{ticket}-*.md 2>/dev/null
```

Si existen, las lee como contexto. Si no, procede con el contexto estándar (spec, código, reglas).

---

## Limpieza

Las agent-notes de sprints cerrados se archivan en `agent-notes/archive/{sprint}/` al final de cada sprint review. El PM puede archivar manualmente con `/agent-notes-archive`.
