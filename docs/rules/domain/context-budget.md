---
globs: [".claude/commands/spec-generate*", ".claude/commands/dev-session*"]
---

# context-budget — Presupuestos de Contexto por Operación

Límites de tokens máximo por tipo de operación. Compresión obligatoria antes de invocar agentes.

## Presupuestos Máximos

| Operación | Tokens máximo | Rebase | Alerta |
|-----------|---------------|--------|--------|
| **PBI Decompose** | 40K | Base 100K | >85% |
| **Spec Generate** | 35K | Base 100K | >80% |
| **Dev Session** | 25K | Base 100K | >75% |

## Rebase

El presupuesto se calcula sobre un contexto base de **100K tokens** que incluye:
- System prompt (~2K)
- PM-Workspace CLAUDE.md + rules (~8K)
- Project context (~15K)
- Skills y ejemplos (~10K)
- Buffer para conversación (~65K)

## Alerta Automática

Si contexto actual > umbral de alerta:
```
⚠️ Contexto alto (XX%). Compresión recomendada antes de {operación}.
```

## Compresión Obligatoria

Si contexto actual > presupuesto máximo:
```
❌ Contexto excede presupuesto para {operación} (XX% > YY%).
   Ejecuta /compact ahora, o reduce scope.
```

**Acción:** Bloquear invocación de agente hasta compresión.

## Integración

- Verificación pre-agente: `scripts/context-check.sh`
- Alertas en commands que usan agentes (SDD, project-audit, etc.)
- Dashboard: `/context-budget --show`

