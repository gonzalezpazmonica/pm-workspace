# code-reviewer-runbook — Domain

Auxiliar del agente `code-reviewer`. Contiene los checklists detallados,
el formato de informe completo y los arboles de decision que el agente
referencia en lugar de mantenerlos inline.

## Uso

Cargar cuando `code-reviewer` necesita ejecutar una revision completa
y requiere el detalle de los checks por categoria (seguridad, calidad,
SOLID, spec SDD) o el formato exacto del informe de veredicto.

## Relacion con el agente

- Agente: `.opencode/agents/code-reviewer.md`
- Este skill: detalle de checklists, formato de informe, decision trees
- Reglas de referencia: `docs/rules/languages/csharp-rules.md`
