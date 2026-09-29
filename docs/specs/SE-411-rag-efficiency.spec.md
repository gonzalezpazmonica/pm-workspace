---
status: APPROVED
approved_at: 2026-09-29
approval: "Operadora 2026-09-29 en chat (AskUserQuestion): Aprobar e implementar"
priority: P1
developer_type: agent-single
created: 2026-09-29
author: Savia
phase: A
risk: L2
related_specs: [SE-410, SE-331]
origin: medición de eficiencia de Savia RAG en Savia Labs (privada); cifras públicas reproducidas sobre savia-docs
resource: https://github.com/gonzalezpazmonica/pm-workspace/tree/main/projects/savia-vaults/src/rag
---

# SE-411 — Eficiencia de Savia RAG: fusión, caché, frío y carga útil

## Problema

Una batería de medición de Savia RAG (con/sin RAG × MCP/CLI, 3 repeticiones, 6
baterías) confirmó que `vault_rag` híbrido por MCP es la mejor configuración para
agentes (savia-docs: MRR 0,251 → 0,565, p95 176 ms), pero encontró cinco
defectos que degradan calidad, latencia o coste de contexto:

- **G1 Fusión entre cúpulas dependiente del orden.** La fusión RRF por rango da
  la misma puntuación al primer resultado de cada cúpula y el empate lo decide el
  orden de la lista. Con savia-docs + 3 cúpulas: si savia-docs va primera,
  MRR 0,480; si va última, **MRR 0,125 y top-1 0** (solo savia-docs: 0,565).
- **G2 Caché de índices menor que las cúpulas habilitadas.** El LRU guarda 4
  índices y hay 5 cúpulas con `rag.enabled`: `domes: "*"` desaloja en bucle y
  recarga savia-docs (44 MB + BM25) en cada llamada: **1,9 s** frente a
  150–195 ms con 4 cúpulas.
- **G3 Descarga del modelo.** Ollama descarga el modelo de embedding a los 5 min
  sin uso; la primera consulta tras la pausa tarda **1,37 s** (1,35 s de carga).
- **G4 Carga útil inflada.** La respuesta MCP es JSON indentado (+22 %) y con
  metadatos por hit; el texto útil es el **36 %** de la respuesta. `maxChars` solo
  recorta el texto: con k=8, pasar de 12 000 a 4 000 apenas reduce un 12 %.
- **G5 Arranque en frío de la CLI.** Cada proceso resuelve el contrato con un
  embedding de sondeo extra (embed 222 ms en CLI frente a 102 ms en MCP) y
  reconstruye BM25 sobre todos los chunks: `rag search` en savia-docs tarda
  **2,48 s** de mediana.

## Solución

1. **G1 — Fusión invariante al orden.** Si todas las cúpulas del fan-out
   comparten contrato (mismo `generation`), ordenar los candidatos de todas las
   cúpulas por coseno global (los vectores son comparables); desempates por
   rango BM25 local y luego por `dome`/`path` (determinista). Con contratos
   distintos, RRF con desempate determinista (nunca por orden de entrada) y
   `detail` avisando de que la fusión no está calibrada. Simulación sobre el
   banco de savia-docs: MRR 0,557 (99 % de la cúpula sola) con cualquier orden.
2. **G2 — Caché dimensionada.** LRU con capacidad = nº de cúpulas habilitadas y
   tope por memoria `SAVIA_RAG_MEMORY_MB` (def. 512). `rag status` muestra la
   memoria cargada.
3. **G3 — keep_alive por petición.** `OllamaEmbedder` envía `keep_alive`
   (`SAVIA_RAG_KEEP_ALIVE`, def. `30m`) solo en las llamadas de embedding, sin
   afectar a otros modelos del servidor Ollama.
4. **G4 — Respuesta compacta.** JSON sin indentar en `vault_rag`; parámetro
   `fields` con perfil `lean` por defecto (`dome`, `confidentiality`, `path`,
   `heading`, `text`, `score`) y `full` bajo demanda; `maxChars` pasa a acotar la
   respuesta entera. Defaults nuevos: `k=8`, `maxChars=6000` (sobre la respuesta
   entera equivale a ~4 400 caracteres de texto, el presupuesto medido como óptimo;
   4 000 sobre la respuesta dejaría ~300 caracteres por hit).
5. **G5 — CLI en frío.** Contrato de consulta desde el manifest + comprobación de
   digest vía `/api/tags` (sin embedding de sondeo) y caché del índice BM25
   serializado por `generation/seq`.

### Entregables (rutas)

- Código: `projects/savia-vaults/src/rag/*.ts` (incl. `projects/savia-vaults/src/rag/format.ts`),
  `projects/savia-vaults/src/server/mcp.ts`, `projects/savia-vaults/src/cli/index.ts`,
  `projects/savia-vaults/src/cli/main.ts`, `projects/savia-vaults/src/cli/rag.ts`.
