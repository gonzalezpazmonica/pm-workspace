---
status: APPROVED
approved_at: 2026-09-30
approval: "Operadora 2026-09-30 en chat (AskUserQuestion): 'Aprobar e implementar'; oculta para todos (admin incluido) como RAG"
priority: P1
developer_type: agent-single
created: 2026-09-30
author: Savia
phase: A
risk: L3
related_specs: [SE-410, SE-419, SE-291]
origin: hueco detectado al implementar SE-419 (desviación 1 y fuera de alcance); la operadora decide atacarlo antes de D09
resource: https://github.com/gonzalezpazmonica/pm-workspace/tree/main/projects/savia-vaults/src/storage
---

# SE-420 — SaviaVaults: una nota con nivel mayor que su cúpula no se sirve

## Problema

Una nota markdown puede declarar `confidentiality: N4` en su frontmatter aunque esté
en una cúpula N2, por ejemplo al moverla o copiarla por error.

- **Savia RAG** ya la omite: el indexador la salta (`skipped: confidentiality:N4`,
  SE-410).
- **El resto de herramientas la sirven** a cualquiera que lea la cúpula: `vault_read`,
  `vault_search` (fragmento), `vault_list`, `vault_tags`, `vault_graph`,
  `vault_query`, `vault_introspect`, `vault_wikilink_health`, los *backlinks* de
  `vault_read` de otras notas, y la búsqueda y lectura A2A.
- **Consecuencia:** un `reader` de la cúpula N2 lee una nota N4 entera. La
  autorización es por cúpula y nunca mira la nota.

## Solución

Mismo criterio que el indexador de RAG, aplicado en la capa común:

- **Qué se considera fuera de nivel.** Una nota **fuera de nivel** es la que tiene
  un `confidentiality` en el frontmatter mayor que el de su cúpula. Se compara con
  `exceedsDomeLevel` (`src/rag/indexer.ts`): la misma función que usa RAG, así que
  las dos vistas deciden igual.
- **`VaultConfig.confidentiality`.** Se añade este campo opcional, y
  `makeConfig(dome)` y A2A lo rellenan con el nivel de la cúpula. Sin él (CLI local
  y vault única), nada cambia: la CLI es del operador.
- **`VaultStorage`**, con nivel:
  - `list()` omite las notas fuera de nivel. Los ficheros `.md` se comprueban con
    una caché por ruta, mtime y tamaño.
  - `read()`, `diff()` y `log()` de una nota fuera de nivel dan `Note not found`
    (no se revela que existe).
  - `write()` rechaza contenido cuyo frontmatter supere el nivel de la cúpula
    (`POLICY_DENIED`). También rechaza sobrescribir una nota fuera de nivel, para no
    destruirla a ciegas.
  - `stats()` cuenta aparte `outOfLevel` (solo el número).
- **`SearchEngine`**, con nivel:
  - no indexa las notas fuera de nivel;
  - la huella de la caché incluye el nivel de la cúpula (reclasificar invalida la
    caché);
  - `CACHE_VERSION` sube para descartar cachés con notas fuera de nivel.
- **Todas las demás vistas** (graph, query, introspect, wikilinks, quality,
  provenance, backlinks) leen a través de `VaultStorage` con la configuración de la
  instancia, así que heredan el filtro sin tocarlas. Se comprueba con tests.
- **Para todos por igual, `admin` incluido,** como hace RAG. Se ve y se corrige desde
  la CLI local o el sistema de ficheros, cambiando la nota de cúpula o su nivel.
  `vault_stats` da el recuento para que Savia pueda avisar.

## Criterios de aceptación

- **AC1** Con una nota N4 en una cúpula N2, por MCP con usuarios:
  - `vault_read` da `Note not found`;
  - `vault_list`, `vault_search`, `vault_tags`, `vault_graph`, `vault_query` y
    `vault_wikilink_health` no la muestran, ni su texto ni sus etiquetas propias;
  - los *backlinks* de otra nota no citan su contexto;
  - `vault_rag` sigue sin devolverla.
- **AC2** A2A: `readDome` y `searchAll` no la devuelven.
- **AC3** `vault_write`:
  - con `confidentiality: N4` en una cúpula N2 da `POLICY_DENIED` y no escribe nada;
  - sobre la ruta de una nota fuera de nivel, también `POLICY_DENIED`;
  - con N2 o sin nivel, funciona como hoy.
