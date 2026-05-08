---
name: memory-stats
description: Display memory usage statistics and optimization recommendations
---

---

# memory-stats

Estadísticas del índice de memoria semántica.

## Descripción
Muestra métricas de cobertura, antigüedad y tamaño del índice vectorial del proyecto. Útil para verificar si el índice está actualizado y tiene buena cobertura.

## Argumentos
`$ARGUMENTS` — Nombre del proyecto (por defecto: activo)

## Opciones
- `--format {json|table}` — Formato de salida (por defecto: table)

## Salida
Tabla con:
- Total de entradas
- Última actualización
- Cobertura por fuente (%)
- Tamaño fichero índice

## Ejemplo
```
/memory-stats sala-reservas
→ Índice: data/memory-index/sala-reservas.json
  Entradas: 42 | Última actualización: 2026-03-05 09:30
  Cobertura:
    agent-notes: 15 (36%)
    lessons: 10 (24%)
    decisions: 12 (29%)
    postmortems: 5 (12%)
```
