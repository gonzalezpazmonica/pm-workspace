# Spec: SE-328 — Dual-mode query: local + global

**Task ID:**        SE-328
**PBI padre:**      SE-328 — Dual-mode query (local/global)
**Sprint:**        2026-08
**Fecha creacion:** 2026-08-14
**Creado por:**     Savia

**Developer Type:** agent-single
**Asignado a:**     typescript-developer
**Estado:**         IMPLEMENTED

**Effort Estimation (Dual Model):**

| Dimension | Value |
|---|---|
| Agent effort | 4 h |
| Human effort | 2 h |
| Review effort | 15 min |
| Context risk | medium |
| Agent-capable | yes |

---

## 1. Contexto y Objetivo

SaviaVaults tiene query local (entidad específica → vecinos, query dot-notation)
pero no razonamiento global: preguntas de tipo "¿cuáles son los temas principales
del vault?" o síntesis cross-documento fallan porque no hay vista agregada.

**Referente**: GraphRAG (Microsoft) distingue **local search** (entidad)
vs **global search** (whole-dataset reasoning) — la estructura del grafo
organiza el dataset en clústeres que permiten resumir temas. LightRAG añade
modos `local` / `global` / `hybrid` / `mix`.

Objetivo: añadir modo **global** determinista (sin LLM, alineado con SE-288
"no embeddings/vectorial"):
- Detección de **comunidades** (componentes conexos + clustering por centralidad)
- Resumen de clúster por tema (por concurrencia de tipos y relaciones)
- Query global: "temas principales", "agrupaciones", "hub más conectado"

## 2. Contrato Tecnico

### 2.1 Community detection

```typescript
// src/knowledge/communities.ts
interface Community {
  id: string;                    // "C1", "C2"...
  memberIds: string[];           // entidades miembro (ordenadas por score PPR)
  dominantTypes: string[];       // tipos más frecuentes (top 3)
  dominantRelations: string[];   // relaciones más frecuentes entre miembros
  size: number;
}

class CommunityDetector {
  /** Componentes conexos del grafo; cada componente = una comunidad. */
  detect(graph: GraphSnapshot): Community[];
}
```

- Componentes conexos (BFS/DFS sobre undirected derivado).
- Dentro de cada comunidad, miembros ordenados por PPR (SE-327).
- `dominantTypes`/`dominantRelations`: frecuencias sobre miembros (sin LLM).

### 2.2 Query global

```typescript
// QueryEngine.query modo 'global' (flag --mode global)
interface GlobalQueryResult {
  mode: 'global';
  communities: Community[];
  summary: string;   // markdown: tamaño, tipos dominantes, hubs (top PPR)
  outputRows: Record<string, unknown>[];
}
```

`vaults query "temas principales" --mode global` y
`vaults query "hub" --mode global` → resumen de comunidades + hubs.

### 2.3 Hybrid

`--mode hybrid` = local (si la query referencia entidades exactas) + global
(comunidades donde viven). Retorna ambos bloques con etiquetas `local`/`global`.

## 3. Criterios de aceptacion

- [ ] AC-1: grafo con 2 componentes desconectados → 2 comunidades.
- [ ] AC-2: miembros de cada comunidad ordenados por PPR descendente.
- [ ] AC-3: dominantTypes refleja los tipos reales más frecuentes del componente.
- [ ] AC-4: `--mode global` en un vault con un solo componente → 1 comunidad + hubs.
- [ ] AC-5: `--mode hybrid` incluye bloques local y global etiquetados.
- [ ] AC-6: grafo vacío → 0 comunidades, summary vacío, no lanza.
- [ ] AC-7: determinista (mismo grafo → mismas comunidades y orden).
- [ ] AC-8: la salida markdown es consumible por el health-report.

## 4. Tests

`tests/communities.test.ts` (vitest): detección, orden PPR, tipos dominantes,
modo global, modo hybrid, vacío, determinismo.
