# Dominio: Memoria Semántica del Proyecto

## Conceptos Clave

**Vector**: Representación numérica de significado semántico. Permite medir similitud entre ideas.

**Embedding**: Proceso de convertir texto a vector en espacio de alta dimensión, capturando semántica.

**Similitud del Coseno**: Métrica de distancia entre vectores (0 = no relacionado, 1 = idéntico).

**Top-K**: Retorna los K resultados más relevantes ordenados por relevancia descendente.

**Índice Vectorial**: Estructura de datos que almacena vectores con acceso rápido por similitud.

## Fuentes de Memoria

| Fuente | Descripción | Uso |
|--------|-------------|-----|
| agent-notes | Observaciones durante ejecución | Contexto de decisiones |
| lessons | Lecciones aprendidas | Patrones y anti-patrones |
| decisions | Decisiones arquitectónicas | Rationale de diseño |
| postmortems | Análisis de incidentes | Resolución de problemas |

## Flujos Principales

1. **Indexación**: Memoria JSONL → Embeddings → Índice vectorial
2. **Búsqueda**: Query natural → Embedding → Similitud → Top-5 resultados
3. **Estadísticas**: Análisis del índice (cobertura, antigüedad, distribución)
