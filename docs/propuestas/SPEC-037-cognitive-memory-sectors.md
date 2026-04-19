---
id: SPEC-037
title: SPEC-037: Cognitive Memory Sectors — Memoria por Tipo con Decay Propio
status: Proposed
origin_date: "2026-03-23"
migrated_at: "2026-04-19"
migrated_from: body-prose
---

# SPEC-037: Cognitive Memory Sectors — Memoria por Tipo con Decay Propio

> Status: **DRAFT** · Fecha: 2026-03-23 · Score: 4.35
> Origen: OpenMemory (3.7K) — 5 sectores cognitivos con decay independiente
> Impacto: Cada tipo de memoria envejece a su ritmo natural

---

## Problema

El context-aging actual aplica los mismos umbrales a toda la memoria:
<30d fresco, 30-90d maduro, >90d antiguo. Pero una decision arquitectonica
sigue siendo relevante a los 6 meses, mientras que un estado de debug
caduca en horas.

OpenMemory resuelve esto con 5 sectores cognitivos, cada uno con
politica de decay independiente.

## Principio inmutable

**Los .md son la fuente de verdad.** Los sectores son una clasificacion
logica sobre ficheros existentes, no una migracion a otra infraestructura.
El frontmatter `type:` del engram determina el sector.

## Solucion

Formalizar los tipos de memoria existentes como sectores con politicas
de decay calibradas independientemente.

### 5 Sectores

| Sector | Tipo actual | Decay | Justificacion |
|--------|-------------|-------|---------------|
| **Episodico** | `feedback` | 60 dias | Correcciones del usuario pierden relevancia si el comportamiento ya cambio |
| **Semantico** | `project` | 180 dias | Decisiones de proyecto duran sprints, no dias |
| **Procedural** | `pattern` | 365 dias | Patrones de trabajo son estables a largo plazo |
| **Referencial** | `reference` | 90 dias | Links y recursos cambian, verificar periodicamente |
| **Reflexivo** | `discovery` | 120 dias | Descubrimientos se consolidan o se olvidan |

### Scoring por sector

Extender `memory-importance.md` con peso por sector:

```
importance = (relevance * 0.4) + (recency_sector * 0.3) + (frequency * 0.3)
```

Donde `recency_sector` usa el decay del sector, no un valor global:
- Episodico: decae rapido (half-life 30d)
- Procedural: decae lento (half-life 180d)

### Poda por sector

`/memory-prune` respeta sectores:
- Episodico: podar agresivamente (>60d sin acceso)
- Semantico: podar conservadoramente (>180d sin acceso)
- Procedural: casi nunca podar (solo si contradice patron mas reciente)
- Referencial: verificar links antes de podar (link roto = podar)
- Reflexivo: consolidar en semantico si se confirmo, podar si no

### Implementacion en .md

No requiere cambio de formato. El campo `type:` en frontmatter
ya clasifica cada engram. Solo se anade la politica de decay:

```yaml
# En memory-system.md o context-aging.md
sectors:
  feedback:    { sector: episodic,    decay_days: 60  }
  project:     { sector: semantic,    decay_days: 180 }
  pattern:     { sector: procedural,  decay_days: 365 }
  reference:   { sector: referential, decay_days: 90  }
  discovery:   { sector: reflective,  decay_days: 120 }
```

### Compatibilidad

- Engrams existentes sin sector → se asigna por `type:` (mapeo arriba)
- Si no tiene `type:` → default a `semantic` (el mas conservador)
- Ningun engram se borra automaticamente → solo se marca para revision
- El PM siempre tiene la ultima palabra en poda

## Integracion

- `context-aging.md`: reemplazar umbrales fijos por umbrales por sector
- `memory-importance.md`: ajustar formula con recency_sector
- `memory-prune`: respetar politica de cada sector
- `memory-stats`: mostrar distribucion por sector

## Esfuerzo

Bajo-medio — 1 sprint. Es una reconfiguracion de politicas sobre
infraestructura existente, no codigo nuevo.
