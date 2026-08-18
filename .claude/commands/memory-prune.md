---
name: memory-prune
description: Poda semántica de memorias con preview seguro y aplicación explícita. Conserva entradas podadas en un tombstone.
developer_type: all
agent: task
context_cost: high
tier: extended
---

# /memory-prune

Gestiona el ciclo de vida de engrams: archiva los de baja importancia,
preserva los críticos y conserva un tombstone para recuperación manual.

## Sintaxis

```
/memory-prune [--preview] [--apply] [--keep-critical] [--lang es|en]
```

## Flags

- `--preview` — Muestra qué se archivará sin ejecutar
- `--apply` — Ejecuta el archivado
- `--keep-critical` — Nunca archiva decision-log, critical-context (defecto: true)
- `--lang es|en` — Idioma de salida (defecto: es)

## Workflow

### 1. Consultar importancia

```bash
/memory-importance --scan
# Genera scores para cada engram (basados en relevancia, recencia, frecuencia)

/memory-prune --preview
# Muestra candidatas de poda basadas en scores < umbral
```

### 2. Revisar propuesta

Ejecución real de preview:

```bash
bash scripts/memory-prune.sh --dry-run
```

Sin `--apply`, este comando SIEMPRE usa `--dry-run` y no modifica el store.

```
Propuesta de Poda
=================
Criterio: Score < 0.35

Candidatos para archivar:
  ❌ 2024-12-05_old-experiment.md (score: 0.28, último acceso: 88d atrás)
  ❌ 2024-11-30_research-spike.md (score: 0.18, nunca consultado)
  
Críticas — se mantienen (--keep-critical):
  ✅ 2025-02-01_architecture.md (score: 0.89, decision-log)
  ✅ 2025-01-15_project-charter.md (score: 0.87, critical-context)

¿Proceder con archivado? (y/n)
```

### 3. Aplicar o descartar

`/memory-prune --apply` explícito habilita la ejecución mutante y delega en:

```bash
bash scripts/memory-prune.sh --apply
```

Mueve candidatos a `output/.memory-tombstone.jsonl` y reescribe
`output/.memory-store.jsonl`. No existe restauración automática: recuperar una
entrada exige revisión humana del tombstone y una escritura explícita.

## Políticas de protección (--keep-critical)

NUNCA se archivan:
- decision-log.md (registro de decisiones del proyecto)
- critical-context.md (contexto crítico definido por el PM)
- Ficheros mencionados en config.yaml `memory.protect_sections`
- Engrams con score de importancia ≥ 0.70

## Archivado

Ubicación: `output/.memory-tombstone.jsonl`. Cada entrada conserva contenido,
`tombstone_ts` y `tombstone_reason`.

## Restauración

No hay subcomando de restauración. La recuperación requiere seleccionar una
entrada del tombstone y guardarla de nuevo mediante el flujo de memoria.

## Impacto en contexto

- **Engram pequeño (<500 tokens)**: Rara vez archivado (no consume contexto significativo)
- **Engram grande (>2000 tokens)**: Candidato para archivado si score < 0.40
- **Engram nunca consultado**: Candidato inmediato para archivado (score tendería a 0)

## Reversibilidad

La poda conserva la entrada completa en el tombstone, pero la restauración no es
automática ni atómica. No afirmar reversibilidad total hasta implementar y probar
un comando de restore.

## Configuración

En `config.yaml`:

```yaml
memory:
  prune:
    score_threshold: 0.35      # Candidatas para archivar si score < 0.35
    keep_critical: true        # NUNCA archivar decision-log
    min_age_days: 30          # Solo si > 30 días de antigüedad
    auto_archive: false       # No hacer automático; usar --apply
    protect_sections:
      - decision-log.md
      - critical-context.md
      - goals-quarterly.md
```

## Casos de uso

1. **Limpieza post-sprint**: Archivar notas de spike que no llegó a feature.
2. **Transición de contexto**: Archivar historiales de proyecto finalizado.
3. **Recuperación de contexto**: Revisar el tombstone y volver a guardar
   explícitamente una entrada que resulte relevante.

---
Persona: Savia — "Una buena memoria no es guardar todo — es saber qué guardar cerca y qué archivar. Y confiar que puedas recuperar cuando lo necesites."
