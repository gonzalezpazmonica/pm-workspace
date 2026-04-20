---
status: PROPOSED
---

# SPEC-SE-004 — Agent Framework Interop

> **Prioridad:** P1 · **Estima:** 10 días · **Tipo:** agnosticismo de runtime

## Objetivo

Hacer que los agentes SDD de Savia (46 agentes actuales) puedan ejecutarse
sobre **cualquier runtime agentic del mercado** mediante adaptadores: Claude
Code (nativo), Microsoft Agent Framework 1.0, LangGraph, Semantic Kernel,
PydanticAI, AWS Strands. El cliente elige runtime; Savia no obliga.

## Principios afectados

- #2 Independencia del proveedor (agnosticismo total de runtime)
- #1 Soberanía (runtime local como opción de primera clase)

## Diseño

### Agent manifest canónico

Cada agente Savia se describe en formato canónico YAML (ya existe en
frontmatter actual). Los adaptadores leen este manifest y lo traducen:

```yaml
---
name: architect
permission_level: L1
tools: [Read, Glob, Grep]
model_tier: opus
token_budget: 13000
description: "Diseño de arquitectura y decisiones técnicas de alto nivel"
---
```

### Adaptadores objetivo (orden de prioridad)

1. **Claude Code** — nativo, ya funciona
2. **Microsoft Agent Framework 1.0** — apuesta 5.4 del informe, mercado .NET
3. **LangGraph** — ecosistema Python/TS mayoritario
4. **Semantic Kernel** — legacy Microsoft, migración asistida
5. **PydanticAI** — creciente en research/startups
6. **AWS Strands** — requerido en ofertas AWS senior

### Implementación por adaptador

```
.claude/enterprise/adapters/
├── msagent/
│   ├── manifest-transform.py      ← Savia → MS Agent YAML
│   ├── tool-bridge.cs             ← puente tools
│   └── golden-set.json            ← tests de paridad
├── langgraph/
├── semantic-kernel/
└── pydantic-ai/
```

### Golden set de paridad

Cada adaptador se valida contra un set de 20 tareas canónicas. Un agente
portado debe producir resultados **semánticamente equivalentes** al de
Claude Code nativo (score ≥ 0.85 en reflection-validator).

### Model-agnosticism

El adaptador NO fuerza modelo. Acepta:
- Claude (Anthropic API)
- GPT-4/5 (OpenAI)
- Gemini (Google)
- Llama/Qwen/Mistral locales (Ollama, vLLM)
- Modelos custom del cliente

## Criterios de aceptación

1. Manifest canónico documentado en `docs/propuestas/savia-enterprise/agent-manifest-spec.md`
2. Adaptador MS Agent Framework funcional con 3 agentes portados (architect, business-analyst, test-engineer)
3. Golden set de 20 tareas con paridad ≥ 85%
4. Demo: mismo PBI procesado en Claude Code y en MS Agent Framework → outputs equivalentes
5. Documentación de migración Semantic Kernel → Savia
6. Post técnico público sobre "Savia agents sobre MS Agent Framework 1.0"

## Out of scope

- Runtime propio de Savia (rechazado: violaría principio #2)
- Optimizaciones específicas por runtime

## Dependencias

- SE-001 (extension points)
- SE-003 (MCP catalog, para que adaptadores compartan tools)

## Impacto estratégico

Ejecuta la apuesta 5.4 del informe: *"Profundizar en Microsoft Agent
Framework 1.0 inmediatamente"*. Posicionamiento como voz de referencia
en español sobre Agent Framework, hueco prácticamente vacío.
