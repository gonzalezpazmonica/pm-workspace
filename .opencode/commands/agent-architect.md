# /agent-architect — Detección y descomposición de agentes monolíticos

Invoca el agente especializado `agent-architect` para analizar uno o varios agentes del catálogo y, si detecta monolitos, generar una propuesta de descomposición.

## Uso

```
/agent-architect <agent-id>           # Analiza un agente concreto + propuesta si aplica
/agent-architect --all                # Analiza los 70 agentes y produce ranking agregado
/agent-architect --threshold alert    # Solo lista agentes con ≥ 2 alerts
```

## Qué hace

1. Localiza el agente target en `.opencode/agents/`.
2. Invoca `scripts/agent-architect.sh` (wrapper bash → analizador Python).
3. Recibe señales estructuradas (length, responsibilities, tools, contradictions, roleplay_depth, age_days).
4. Si el agente tiene **≥ 2 alerts**, genera propuesta de descomposición usando `templates/agent-decomposition-template.md`.
5. Entrega la propuesta como artefacto markdown bajo `output/agent-architect/<agent-id>-<fecha>.md`. **Nunca** modifica el agente original.

## Reglas

- D-1: Detector + propositor, no refactorizador automático.
- D-3: Propuesta es artefacto markdown; jamás se aplican cambios.
- D-4: Análisis offline. El contenido del agente no sale del workspace.
- Rule #26: Heurísticas en Python; bash solo wrapper.

## Invocación recomendada

Para análisis del catálogo completo: `/agent-architect --all`.
Para profundizar en un candidato: `/agent-architect <agent-id>`.

## Skill asociada

`.opencode/skills/agent-monolith-detector/SKILL.md` documenta heurísticas, cómo interpretar señales y cómo encajar la descomposición en `SPEC-AGENTIC-FLOW-GRAPH`.

## Salida JSON

Para integraciones, añadir `--json`:

```
scripts/agent-architect.sh --all --json > output/agent-architect/all.json
```

## Configuración

Umbrales en `.opencode/agent-architect-thresholds.yaml`. Editables sin tocar código.
