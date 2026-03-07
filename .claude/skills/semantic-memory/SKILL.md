---
name: semantic-memory
description: semantic-memory
maturity: alpha
---

# semantic-memory

**Descripción**: Capa de búsqueda semántica sobre la memoria del proyecto usando embeddings y similitud vectorial.

## Arquitectura de Memoria

El sistema de memoria del proyecto consta de tres capas:

1. **Session (Efímera)**: Conversación actual, residente en memoria del agente
2. **Project (Persistente)**: Archivos JSONL en `data/memory-store/`, accesibles vía `memory-store.sh`
3. **Semantic (Índice Vectorial)**: NUEVO — búsqueda por similitud semántica

## Indexación Semántica

**Fuentes de Indexación**:
- `data/memory-store/agent-notes.jsonl` — Observaciones y notas del agente
- `data/memory-store/lessons.jsonl` — Lecciones aprendidas
- `data/memory-store/decisions.jsonl` — Decisiones arquitectónicas
- `data/memory-store/postmortems.jsonl` — Análisis post-mortem

**Proceso de Indexación**:
1. Leer cada documento de fuentes JSONL
2. Extraer hechos clave (summary, decisions, outcomes)
3. Generar embeddings (representación vectorial en espacio de alta dimensión)
4. Almacenar en índice vectorial con metadatos de fuente

## Almacenamiento

**Ubicación**: `data/memory-index/{project}.json`

**Formato Ligero** (sin BD externa):
```json
{
  "metadata": {
    "project": "nombre",
    "last_updated": "2026-03-07T10:30:00Z",
    "entry_count": 42,
    "coverage": { "agent-notes": 15, "lessons": 10, "decisions": 12, "postmortems": 5 }
  },
  "vectors": [
    {
      "id": "uuid",
      "text": "hecho key",
      "embedding": [...],
      "source": "lessons",
      "relevance": 0.95,
      "metadata": { "project": "...", "date": "..." }
    }
  ]
}
```

## Búsqueda Semántica

**Flujo de Consulta**:
1. Entrada: consulta en lenguaje natural (ej: "¿qué aprendimos del módulo auth?")
2. Generar embedding de la consulta
3. Calcular similitud del coseno contra todos los vectores indexados
4. Retornar Top-K resultados ordenados por relevancia
5. Incluir: texto original, fuente, score de similitud

**Casos de Uso**:
- "¿Qué decidimos sobre caché?" → busca decisiones relacionadas
- "Bugs similares a este problema de autenticación" → identifica patrones
- "Lecciones sobre manejo de errores" → recopila experiencias

## Mantenimiento del Índice

- **Reconstrucción bajo demanda**: Comando `/memory-index {project}`
- **Actualizaciones incrementales**: Agregar nuevas memorias sin reindexar todo
- **Versionado**: Metadatos de actualización para tracking de cambios

## Dependencias

- Embeddings: Utiliza modelo de embeddings local/embeddings-api (sin especificar aquí, delegar a runtime)
- Similitud: Cálculo de coseno estándar
- Sin dependencias externas de BD (JSON puro)
