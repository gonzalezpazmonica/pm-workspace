# SE-288 — Capa de conocimiento: entidades tipadas, introspección, consulta determinista y calidad de la verdad a escala

**Status:** IN_PROGRESS
**Fecha:** 2026-08-01
**Proyecto:** projects/savia-vaults
**Area:** Knowledge graph / Typed query / Provenance / Scale
**Branch:** agent/se288-capa-conocimiento
**Estimación total:** ~72h (8 slices)
**Base:** PR #919 (SaviaVaults v0.2.0). Construye encima, no duplica.

---

## Origen

SaviaVaults v0.2.0 es un servidor de documentos: almacena markdown versionado, lo busca léxicamente, lo firma y lo sirve por MCP/A2A. Esta spec ataca el salto siguiente: **de servidor de documentos a capa de conocimiento**.

### Patrones del referente analizado

1. Grafo de entidades tipadas, no de documentos
2. Relaciones direccionales con nombre
3. Introspección de esquema
4. Lenguaje de consulta determinista con doble salida
5. Observaciones numéricas con taxonomía, unidad y cadencia
6. Procedencia y validez por hecho, no por documento
7. Búsqueda difusa por nombre con alias
8. Densidad de tokens como métrica de producto

### Lo que NO se adopta

- Nada de RAG, embeddings ni búsqueda vectorial
- Nada de datos públicos preprocesados por terceros
- Ninguna dependencia de nube

---

## Slice 1 — Esquema de entidades sobre frontmatter (10h)

Entidades tipadas declaradas por vault (`schema/entities/*.yaml`). Vocabulario base de 7+ tipos extensible sin tocar código. Frontmatter con `entity: {type, id}`. Validación en escritura. Alias como propiedad de primera clase.

[Spec completa en el mensaje original del usuario. Por brevedad, aquí solo el resumen ejecutivo de cada slice.]

---

## Slice 2 — Grafo de relaciones tipadas y direccionales (12h)

Relaciones con nombre y dirección en frontmatter: `relations: [{type, target, since, until}]`. Vocabulario base con inversa declarada. Derivación desde wikilinks. Reconstrucción determinista. Recorrido acotado.

## Slice 3 — Introspección (8h)

Qué puedo preguntar. Tipos presentes, conteos, cobertura, relaciones, rango temporal. Por vault y por entidad. Expuesto en MCP, A2A y CLI. Basado en índice, no en recorrido.

## Slice 4 — Consulta determinista con doble salida (14h)

Notación punteada: `Entidad.propiedad`, `Entidad.relacion.Entidad`, `Entidad.métrica.From=X.To=Y`. Gramática formal, parser propio. Salida en filas tipadas o markdown con citas. Búsqueda difusa por nombre y alias.

## Slice 5 — Procedencia y validez por afirmación (12h)

Afirmación como unidad: `source`, `asserted_at`, `valid_from`/`valid_until`. Bitemporalidad. Observaciones numéricas con taxonomía, unidad y cadencia. Jerarquía de autoridad de fuente. Conflicto explícito.

## Slice 6 — Calidad de la verdad medida (8h)

Indicadores deterministas y recomputables: cobertura, fuente, autoridad, caducidad, conflictos, huérfanos, frescura. Informe de salud. Umbrales declarables. Sin puntuación global.

## Slice 7 — Escala (10h)

Índice persistido y particionado. Reindexado incremental por commit. Paginación y streaming. Presupuesto de recursos declarado.

## Slice 8 — Densidad de tokens (6h)

Banco de preguntas (30+). Comparativa tres vías: crudo, léxico, tipado. Método reproducible. Publicación honesta incluyendo derrotas.

---

## Plan de implementación (scope-down realista)

**Sesión actual: S1 + documentación de plan.** El esquema de entidades es el fundamento sin el cual nada más funciona. S1 entrega: vocabulario base, validación de frontmatter, alias, y tests.

**Próxima sesión: S3 + S2.** Introspección primero (barata, hace útil S1 inmediatamente), luego grafo tipado.

El orden recomendado por la spec es correcto: 1 → 3 → 2 → 4 → 5 → 6 → 7 → 8.
