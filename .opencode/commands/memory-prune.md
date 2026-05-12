---
name: memory-prune
description: Poda semántica inteligente de memorias. Archiva engrams de baja importancia, mantiene críticas. Usa scores de /memory-importance. Reversible con restore.
developer_type: all
agent: task
context_cost: high
---

# /memory-prune

Gestiona el ciclo de vida de engrams: archiva los de baja importancia,
preserva los críticos, permite restauración. Equilibra accesibilidad vs.
sobrecarga de contexto histórico.

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

```bash
/memory-prune --apply
# Archiva candidatos a .archive/, genera índice reversible

/memory-prune --restore 2024-12-05
# Recupera un engram archivado específico
```

## Políticas de protección (--keep-critical)

NUNCA se archivan:
- decision-log.md (registro de decisiones del proyecto)
- critical-context.md (contexto crítico definido por el PM)
- Ficheros mencionados en config.yaml `memory.protect_sections`
- Engrams con score de importancia ≥ 0.70

## Archivado

Ubicación: `projects/{proyecto}/engrams/.archive/{YYYYMMDD}/`

```
.archive/
  2025-03-01/
    2024-12-05_old-experiment.md
    2024-11-30_research-spike.md
    INDEX.md  ← Catálogo de archivados con fechas y motivos
```

## Restauración

```bash
/memory-prune --list-archived
# Enumera qué hay en .archive/

/memory-prune --restore {fecha-o-nombre}
# Mueve el engram de vuelta a engrams/

/memory-prune --restore-all {fecha}
# Restaura todos los archivados en una fecha específica
```

## Impacto en contexto

- **Engram pequeño (<500 tokens)**: Rara vez archivado (no consume contexto significativo)
- **Engram grande (>2000 tokens)**: Candidato para archivado si score < 0.40
- **Engram nunca consultado**: Candidato inmediato para archivado (score tendería a 0)

## Reversibilidad

El archivado es **100% reversible**:
1. INDEX.md registra por qué se archivó (score, fecha, causa)
2. Contenido original preservado íntegro
3. Restauración es operación atómica

No hay eliminación permanente de engrams en este comando.
Para eliminar permanentemente, usar `/memory-destroy` (requiere confirmación explícita).

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
3. **Recuperación de contexto**: Si un engram archivado resulta relevante,
   `/memory-prune --restore` lo trae de vuelta sin fricciones.

---
Persona: Savia — "Una buena memoria no es guardar todo — es saber qué guardar cerca y qué archivar. Y confiar que puedas recuperar cuando lo necesites."
