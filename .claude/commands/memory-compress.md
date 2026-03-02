---
name: memory-compress
description: Compresión semántica de memorias (engrams). Reduce tokens hasta 80% preservando fidelidad mediante extracción de entidades, resumen de eventos, condensación de decisiones y deduplicación de contexto.
developer_type: all
agent: task
context_cost: high
---

# /memory-compress

Comprime engrams del proyecto usando técnicas semánticas de reducción de tokens mientras preservas fidelidad y coherencia. Ideal para mantener proyectos con memoria histórica sin consumir contexto excesivamente.

## Sintaxis

```
/memory-compress [--preview] [--apply] [--ratio 80] [--lang es|en]
```

## Flags

- `--preview` — Muestra análisis sin aplicar cambios
- `--apply` — Aplica compresión a archivos de memoria
- `--ratio 80` — Target de reducción de tokens (defecto: 80%)
- `--lang es|en` — Idioma de salida (defecto: es)

## Técnicas

### Entity Extraction
Identifica y consolida referencias a entidades (personas, proyectos, decisiones) para eliminar redundancias.

### Event Summarization
Comprime narrativas de eventos manteniendo causa, acción, resultado (CAR).

### Decision Condensation
Extrae decisión → justificación → impacto de registros extensos.

### Context Deduplication
Elimina contexto repetido entre engrams adyacentes.

## Estructura de Directorios

Busca engrams en: `projects/{project}/engrams/`

```
projects/
  my-project/
    engrams/
      2025-02-15_session.md
      2025-02-20_sprint.md
      2025-03-01_decisions.md
```

## Ejemplo de Uso

```bash
/memory-compress --preview --ratio 75 --lang es
# Analiza todos los engrams, muestra estimación de compresión

/memory-compress --apply --ratio 80
# Comprime engrams preservando 20% (reducción del 80%)

/memory-compress --preview --lang en
# Vista previa en inglés
```

## Salida esperada

```
Análisis de Compresión Semántica
================================
Engram: 2025-02-15_session.md
  Original: 2,450 tokens
  Comprimido: 490 tokens (80% reducción)
  Confianza: 94.2%
  
Engram: 2025-02-20_sprint.md
  Original: 1,800 tokens
  Comprimido: 360 tokens (80% reducción)
  Confianza: 91.5%

Total: 4,250 tokens → 850 tokens (80% reducción)
```

## Notas Importantes

- Preserva siempre "decision-log" y "critical-context"
- Mantiene traces de tradeoffs y alternativas consideradas
- Genera backups antes de aplicar cambios
- Reversible: restaura desde `.backup/` si es necesario

## Configuración Avanzada

En `config.yaml`:

```yaml
memory:
  compression:
    techniques: [entity_extraction, event_summary, decision_condensation]
    preserve_sections: [decision-log, critical-context]
    confidence_threshold: 0.90
```

---
Persona: Savia (búho sabia) — "Cada memoria comprimida es una lección aprendida, guardada con calidez para consultas futuras."
