---
id: SE-033
title: Topic cluster skill — BERTopic sobre retros/backlog/lessons
status: IMPLEMENTED
origin: Hands-On Large Language Models cap.5 (research 2026-04-18)
author: Savia
related: retro-patterns, backlog-patterns, lesson-extract, incident-correlate
approved_at: "2026-04-22"
applied_at: "2026-04-22"
batches: [20]
expires: "2026-05-16"
---

# SE-033 — Topic cluster skill

## Purpose

Si NO hacemos esto: `retro-patterns`, `backlog-patterns`, `lesson-extract` e `incident-correlate` siguen agrupando por reglas heuristicas frag iles (keywords, tags manuales, regex). Resultado: patrones reales cruzando multiples retros/PBIs/incidentes no se ven. Perdemos aprendizaje compuesto.

Cost of inaction: si 3 proyectos tienen un mismo patron de incidente (ej. "bounded concurrency forgotten"), lo descubrimos el tercera vez porque el segundo no triggerea el primero. Equivalente al fork bomb 2026-04-18 — el patron existia pero no se detecto.

## Objective

Introducir skill `topic-cluster` que agrupe documentos (retros, PBIs cerrados, incidentes, lessons) en clusters tematicos usando BERTopic (UMAP + HDBSCAN + c-TF-IDF), con labels legibles generados automaticamente. Criterio de exito: >=3 clusters utiles identificados sobre corpus real de 50+ documentos, donde "util" = un humano al verlos dice "si, esto es un tema real en este proyecto".

## Slicing

- Slice 1: Feasibility Probe (1.5h) — BERTopic sobre 50 retros reales → cluster labels manuales validados
- Slice 2: skill `topic-cluster` + CLI + tests
- Slice 3: integracion en `retro-patterns`, `backlog-patterns`, `lesson-extract`

## Acceptance (resumen)

- [ ] Probe: >=3 clusters utiles en corpus real
- [ ] Skill documentado + 20+ bats tests
- [ ] Backward compatible (opt-in via `--cluster`)

## Riesgos

| Riesgo | Mitigacion |
|---|---|
| BERTopic requiere UMAP + hdbscan (numpy-heavy) | Install on-demand, cached; documentar |
| Clusters ruidosos en corpus <20 docs | Skill requiere minimo 20, sino `fallback: heuristic` |

## Referencias

- Hands-On LLM cap.5: https://github.com/HandsOnLLM/Hands-On-Large-Language-Models/blob/main/chapter05/Chapter%205%20-%20Text%20Clustering%20and%20Topic%20Modeling.ipynb
- BERTopic: https://github.com/MaartenGr/BERTopic

## Dependencia

Espera al Feasibility Probe de SE-032 (reranker). Si SE-032 probe falla, SE-033 tambien es alto riesgo (stack tecnico similar). Si SE-032 probe pasa, SE-033 es low-risk.
