# Agent Architect

> Detector y propositor de descomposición para agentes monolíticos.
> Spec fuente de verdad: `docs/specs/SPEC-AGENT-ARCHITECT.spec.md`.

## Qué es

Una pipeline ligera que analiza los agentes de `.opencode/agents/` y detecta cuáles han crecido lo suficiente como para perder eficacia. Si encuentra candidatos, propone una descomposición concreta. **Nunca** modifica el agente original.

## Arquitectura

```
/agent-architect <id>           (comando slash, markdown)
        │
        ▼
.opencode/agents/agent-architect.md   (agente que orquesta)
        │
        ▼
scripts/agent-architect.sh      (wrapper bash, ≤ 20 líneas)
        │
        ▼
scripts/lib/agent_architect/    (módulo Python: parser, heuristics, detector, report, cli)
```

## Cómo se invoca

```
/agent-architect <agent-id>           # análisis individual + propuesta si aplica
/agent-architect --all                # ranking del catálogo entero
/agent-architect --threshold alert    # solo candidatos
```

CLI directa (debug):

```
scripts/agent-architect.sh --agent dotnet-developer
scripts/agent-architect.sh --all --json
PYTHONPATH=scripts/lib python3 -m agent_architect.cli --agent <id>
```

## Heurísticas

Cada heurística es una función pura sobre el AST del agente. Cada una emite `info`, `warn` o `alert`.

| Heurística | Qué mide |
|---|---|
| `length` | Líneas de prompt |
| `responsibilities` | Verbos imperativos distintos en headers (en + es) |
| `tools` | Tools declaradas en frontmatter |
| `contradictions` | Pares always/never, must/must-not en distintas oraciones |
| `roleplay_depth` | Markers de roleplay anidado |
| `age_days` | Días desde última modificación |

Un agente con **≥ 2 alerts** es candidato a descomposición.

## Configuración

Umbrales en `.opencode/agent-architect-thresholds.yaml`. Editables sin tocar código.

Orchestrators (`kind: orchestrator` en frontmatter) reciben thresholds 2x relajados para length, responsibilities y tools — coordinar legítimamente requiere más superficie.

## Output

- **Reporte agregado** (`--all`): tabla ranking + análisis individual de cada agente con evidencia textual.
- **Análisis individual** (`<agent-id>`): señales con citas + propuesta de descomposición si es candidato.
- **Propuesta de descomposición** (auto-generada por el agente, no por Python): diagnóstico, sub-agentes con contratos, diagrama Mermaid, encaje en SPEC-AGENTIC-FLOW-GRAPH, plan de migración, riesgos. Plantilla en `templates/agent-decomposition-template.md`.

Las propuestas se guardan en `output/agent-architect/<agent-id>-<YYYY-MM-DD>.md`.

## Decisiones arquitectónicas

| ID | Decisión |
|---|---|
| D-1 | Detector + propositor, no refactorizador. |
| D-2 | Heurísticas explícitas y configurables, no black-box. |
| D-3 | Propuesta es artefacto markdown; nunca aplica cambios. |
| D-4 | Análisis offline. Contenido del agente no sale del workspace. |
| D-5 | Heurísticas en Python; bash solo wrapper (Rule #26). |
| D-6 | NO se expone como MCP server. Acoplado al workspace local. |

## Limitaciones honestas

- Falsos positivos aceptables — D-1 explícito.
- `responsibilities` infra-cuenta agentes redactados con frases en lugar de verbos.
- `contradictions` es conservadora: solo cuenta pares en distintas oraciones.
- `age_days` mira `mtime` del fichero — un rename rompe la señal.
- No mide cobertura de tests por agente (heurística pendiente para slice futuro).

## Tests

- pytest: `tests/python/test_agent_architect_*.py` (28 cases).
- bats: `tests/agent-architect-wrapper.bats` (6 cases).
- Smoke real: `--all` corre sobre 70 agentes en ~1s.

## Coste y soberanía

- Análisis 100% offline. No usa LLMs ni APIs externas.
- Propuesta de descomposición sí usa LLM (vía agente `agent-architect`), pero sobre datos ya extraídos localmente.
- Cero datos del agente target salen del workspace para el análisis estructural.
