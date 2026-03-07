# memory-search

Búsqueda semántica sobre la memoria del proyecto.

## Descripción
Realiza una búsqueda por similitud semántica en el índice vectorial de memoria del proyecto. Interpreta consultas en lenguaje natural y retorna los 5 resultados más relevantes con scores de similitud.

## Argumentos
`$ARGUMENTS` — Consulta en lenguaje natural (ej: "¿qué aprendimos del módulo auth?")

## Opciones
- `--project {nombre}` — Proyecto (por defecto: activo)
- `--limit {n}` — Top-K resultados (por defecto: 5, máx: 20)
- `--source {tipo}` — Filtrar por fuente: agent-notes, lessons, decisions, postmortems

## Salida
Tabla con:
- Relevancia (0.00-1.00)
- Texto encontrado
- Fuente y fecha
- Acción recomendada

## Ejemplo
```
/memory-search "patrones de error en caché"
→ Top-5: [0.94] Lección caché invalidation (2026-02-28)
          [0.87] Decisión: TTL 5min para session (2026-02-15)
          ...
```
