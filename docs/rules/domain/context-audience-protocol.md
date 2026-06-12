---
context_tier: L4
token_budget: 700
audience: all-agents
---

# Regla: Context Audience Protocol

> Spec: SE-221 Slice 3. Fecha: 2026-06-12.
> Frontmatter opcional `audience:` para fragmentos de contexto.

## Principio

Cada fichero de regla o skill puede declarar en su frontmatter YAML un
campo `audience:` que indica que agentes deberian consumirlo. El campo es
opcional; si falta, el default implicito es `all-agents`.

Este campo cumple dos funciones:

1. Filtro para subagentes: cuando un subagente arranca via Task tool, el
   hook subagent-audience-filter genera una lista filtrada de fragmentos
   donde el subagente esta autorizado. Subagente desconocido recibe solo
   ficheros con audience `all-agents` (deny by default).
2. Revelacion de conexiones cross-concept: el script
   context-audience-graph.py extrae pares de ficheros con dos o mas
   agentes compartidos en su audience. Ese par es evidencia de conexion
   no obvia que alimenta el knowledge graph.

## Formato

Tres variantes validas:

  audience: all-agents
  audience: [architect, code-reviewer]
  audience:
    - architect
    - code-reviewer
    - security-guardian

Palabras reservadas:
- all-agents: todos los agentes (default implicito).
- humans-only: ningun agente, solo lectura humana.

## Validacion

  bash scripts/context-capability-check.sh

Exit code 1 si algun fichero referencia un agente que no existe en
.opencode/agents/. Modo --strict ademas exige que el campo exista.

## Generacion del audience-graph

  python3 scripts/context-audience-graph.py

Produce dos artefactos en output/:
- context-audience-graph.json (mapping agent -> paths)
- context-audience-cross.tsv (pares con shared agents)

## Integracion knowledge-graph

  bash scripts/knowledge-graph.sh import-audience --tsv output/context-audience-cross.tsv

Importa el TSV como relacion tipada shared_audience.

## Verificacion

  bats tests/test-context-capability.bats

## Refs

- Spec SE-221 en docs/propuestas/
- Spec SE-162 (knowledge graph)
- Debenedetti et al. 2025, CaMeL capability-based (arXiv:2503.18813)
