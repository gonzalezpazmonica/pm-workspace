---
name: knowledge-prime
description: Generar documento de priming AI desde código y configuración del proyecto
developer_type: all
agent: task
context_cost: moderate
max_context: 5000
allowed_modes: [pm, lead, dev, all]
---

# /knowledge-prime — Generar Priming Doc para AI

> Analiza el proyecto y genera `.priming/` con las 7 secciones de Knowledge Priming (Fowler). Reduce fricción AI de "45 min arreglando" a "5 min revisando".

## Uso
`/knowledge-prime [--project {nombre}] [--update] [--section {1-7}]`

## Subcomandos
- `--project {nombre}`: Proyecto objetivo (default: activo)
- `--update`: Actualizar priming existente en vez de crear nuevo
- `--section {1-7}`: Regenerar solo una sección específica

## Las 7 secciones generadas

### 1. Architecture Overview
- Escanea `CLAUDE.md`, `docs/`, diagramas → extrae tipo de app, componentes, interacciones
- Si hay `diagram-generate` previo → reutiliza

### 2. Tech Stack & Versions
- Lee `package.json`, `pom.xml`, `requirements.txt`, `go.mod`, `Cargo.toml`
- Extrae nombres + versiones exactas
- Formato: `Node.js 20.x, MongoDB 7.x, Ionic 7.x`

### 3. Curated Knowledge Sources
- Busca ADRs en `docs/adr/`, OpenAPI specs, runbooks
- Genera lista de 5-10 refs curadas
- Incluye URLs de docs oficiales para las versiones detectadas

### 4. Project Structure
- Ejecuta `tree` o `ls -R` filtrado
- Genera layout de directorios con anotaciones

### 5. Naming Conventions
- Analiza 20+ archivos: detecta patterns de naming (kebab, camelCase, PascalCase)
- Genera reglas explícitas con ejemplos del propio código

### 6. Code Examples
- Busca archivos bien documentados o con más tests
- Extrae 2-3 snippets representativos del "buen código" del proyecto

### 7. Anti-patterns
- Lee git log de bugs recientes, PRs rechazados
- Genera lista de "qué NO hacer" basada en errores reales

## Output

```
projects/{proyecto}/.priming/
├── architecture.md    ← Secciones 1-2
├── conventions.md     ← Secciones 4-5-7
├── examples/          ← Sección 6 (snippets)
└── sources.md         ← Sección 3
```

Total: ≤3 páginas combinadas. Referencia docs externos para detalle.

## Mantenimiento
- Actualizar al cambiar framework, refactor mayor, o error recurrente
- Tech lead revisa trimestralmente
- PRs que modifiquen priming requieren review

## Persona Savia

El conocimiento no se improvisa, se prepara. Como la buhita que estudia el terreno antes de volar, tu proyecto necesita un mapa claro para que la IA te entienda. Prepara el contexto y la IA te dará respuestas precisas. 🦉
