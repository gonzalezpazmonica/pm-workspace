---
name: graph-query
description: Consulta el grafo de conocimiento en lenguaje natural
allowed-tools:
  - Read
  - Grep
  - Bash
context_cost: low
---

# /graph-query {question}

Traduce preguntas en lenguaje natural a graph traversals y retorna resultados.

## Ejemplos de preguntas soportadas

- "¿Quién sabe TypeScript en mi equipo?"
- "¿De qué tareas depende el PBI AB#456?"
- "¿Qué riesgos afectan el Sprint 2026-04?"
- "¿Cuál es el impacto de la decisión ADR-3?"
- "¿Está Alice asignada a más de 75 SP?"

## Ejecución

1. 🏁 Banner: `══ /graph-query ══`
2. **Parsear pregunta**
   - Detectar tipo: "quién sabe" (Member), "qué riesgos" (Risk), etc.
   - Extraer parámetros: nombre skill, PBI, sprint, miembro
3. **Traducir a traversal**
   - Mapear pregunta a ruta de relaciones
   - Ejemplo: "quién sabe X" → Member→HAS_SKILL→Skill(nombre=X)
4. **Ejecutar traversal**
   - Cargar grafo JSONL del proyecto activo
   - Seguir relaciones, recopilar resultados
5. **Formatear resultado**
   - Tabla si múltiples resultados (≤20 filas)
   - Texto narrativo si 1-3 resultados
6. ✅ Banner fin

## Máximo 60 líneas

Documentación comprimida. Detalles de NL→traversal en SKILL.md.
