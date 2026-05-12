---
name: agent-monolith-detector
description: Detección de agentes monolíticos en `.opencode/agents/` mediante heurísticas explícitas (length, responsibilities, tools, contradictions, roleplay_depth, age_days). Invoca el analizador Python vía `scripts/agent-architect.sh` y devuelve señales cualificadas. NO refactoriza; produce reporte y, si hay candidatos, plantilla de descomposición. Ver SPEC-AGENT-ARCHITECT.
---

# agent-monolith-detector

## Cuándo usar

- Higiene periódica del catálogo de agentes (mensual).
- Antes de aceptar un PR que añade un nuevo agente o engorda uno existente.
- Cuando se sospecha que un agente está siendo "ignorado" parcialmente por el modelo.
- Bajo demanda durante decisiones de arquitectura SDD.

## Cómo invocar

Comando slash:
```
/agent-architect <agent-id>
/agent-architect --all
/agent-architect --threshold alert
```

Wrapper directo:
```
scripts/agent-architect.sh --agent <id>
scripts/agent-architect.sh --all --json
scripts/agent-architect.sh --threshold alert
```

Entrypoint Python (debug):
```
PYTHONPATH=scripts/lib python3 -m agent_architect.cli --all --json
```

## Heurísticas

Cada heurística es una función pura sobre el AST del agente. Niveles: `info`, `warn`, `alert`.

| Heurística | Qué mide | Por qué importa |
|---|---|---|
| `length` | Líneas del fichero | > 400 líneas → modelo ignora partes |
| `responsibilities` | Verbos imperativos distintos en headers (en+es) | ≥ 5 → mezcla concerns |
| `tools` | Tools en frontmatter | > 10 → acoplamiento |
| `contradictions` | Pares always/never, must/must-not en distintas oraciones | ≥ 3 → reglas inconsistentes |
| `roleplay_depth` | Markers de roleplay anidado ("imagina que…") | ≥ 2 → carga cognitiva |
| `age_days` | Días desde última modificación | > 180 → deuda sin revisión |

## Cómo interpretar señales

- **info**: nominal, no acción.
- **warn**: vigilar; si se acumula con otros, considerar revisar.
- **alert**: revisar.
- **≥ 2 alerts**: agente es **candidato a descomposición**.

## Configuración

Umbrales en `.opencode/agent-architect-thresholds.yaml`. Orchestrators (`kind: orchestrator` en frontmatter) reciben thresholds 2x relajados para length/responsibilities/tools.

## Encaje en SPEC-AGENTIC-FLOW-GRAPH

Si SPEC-AFG está activo, una propuesta de descomposición puede incluir un `.flow.yaml` que orqueste los sub-agentes propuestos. Plantilla en `templates/agent-decomposition-template.md`.

## Limitaciones honestas

- Las heurísticas son aproximaciones. Falsos positivos son aceptables (D-1 explícito).
- `responsibilities` se basa en verbos en headers. Si el agente usa frases en lugar de verbo-imperativo, infra-cuenta.
- `contradictions` es conservador: pares en la misma oración no se cuentan.
- `age_days` mira mtime del fichero. Un rename rompe la señal.
- No hay cobertura de tests por agente todavía (heurística pendiente para slice futuro).

## Anti-patrones detectables

1. **Mega-prompt con N responsabilidades**: length alert + responsibilities alert.
2. **Agente "tool sponge"**: tools alert pero responsibilities info → revisar si realmente necesita tantas.
3. **Roleplay nesting**: roleplay_depth alert → suele ir con length alert.
4. **Reglas contradictorias acumuladas**: contradictions alert + age_days alert.

## Output esperado

Reporte markdown a stdout (o JSON con `--json`). Para candidatos, la propuesta usa la plantilla `templates/agent-decomposition-template.md` y se guarda en `output/agent-architect/`.
