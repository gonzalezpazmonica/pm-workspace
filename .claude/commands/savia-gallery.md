---
name: savia-gallery
description: Catálogo visual/interactivo de comandos, skills y agentes por rol y vertical
developer_type: all
agent: task
context_cost: high
---

# /savia-gallery

> Catálogo interactivo de los 270+ comandos organizados por rol y vertical.

Inspirado en component.gallery — organiza comandos como "componentes"
con variantes, ejemplos y filtros por rol.

## Sintaxis

```
/savia-gallery [--role pm|techlead|qa|po|dev|ceo] [--vertical name] [--search term]
```

## Flujo

### Paso 1 — Recopilar catálogo

Escanear `.claude/commands/` y extraer de cada fichero:
- `name` (frontmatter)
- `description` (frontmatter)
- `context_cost` (low/medium/high)
- Categoría (inferida de nombre o path)

### Paso 2 — Clasificar por rol

Usar `role-workflows.md` para mapear comandos a roles:

| Rol | Comandos principales |
|---|---|
| PM | sprint-*, report-*, board-*, capacity-*, backlog-* |
| Tech Lead | arch-*, tech-*, pr-*, spec-*, debt-* |
| QA | qa-*, testplan-*, a11y-*, compliance-* |
| PO | kpi-*, feature-*, backlog-*, release-* |
| Developer | my-*, spec-implement, flow-* |
| CEO/CTO | ceo-*, portfolio-*, org-*, strategy-* |

### Paso 3 — Filtrar por vertical (si aplica)

Verticales con comandos específicos:
- **Banking**: banking-*, `/banking-bian`, `/banking-detect`
- **Healthcare**: `/vertical-healthcare`
- **Finance**: `/vertical-finance`
- **Legal**: `/vertical-legal`
- **Education**: `/vertical-education`
- **AEPD/Governance**: `/aepd-compliance`, `/governance-*`

### Paso 4 — Generar galería

Output en fichero con formato navegable.

---

## Output

Fichero: `output/gallery-YYYYMMDD.md`

Formato por comando:

```markdown
### /sprint-status
**Rol**: PM · **Coste contexto**: medium · **Era**: 3
Descripción: Estado del sprint actual con progreso y bloqueantes.
Ejemplo: `/sprint-status --project sala-reservas`
Relacionados: /sprint-plan, /sprint-forecast, /board-flow
```

---

## Source Tracking

Cada output de Savia incluye las fuentes consultadas.

### Implementación

Al final de cada respuesta que use reglas, skills o docs:

```
📚 Fuentes consultadas:
- .claude/skills/regulatory-compliance/references/aepd-framework.md
- .claude/skills/regulatory-compliance/SKILL.md
- docs/best-practices-claude-code.md
```

### Cuándo incluir fuentes

- Siempre que se ejecute un slash command
- Siempre que se cite una regla o convención
- Siempre que se genere un informe
- NO en conversación casual o saludos

### Formato compacto

Si hay >5 fuentes, agrupar por tipo:
```
📚 Rules: 3 | Skills: 1 | Docs: 2
   Detalle en output/sources-YYYYMMDD.md
```