- Tests: `projects/savia-vaults/tests/unit/rag/*.test.ts`,
  `projects/savia-vaults/tests/integration/rag/*.test.ts`,
  `projects/savia-vaults/tests/e2e/mcp-rag.test.ts`, `projects/savia-vaults/tests/e2e/cli-rag.test.ts`.
- Documentación: `docs/rules/domain/rag-embedding-policy.md`,
  `.claude/skills/savia-vaults/SKILL.md`, `projects/savia-vaults/README.md`,
  `projects/savia-vaults/CHANGELOG.md`, `docs/propuestas/planning-state.json`,
  `docs/propuestas/LOG.md`, `docs/propuestas/ROADMAP-CURRENT.md`.

## Criterios de aceptación

- **AC1** (G1) Permutar el orden de `domes` produce exactamente el mismo ranking.
  Con savia-docs + SaviaLearning + SaviaDomains + Fronesia sobre el banco
  `eval/rag-savia-docs.json`, el MRR multi-cúpula es ≥ 0,90 × el de savia-docs sola
  en cualquier orden (hoy: 0,22 × en el peor orden).
- **AC2** (G2) Con 5 cúpulas habilitadas y el proceso en caliente, p95 de
  `vault_rag` con `domes:"*"` < 400 ms (hoy 2,0 s); nunca se recarga un índice ya
  cargado mientras la memoria total esté bajo `SAVIA_RAG_MEMORY_MB`.
- **AC3** (G3) Tras 6 min sin consultas, la primera `vault_rag` tarda < 300 ms
  (hoy 1,37 s); las peticiones a `/api/embed` llevan `keep_alive`.
- **AC4** (G4) Con los defaults nuevos, la respuesta de `vault_rag` (k=8) mide
  ≤ 6 000 caracteres de media en el banco de savia-docs (hoy 13 346 con k=10
  y maxChars 12 000), el texto útil es ≥ 60 % de la respuesta y la calidad no
  cambia (misma lista de paths).
- **AC5** (G5) `savia-vaults rag search` en savia-docs: mediana < 1,0 s (hoy
  2,48 s); una sola llamada de embedding por proceso para la consulta.
- **AC6** No regresión: `rag eval` en savia-docs mantiene MRR y recall@10 dentro
  de ±0,01; los 438 tests existentes siguen en verde; tests nuevos para AC1-AC5
  sin red (proveedor de test).

## Resultados (2026-09-29)

| AC | Objetivo | Antes | Después |
|---|---|---|---|
| AC1 | ranking invariante; MRR multi ≥ 0,90 × solo | 0,22 × en el peor orden | 36/36 rankings idénticos; 0,557/0,565 = 0,986 × |
| AC2 | `"*"` p95 < 400 ms | 2 032 ms | 154 ms |
| AC3 | 1ª consulta tras 6 min < 300 ms | 1 369 ms | 201 ms (modelo retenido; `ollama ps` 23 min restantes) |
| AC4 | ≤ 6 000 caracteres, texto ≥ 60 % | 13 346 (k=10) | 5 390, texto 61 % |
| AC5 | CLI mediana < 1,0 s | 2 482 ms | 925 ms (p95 972) |
| AC6 | eval ±0,01 | 0,806 / 0,566 | 0,806 / 0,566 |

G5 necesitó más que lo previsto: el índice BM25 persistido carga en ~460 ms
(reconstrucción del árbol de MiniSearch) y la CLI importaba todo el servidor
(240 ms de arranque). Se separó la CLI `rag` en su propio módulo (arranque
100 ms) y se solapa el embedding de la consulta con la carga de BM25.

## Esfuerzo

| Slice | Contenido | Agente | Humano |
|---|---|---|---|
| S1 | G1 fusión invariante + tests de permutación | 2 h | 30 min |
| S2 | G2 caché por memoria + G3 keep_alive | 1,5 h | 20 min |
| S3 | G4 respuesta compacta, `fields`, `maxChars` global | 1,5 h | 20 min |
| S4 | G5 contrato desde manifest + caché BM25 | 2 h | 30 min |
| S5 | Re-medición completa y documentación | 1 h | 20 min |

Total: 8 h agente, 2 h humano.

## Dependencias

SE-410 (Savia RAG, mergeada en #1188). Ollama local.

## Fuera de alcance

`vault_search` (reconstrucción del índice por proceso en CLI, indexación de
ficheros no markdown), reranker, fusión calibrada entre contratos distintos.

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| MCP savia-vaults (`vault_rag`) | `~/.claude.json` | `opencode.json` `mcp.savia-vaults` (mismo binario) |
| CLI `savia-vaults rag` | bash | idéntico |

### Verification protocol

- [ ] `vault_rag` con `fields: "lean"` devuelve lo mismo en ambos frontends
- [ ] `rag search` en frío < 1 s en ambos

### Portability classification

- [x] **PURE_NODE**
