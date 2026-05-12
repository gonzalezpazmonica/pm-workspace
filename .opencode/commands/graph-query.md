---
name: graph-query
description: Consulta el grafo de conocimiento en lenguaje natural
allowed-tools:
  - Read
  - Grep
  - Bash
context_cost: low
---

# /graph-query {question} [--mode=local|global|hybrid|bypass]

Traduce preguntas en lenguaje natural a graph traversals y retorna resultados.

## Modos (SPEC-113)

- `--mode=local` (default) — entidad específica, 1-2 hops. "¿quién sabe X?"
- `--mode=global` — agregación/summary, traversal amplio. "¿qué skills dominan el equipo?"
- `--mode=hybrid` — combina local + global. "¿quién sabe X en proyecto Y?"
- `--mode=bypass` — lookup directo sin traversal. Metadata concreta.

## Ejemplos de preguntas soportadas

- "¿Quién sabe TypeScript en mi equipo?" (local)
- "¿De qué tareas depende el PBI AB#456?" (local)
- "¿Qué skills dominan el equipo?" (global)
- "¿Qué riesgos afectan el Sprint 2026-04?" (local)
- "¿Cuál es el impacto de la decisión ADR-3?" (hybrid)

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
