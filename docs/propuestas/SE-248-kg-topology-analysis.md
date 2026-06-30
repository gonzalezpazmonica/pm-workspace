---
id: SE-248
title: "KG Topology Analysis — Forman-Ricci + Leiden sobre el grafo real de agentes/skills"
status: PROPOSED
priority: P1
effort: S (4h — S1 2h scripts + S2 1h integración + S3 1h tests)
origin: Investigación output/research/20260628-kg-optimization-state-of-art-2024-2025.md
author: Savia
related:
  - scripts/knowledge-graph.sh
  - SE-162 (Knowledge Graph implemented)
  - codebase-memory-mcp (grafo estructural)
proposed_at: "2026-06-28"
era: 248
roi: Alto — scripts ya escritos, output inmediato sobre el KG real del workspace
---

# SE-248 — KG Topology Analysis: Forman-Ricci + Leiden

## Objective

Implementar `scripts/kg-topology-analysis.sh` que ejecuta dos algoritmos sobre el KG real
de pm-workspace (exportado desde `scripts/knowledge-graph.sh`): Forman-Ricci curvature para
detectar bottlenecks estructurales, y Leiden community detection para identificar clusters
funcionales entre agentes y skills.

El problema que resuelve: pm-workspace tiene ~200 nodos (agentes, skills, specs, reglas) y
~500 edges en su knowledge graph, pero no existe ninguna métrica cuantitativa de salud topológica.
Los bottlenecks (edges con curvatura muy negativa) indican acoplamiento excesivo entre módulos.
Las comunidades detectadas por Leiden revelan los clusters funcionales reales, que pueden diferir
del layout de carpetas.

Scripts Python ya disponibles en `output/research/`: validados, con benchmarks contra KG sintético.
Esta spec los integra en el workflow de pm-workspace con output estandarizado.

## Principles affected

- #5 Humans decide — los resultados son métricas+recomendaciones, no acciones automáticas.
  Savia propone, el humano actúa.
- #2 Vendor independence — scripts Python stdlib + networkx, sin cloud, sin APIs externas.
- #1 Data sovereignty — el KG es local; ningún dato sale del workspace.

## Design

### Overview

```
scripts/knowledge-graph.sh --export-json
        ↓
output/kg-export-YYYYMMDD.json
        ↓
scripts/kg-topology-analysis.py --input kg-export.json [--forman-ricci] [--leiden] [--all]
        ↓
output/research/kg-topology-YYYYMMDD.md   (informe legible)
output/research/kg-topology-YYYYMMDD.json (datos para herramientas downstream)
```

### Components

| Name | Kind | Purpose |
|---|---|---|
| `scripts/kg-topology-analysis.py` | script Python | Análisis Forman-Ricci + Leiden sobre JSON del KG |
| `scripts/kg-topology-analysis.sh` | wrapper bash | Gate de dependencias + invocación del script Python |
| `tests/test-se248-kg-topology.bats` | test suite | Verificación de smoke tests y outputs |

### Forman-Ricci curvature

Para cada edge `(u,v)`:
```
κ(u,v) = 2/w(u,v) - deg(u)/m(u) - deg(v)/m(v)
```
donde `m(v)` = media de pesos de edges incidentes a v.

Interpretación:
- `κ > 0`: edge en comunidad densa (buena cohesión)
- `κ ≈ 0`: edge neutro
- `κ < -1`: bottleneck — si se elimina, el grafo se fragmenta

Output esperado: ranking top-10 edges más negativos + top-10 más positivos, con nombres
de nodos reales (agente/skill). Métrica global: `mean_curvature` y `bottleneck_ratio` (% edges con κ < -0.5).

### Leiden community detection

Usa `networkx` + implementación propia (sin leidenalg para evitar dependencia C).
Aproximación: Louvain con modularity optimization iterativa hasta convergencia estable.

Output esperado: lista de comunidades con nombre sugerido (derivado del nodo más central)
+ modularity score Q (>0.3 = estructura comunitaria significativa).

### Contracts

Input:
```json
{
  "nodes": [{"id": "architect", "type": "agent"}, ...],
  "edges": [{"source": "architect", "target": "sdd-spec-writer", "weight": 1.0}, ...]
}
```

Output JSON:
```json
{
  "forman_ricci": {
    "mean_curvature": -0.12,
    "bottleneck_ratio": 0.08,
    "top_bottlenecks": [{"edge": ["A","B"], "curvature": -1.4}],
    "top_cohesive": [{"edge": ["C","D"], "curvature": 0.8}]
  },
  "leiden": {
    "modularity": 0.41,
    "num_communities": 7,
    "communities": [{"id": 0, "label": "security-cluster", "members": [...], "size": 12}]
  }
}
```

### Configuration

```bash
KG_TOPOLOGY_MIN_CURVATURE=-0.5   # threshold para marcar bottleneck (default -0.5)
KG_TOPOLOGY_OUTPUT_DIR=output/research  # directorio de salida
KG_TOPOLOGY_FORMAT=both          # json | md | both
```

## Acceptance criteria

1. `scripts/kg-topology-analysis.sh --help` imprime uso y sale con código 0.
2. Con el KG real exportado desde `scripts/knowledge-graph.sh`, el script produce un JSON válido en `output/research/`.
3. El JSON tiene campos `forman_ricci.mean_curvature` (float), `leiden.modularity` (float en [0,1]), `leiden.num_communities` (int > 0).
4. El informe `.md` lista los top-5 bottlenecks con nombres de nodos legibles.
5. `scripts/kg-topology-analysis.py --input /dev/null` sale con código 2 (error de input) sin crash.
6. BATS suite: ≥ 8 tests, calidad ≥ 80 en el auditor.
7. Dependencias: solo `python3`, `networkx`, `numpy`. Sin `leidenalg`, `gudhi` ni cloud.

## Out of scope

- Visualización gráfica del KG (requiere matplotlib o graphviz, fuera del scope de CLI).
- Persistent Homology (SE-249 o posterior).
- Integración automática en CI (esto es un tool on-demand, no un gate automático).
- Análisis de codebase-memory-mcp (usa su propia API; esta spec actúa sobre el KG de docs/specs).

## Dependencies

- Blocked by: ninguno. `scripts/knowledge-graph.sh` ya existe (SE-162).
- Blocks: SE-249 (RotatE usa el mismo JSON de export como input).

## Migration path

Script nuevo, no modifica nada existente. Activación: `bash scripts/kg-topology-analysis.sh`.
Sin flags de feature ni rollback necesario.

## Impact statement

Proporciona la primera métrica cuantitativa de salud topológica del workspace: bottleneck_ratio
y modularity permiten comparar versiones del KG a lo largo del tiempo y detectar regresiones
arquitectónicas. Un bottleneck_ratio > 20% indica acoplamiento patológico que debe atenderse
antes de añadir más agentes. Esfuerzo: 4h. Los scripts Python están validados; solo falta
integración y tests BATS.
