## SE-235..SE-238 — Mejoras arquitecturales inspiradas en Proto

Inspirado en Proto (Arc Institute / Brian Hie et al., 2026). Cuatro mejoras
que trasladan principios del framework de diseño biológico generativo al
sistema de gestión de proyectos agénticos de Savia.

- SE-235: Dual Pool (Proposal vs Result State) — formaliza la distinción
  entre artefactos en ramas agent/* y artefactos mergeados a main.
- SE-236: Scoring numérico en Code Review Court — cada juez aporta score
  [0.0-1.0]; court-score-aggregator.sh calcula energía total.
- SE-237: Patrón Coarse-to-Fine en DAG Scheduling — gates baratos primero.
- SE-238: Skills schema descubrible — skills-schema.json + .llms.txt.
