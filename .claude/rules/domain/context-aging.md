---
name: context-aging
description: Protocolo de envejecimiento semantico con sectores cognitivos y temporalidad
auto_load: false
paths: []
---

# Context Aging Protocol

> El contexto que envejece sin comprimirse es deuda cognitiva.

---

## Principio

Inspirado en la consolidacion de memoria del cerebro humano (Winocur & Moscovitch, 2011):
los recuerdos episodicos se transforman en semanticos con el tiempo.

## Sectores cognitivos [SPEC-037]

Cada tipo de memoria envejece a su ritmo natural. Un patron de trabajo
sigue siendo relevante a los 6 meses; un estado de debug caduca en horas.

| Sector | Tipos | Decay (dias) | Half-life | Justificacion |
|--------|-------|:------------:|:---------:|---------------|
| Episodico | feedback, correction | 60 | 30d | Correcciones pierden relevancia si el comportamiento cambio |
| Semantico | decision, project, bug | 180 | 90d | Decisiones duran sprints, no dias |
| Procedural | pattern, convention | 365 | 180d | Patrones de trabajo son estables |
| Referencial | reference | 90 | 45d | Links y recursos cambian, verificar |
| Reflexivo | discovery | 120 | 60d | Descubrimientos se consolidan o se olvidan |

## Umbrales por sector

| Sector | Fresco | Maduro | Antiguo |
|--------|--------|--------|---------|
| Episodico | < 30d | 30-60d | > 60d |
| Semantico | < 60d | 60-180d | > 180d |
| Procedural | < 90d | 90-365d | > 365d |
| Referencial | < 30d | 30-90d | > 90d |
| Reflexivo | < 45d | 45-120d | > 120d |

## Temporalidad [SPEC-034]

Cada hecho tiene validez temporal. No se borra — se marca como superado.

```
valid_from: fecha en que el hecho empezo a ser verdad
valid_to: null (vigente) o fecha en que fue superado
superseded_by: topic_key del hecho que lo reemplaza
```

Al buscar memoria, por defecto solo se devuelven hechos vigentes
(valid_to = null). Flag `--include-superseded` para ver historico.

## Formato de compresion

**Fresco** (completo): mantener con todos los campos.
**Maduro** (comprimido): una linea con fecha + resumen.
**Antiguo**: archivar si no se referencio, migrar a regla si es patron.

## Criterio de migracion vs archivado

Migrar a regla si: referenciado 3+ veces en 90d, aplica multi-proyecto,
es estandar que el equipo sigue.

Archivar si: puntual, sin referencias en 90d, proyecto finalizado.

## Ficheros afectados

| Fichero | Aplica aging | Sector por defecto |
|---|---|---|
| decision-log.md | Si | Semantico |
| agent-notes/ | Si | Episodico |
| adrs/ | No | Permanentes por diseno |
| memory-store (JSONL) | Si | Segun campo `sector` |

## Archivado

- Destino: `.decision-archive/decisions-{YYYYMMDD}.md`
- Mantener 12 ficheros (1 ano)
- Recuperable desde git

## Automatizacion

- `/context-age status` — verificacion rapida
- `/context-age` — analisis con propuesta
- `/context-age apply` — ejecutar con confirmacion
- Savia sugiere si decision-log supera 50 entradas
