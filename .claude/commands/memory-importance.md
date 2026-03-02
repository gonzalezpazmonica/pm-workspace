---
name: memory-importance
description: Scoring semántico de importancia de engrams usando fórmula composita (relevancia × recencia × frecuencia). Identifica memorias críticas para mantener y candidatas para poda.
developer_type: all
agent: task
context_cost: high
---

# /memory-importance

Califica la importancia de cada engram usando una fórmula composita que combina relevancia contextual, recencia temporal y frecuencia de acceso. Permite tomar decisiones informadas sobre qué memorias preservar.

## Sintaxis

```
/memory-importance [--scan] [--threshold 0.5] [--lang es|en]
```

## Flags

- `--scan` — Ejecuta escaneo completo de engrams
- `--threshold 0.5` — Umbral de importancia (0.0-1.0, defecto: 0.5)
- `--lang es|en` — Idioma de salida (defecto: es)

## Fórmula de Importancia

```
Score = (Relevancia × 0.4) + (Recencia × 0.35) + (Frecuencia × 0.25)

Relevancia: ¿Qué tan relevante es para decisiones futuras? (0-1)
Recencia: ¿Qué tan reciente? (0-1, basado en fecha)
Frecuencia: ¿Cuán a menudo se consulta? (0-1)
```

## Ejemplo de Uso

```bash
/memory-importance --scan --threshold 0.7 --lang es
# Lista engrams por importancia, solo ≥0.7

/memory-importance --scan
# Ranking completo de importancia

/memory-importance --threshold 0.3
# Identifica memorias de baja importancia para considerar poda
```

## Salida esperada

```
Ranking de Importancia de Engrams
==================================

Críticas (0.75-1.0):
  2025-02-01_architecture.md       — Score: 0.89
  2025-01-15_project-charter.md    — Score: 0.87
  2025-02-28_tech-decisions.md     — Score: 0.82

Relevantes (0.5-0.74):
  2025-02-20_sprint-review.md      — Score: 0.68
  2025-02-10_learnings.md          — Score: 0.62

Candidatas para Poda (<0.5):
  2025-01-05_meeting-notes.md      — Score: 0.35
  2024-12-28_archived-discussion.md — Score: 0.28
```

## Pesos Personalizables

En `config.yaml`:

```yaml
memory:
  importance:
    weights:
      relevance: 0.4    # Importancia relativa
      recency: 0.35     # Peso temporal
      frequency: 0.25   # Accesos históricos
    decay_rate: 0.1     # % reducción mensual por antigüedad
```

## Integración con /memory-prune

Los scores de importancia alimentan `/memory-prune` para decisiones de archivado automático.

## Notas

- Recalcula frecuencia de acceso desde logs de sesión
- Detecta "memoria fantasma" (creada pero nunca consultada)
- Genera reportes de tendencias (memorias que ganan/pierden importancia)

---
Persona: Savia — "Cada memoria tiene un valor único. Mi rol es ayudarte a verlo con claridad."
