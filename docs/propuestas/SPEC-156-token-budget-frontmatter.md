---
id: SPEC-156
title: Token Budget Frontmatter for agents
status: PROPOSED
priority: HIGH
estimated_hours: 4
tier: 1A
origin: anthropic-effective-agents-thesis-2026
---

# SPEC-156 Token Budget Frontmatter

## Problema
Los 70 agentes no declaran presupuesto de tokens. Heavy tier consume 80-120k por invocacion sin gate ni alerta. Anthropic recomienda budget explicito por agente.

## Solucion
Anadir campo token_budget al frontmatter de los agentes y crear hook que proyecte consumo antes de invocar.

Campos:
- per_invocation: cap duro de tokens por llamada
- context_window_target: objetivo operativo de ventana
- escalation_policy: block | escalate | warn

Defaults por tier:
- fast: 30000 / 8000 / escalate
- mid: 60000 / 15000 / escalate
- heavy: 100000 / 20000 / block

## Slices
1. Schema y migracion 70 agentes (1.5h)
2. Hook PreToolUse en Task tool (1.5h)
3. Auto-escalation y tests BATS (1h)

## AC
- 70 agentes con campo token_budget
- Hook bloquea exit 2 si excede cap (modo block)
- Telemetria append-only en output/agent-runs/budget-projections.jsonl
- Tests BATS score 80+

## Riesgos
Falsos positivos en proyeccion. Mitigacion: SAVIA_BUDGET_ENFORCEMENT=warn 2 semanas antes de block.

## Out of scope
Calculo exacto tokens. Pricing dolares. Budget compartido entre agentes.
