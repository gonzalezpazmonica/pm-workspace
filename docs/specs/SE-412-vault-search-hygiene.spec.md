---
status: APPROVED
approved_at: 2026-09-29
approval: "Operadora 2026-09-29 en chat: 'Implementa los fix en los gaps pendientes'"
priority: P2
developer_type: agent-single
created: 2026-09-29
author: Savia
phase: A
risk: L1
related_specs: [SE-410, SE-411, SE-310]
origin: gaps pendientes G6/G8 de la medición de eficiencia de Savia RAG (Savia Labs, privada) y ruido de tags del AS-IS de SE-410
resource: https://github.com/gonzalezpazmonica/pm-workspace/tree/main/projects/savia-vaults/src/search
---

# SE-412 — Higiene y arranque en frío de `vault_search`

## Problema

La medición de SE-411 dejó fuera cuatro defectos de `vault_search` (BM25 por
documento), que sigue siendo la herramienta por defecto de muchos agentes:

- **G6 Arranque en frío de la CLI.** `savia-vaults search` reconstruye el índice
  de todo el vault en cada proceso: 1,34–1,40 s en savia-docs.
- **G8 Indexa cualquier fichero.** Entran `.json`, `.jsonl`, `.yaml`, `.txt`
  (p. ej. `llms-full.txt`, que duplica toda la documentación) y no se excluyen
  `node_modules` ni directorios ocultos distintos de `.git/.trash/.savia-vault`.
- **Tags falsos.** Toda secuencia `#palabra` del cuerpo cuenta como tag; las
  referencias a PR o issues (`#648`) llenan el índice de tags numéricos.
- **Respuesta MCP indentada.** `vault_search` devuelve JSON con indentación
  (el mismo sobrecoste de ~22 % medido en `vault_rag`).

Además queda un fallo intermitente, observado una vez, del test de caché por
memoria de SE-411 sin causa identificada.

## Solución

1. **Solo markdown por defecto** (`.md`, `.markdown`); si la cúpula define
   `allowedExtensions`, mandan esas. Se excluyen `node_modules` y todo
   directorio que empiece por `.`.
2. **Tags inline** solo si empiezan por letra (`#arquitectura` sí, `#648` no).
3. **Caché persistente del índice para la CLI**: MiniSearch serializado en
   `$SAVIA_SEARCH_CACHE` (def. `~/.savia-vaults/search-cache/<hash-del-vault>/`),
   invalidado por el fingerprint existente (nº de ficheros + mtime máx.),
   ficheros `0600`, directorios `0700`, negativa a escribir dentro de git (mismo
   guard que Savia RAG). El servidor MCP no la usa (ya mantiene el índice en memoria).
4. **JSON compacto** en `vault_search`, `vault_list`, `vault_tags` y
   `vault_rag_status` por MCP.
5. **Test intermitente**: causa encontrada al instrumentarlo — una cúpula que
   vence el timeout del fan-out seguía viva y cargaba su índice después, dentro
   de la ventana del test siguiente. `fanOut` pasa una `AbortSignal` que se aborta
   al vencer el timeout; la preparación de la cúpula no carga el índice si está
   abortada (el sync puede terminar y deja la cúpula lista).
6. **Índice sin texto completo**: `storeFields` sin `content`; el snippet se lee
   del fichero solo para los hits devueltos. `search` pasa a módulo propio en el
   dispatcher de la CLI (como `rag`).

### Entregables (rutas)

- `projects/savia-vaults/src/search/index.ts`, `projects/savia-vaults/src/cli/main.ts`,
  `projects/savia-vaults/src/cli/index.ts`, `projects/savia-vaults/src/cli/search.ts`,
  `projects/savia-vaults/src/server/mcp.ts`, `projects/savia-vaults/src/rag/parallel.ts`,
  `projects/savia-vaults/src/rag/service.ts`.
- `projects/savia-vaults/tests/unit/search-engine.test.ts`, `projects/savia-vaults/tests/unit/search.test.ts`,
  `projects/savia-vaults/tests/integration/rag/service.test.ts`, `projects/savia-vaults/tests/unit/rag/parallel.test.ts`.
- `projects/savia-vaults/README.md`, `projects/savia-vaults/CHANGELOG.md`,
  `docs/propuestas/planning-state.json`, `docs/propuestas/LOG.md`, `docs/propuestas/ROADMAP-CURRENT.md`.

## Criterios de aceptación

- **AC1** Un vault con `.md`, `.json`, `.txt`, `node_modules/x.md` y `.oculto/y.md`
  indexa solo los `.md` visibles; con `allowedExtensions: ['.txt']` indexa los `.txt`.
- **AC2** `#648` no aparece como tag; `#arquitectura` sí.
- **AC3** Segunda invocación de `savia-vaults search` en savia-docs (caché
  caliente): mediana < 400 ms (hoy 1,37 s). Un cambio de fichero invalida la caché
  y el resultado refleja el cambio.
- **AC4** La caché no se escribe dentro de un repo git y sus ficheros son `0600`.
- **AC5** Calidad no empeora: MRR de `vault_search` sobre `eval/rag-savia-docs.json`
  ≥ 0,251 (valor actual).
- **AC6** Tests existentes en verde; tests nuevos para AC1-AC4.

## Resultados (2026-09-29)

| AC | Objetivo | Resultado |
|---|---|---|
| AC1 | solo markdown visible | cumplido (tests) |
| AC2 | sin tags numéricos | cumplido: 0 tags numéricos en savia-docs |
| AC3 | CLI con caché < 400 ms | **no cumplido**: 1 370 → ~500 ms (−63 %) |
| AC4 | caché 0600 y fuera de git | cumplido (tests) |
| AC5 | MRR ≥ 0,251 | cumplido: 0,275 (recall@10 0,347 igual) |
| AC6 | tests en verde | 459 en verde, 6 ejecuciones completas seguidas sin el fallo intermitente |

AC3: perfil de CPU de una invocación en caliente (514 ms): ~350 ms son la
deserialización del índice de MiniSearch (parse, reconstrucción del árbol y GC)
aun con el índice reducido de 10,7 a 4,1 MB. Bajar de 400 ms exige cambiar el
motor de `vault_search` (fuera de alcance). Para agentes el camino es MCP
(7–32 ms por consulta) o `vault_rag`.

## Esfuerzo

Agente 2 h · humano 20 min.

## Dependencias

SE-310 (fingerprint del índice), SE-410 (guard de home fuera de git).

## Fuera de alcance

Cambiar el motor de `vault_search`; recomendar `vault_rag` ya lo hace la skill.

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| MCP savia-vaults (`vault_search`) | `~/.claude.json` | `opencode.json` (mismo binario) |
| CLI `savia-vaults search` | bash | idéntico |

### Verification protocol

- [ ] `vault_search` devuelve JSON compacto en ambos frontends

### Portability classification

- [x] **PURE_NODE**

## Cierre (2026-10-01)

Graduada por la operadora con AC3 no cumplido y aceptado: la CLI en caliente tarda
~500 ms (objetivo < 400 ms) por la deserialización de MiniSearch; para agentes, el camino es
MCP (7–32 ms por consulta) o `vault_rag`. Un cambio de motor sería otra spec.
