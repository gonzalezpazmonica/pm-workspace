---
name: memory-index
description: Build and maintain memory index for efficient retrieval
---

---

# memory-index

Construir o reconstruir el índice semántico del proyecto.

## Descripción
Indexa todas las memorias del proyecto (agent-notes, lessons, decisions, postmortems) en un índice vectorial JSON. Extrae hechos clave, genera embeddings y almacena en `data/memory-index/{proyecto}.json`.

## Argumentos
`$ARGUMENTS` — Nombre del proyecto a indexar

## Opciones
- `--rebuild` — Forzar reconstrucción completa (por defecto: incremental)
- `--truncate` — Limpiar índice actual antes de reindexar

## Salida
- Confirmación de indexación
- Número de entradas indexadas por fuente
- Timestamp de última actualización
- Ruta del fichero índice

## Ejemplo
```
/memory-index sala-reservas
→ ✅ Indexado: 42 entradas
  - agent-notes: 15
  - lessons: 10
  - decisions: 12
  - postmortems: 5
  📄 Index: data/memory-index/sala-reservas.json
```