- **AC4** `vault_stats` informa de `outOfLevel: 1` sin rutas.
- **AC5** Las notas sin `confidentiality`, o con nivel menor o igual al de la cúpula,
  se sirven igual que hoy. La CLI local (`search`, `stats`…) y una vault sin
  registro de cúpulas no cambian.
- **AC6** Si la cúpula se reclasifica a la baja, la siguiente búsqueda ya no usa la
  caché antigua.
- **AC7** La suite existente sigue en verde. Coste medido: `vault_list` y
  `vault_search` con 1 000 notas, antes y después.

## Entregables (rutas)

- **Código:**
  - `projects/savia-vaults/src/types.ts`, `projects/savia-vaults/src/storage/index.ts`, `projects/savia-vaults/src/storage/note-level.ts`, `projects/savia-vaults/src/search/index.ts`;
  - `projects/savia-vaults/src/rag/indexer.ts` (reexporta la regla común);
  - `projects/savia-vaults/src/registry/domes.ts`, `projects/savia-vaults/src/server/a2a.ts`.
- **Tests:** `projects/savia-vaults/tests/unit/storage/note-level.test.ts`, `projects/savia-vaults/tests/e2e/note-level.test.ts`.
- **Documentación:**
  - `projects/savia-vaults/docs/VAULTS-CLI.md`;
  - `projects/savia-vaults/CHANGELOG.md`, `CHANGELOG.d/se420-vaults-note-level.md`, `.claude/skills/savia-vaults/SKILL.md`;
  - `docs/propuestas/planning-state.json`, `docs/propuestas/LOG.md`, `docs/propuestas/ROADMAP-CURRENT.md`.

## Resultados (2026-09-30)

| AC | Evidencia | Estado |
|---|---|---|
| AC1 | `note-level.test.ts`: `list`/`read`/`diff`/`log`, búsqueda, etiquetas y grafo. E2E MCP stdio: `vault_read` (`Note not found`), `vault_list`, `vault_search`, `vault_tags`, backlinks de otra nota y hits de `vault_rag` sin la nota | OK |
| AC2 | `note-level.test.ts`: `VaultInstance` recibe el nivel del registro; A2A `readDome` y `searchAll` no la devuelven | OK |
| AC3 | Unit + e2e: `POLICY_DENIED` al crear N4/N3 en N2 y al pisar la ruta oculta; sin escribir nada; N2 y sin nivel funcionan | OK |
| AC4 | `vault_stats` → `{noteCount: 1, outOfLevel: 1}` (e2e) | OK |
| AC5 | Sin nivel en la configuración (CLI local), todo se ve y se busca como antes | OK |
| AC6 | La misma caché en disco con nivel N4 y luego N2: la segunda búsqueda ya no devuelve la nota | OK |
| AC7 | Suite completa 689/689, lint limpio. 1.000 notas (20 fuera de nivel), `main` → SE-420: `list` p50 1,2 → 4 ms (primera vez 1 → 31 ms); `search` p50 5,9 → 7,5 ms; índice en frío 82 → 72 ms | OK |

### Desviaciones

1. **Lectura rápida del nivel.** La primera versión pasaba cada nota por `parseNote`
   completo: `list` en frío tardaba 164 ms con 1.000 notas. Ahora solo se parsea el
   YAML si el frontmatter contiene la clave `confidentiality`. Si el bloque no casa,
   decide `parseNote`, así que la semántica es la misma que la de RAG.
2. **Caché del nivel por fichero** (ruta + mtime + tamaño), en memoria del proceso.
   Una nota editada para subir de nivel deja de servirse en cuanto cambia su mtime
   (probado).

## Esfuerzo

Agente 3–5 h · humano 0,5 h.

## Fuera de alcance

- Permisos por rol dentro de la cúpula para notas (listas por nota, como SE-419 en
  ficheros).
- Historial git de una nota ya borrada que estuviera fuera de nivel.
- Mover o reclasificar notas automáticamente.

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| MCP savia-vaults (`vault_read`, `vault_list`, `vault_search`…) | `~/.claude.json` | `opencode.json` (mismo binario) |

### Verification protocol

- [ ] Una nota N4 en una cúpula N2 no aparece en `vault_read` ni `vault_search` en ambos frontends

### Portability classification

- [x] **PURE_NODE**
