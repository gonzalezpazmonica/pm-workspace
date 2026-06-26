---
spec_id: SE-218
title: "codebase-memory patterns: hook augmentation, kg snapshot, qualified names, tiered export, saviaignore"
status: IMPLEMENTED
priority: P2
effort: M
era: 205
origin: https://github.com/DeusData/codebase-memory-mcp (3.2k stars, MIT)
resource: "https://github.com/DeusData/codebase-memory-mcp"
inspiration: codebase-memory-mcp v0.7.0 — high-performance code intelligence engine (arXiv:2603.27277)
deps:
  - scripts/knowledge-graph.py (implemented — SE-162)
  - .claude/hooks/ast-comprehend-hook.sh (implemented)
  - scripts/confidentiality-scan.sh (implemented)
  - scripts/session-action-log.sh (implemented)
created: 2026-06-10
---

# SE-218 — codebase-memory patterns: 5 slices de codebase-memory-mcp aplicados a pm-workspace

## Contexto

[codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp) (DeusData, MIT, 3.2k stars) es un
engine de análisis estructural de código que construye un knowledge graph persistente via tree-sitter.
Benchmarks publicados (arXiv:2603.27277): 99.2% reducción de tokens vs grep/read file-by-file, <1ms queries,
indexa el kernel Linux en 3 minutos.

pm-workspace **no adopta el binario ni el protocolo MCP** — son incompatibles con la arquitectura de hooks
bash y el modelo de agentes. Lo que sí extrae son **5 patrones de diseño** directamente aplicables:

1. Hook de augmentación no-bloqueante sobre Grep/Glob
2. Snapshot versionado del KG en el repo (`.zst` comprimido, `merge=ours`)
3. Qualified names como contrato canónico de búsqueda en el KG
4. Exportación en dos tiers (best/fast) según contexto de invocación
5. `.saviaignore` — capa de exclusiones específica de herramienta

Cada slice es independiente y deployable sin los demás.

---

## Slice 1 — Hook de augmentación no-bloqueante (`ast-comprehend-hook.sh` refactor) ~2h

### Problema

`ast-comprehend-hook.sh` actúa como gate (puede bloquear con exit distinto de 0). El patrón correcto
demostrado por codebase-memory-mcp es distinto: el hook intercepta `Grep`/`Glob`, consulta el índice
estructural, **inyecta resultados como `additionalContext`** y siempre sale con exit 0. El agente recibe
contexto enriquecido sin que ninguna herramienta quede bloqueada.

> "Hooks are structurally non-blocking (exit code 0, every failure path). The PreToolUse hook intercepts
> Grep/Glob (never Read — gating Read breaks the read-before-edit invariant) and injects them as
> additionalContext via search_graph so the agent gets structured context alongside its normal search."
> — codebase-memory-mcp README

### Solución

Refactorizar `ast-comprehend-hook.sh` para que:
1. Siempre salga con exit 0 (nunca bloquea)
2. Intercepte solo `Grep`/`Glob` — nunca `Read`
3. Si encuentra coincidencias en el ACM, las inyecte como `additionalContext` en el JSON de respuesta
4. Si falla cualquier step interno: silencio + exit 0

### Contrato

```bash
# Input: CLAUDE_TOOL_INPUT JSON con tool_name=Grep|Glob y query
# Output: stdout vacío si no hay contexto extra, o:
# {"additionalContext": "ACM matches for '<pattern>':\n<results>"}
# Exit: siempre 0

bash .claude/hooks/ast-comprehend-hook.sh
# Nunca bloquea. Enriquece cuando puede, silencio cuando no.
```

### Tests

- `test-ast-comprehend-hook.bats`: 8 tests
  - hook con Grep que coincide → additionalContext en stdout
  - hook con Glob que coincide → additionalContext en stdout
  - hook con Read → exit 0, stdout vacío (no intercepta Read)
  - hook con fallo interno (ACM no disponible) → exit 0, stdout vacío
  - hook con Bash → exit 0, stdout vacío (no intercepta Bash)
  - output es JSON válido cuando hay contexto
  - exit siempre 0 en todos los casos anteriores
  - no introduce latencia > 200ms (timeout test)

### Criterios de aceptación

- [ ] `ast-comprehend-hook.sh` sale con exit 0 en todos los paths
- [ ] Nunca intercepta `Read` (invariante read-before-edit preservada)
- [ ] Inyecta `additionalContext` cuando ACM tiene resultados relevantes
- [ ] Tests: 8/8 passing, score SPEC-055 ≥ 80

---

## Slice 2 — KG snapshot versionado (`scripts/kg-export.sh`) ~3h

### Problema

`scripts/knowledge-graph.py` regenera el grafo desde cero en cada sesión. En repos grandes esto cuesta
tiempo y tokens. No hay forma de que un colaborador o agente nuevo arranque desde un estado ya indexado.

codebase-memory-mcp resuelve esto con un artefacto comprimido versionado en el repo:
- Format: SQLite compactado (`VACUUM INTO`) + zstd compresión (ratio 8-13:1 típico)
- `.gitattributes merge=ours` evita conflictos en el binario
- Bootstrap: si existe el artefacto, importar y hacer indexado incremental

### Solución

Script `scripts/kg-export.sh` con dos modos:

```bash
# Exportación completa (best) — tras index_repository explícito
bash scripts/kg-export.sh export --mode best

# Exportación rápida (fast) — invocada por watcher incremental
bash scripts/kg-export.sh export --mode fast

# Importar snapshot existente (bootstrap de sesión nueva)
bash scripts/kg-export.sh import

# Ver estado del snapshot
bash scripts/kg-export.sh status
```

El snapshot se guarda en `.savia-kg/graph.db.zst`. Una línea en `.gitattributes`:
```
.savia-kg/graph.db.zst merge=ours
```

El `import` descomprime, verifica integridad (SHA-256 del `.zst`), y registra el timestamp de origen.
Si la importación falla: warning + continúa sin snapshot (no bloquea).

### Contrato

```bash
# export --mode best: zstd -9 + VACUUM, escribe .savia-kg/graph.db.zst
# export --mode fast: zstd -3, escribe .savia-kg/graph.db.zst (sobreescribe)
# import: descomprime + verifica SHA, restaura en output/knowledge-graph.db
# status: muestra tamaño, timestamp, ratio, SHA
# Exit: 0 siempre (fallos son WARN en stderr, nunca exit 2)
```

### Tests

- `test-kg-export.bats`: 10 tests
  - export --mode best crea .savia-kg/graph.db.zst
  - export --mode fast es más rápido que best (timing relativo)
  - status muestra campos requeridos (tamaño, timestamp, SHA)
  - import restaura DB correctamente
  - import con .zst corrupto: warning + exit 0 (no bloquea)
  - import sin .zst existente: warning + exit 0
  - .gitattributes contiene la línea merge=ours tras primer export
  - SHA-256 del import coincide con el del export
  - fast sobreescribe best sin error
  - modo desconocido: exit 2 con mensaje claro

### Criterios de aceptación

- [ ] `kg-export.sh export --mode best` produce `.savia-kg/graph.db.zst`
- [ ] Ratio de compresión ≥ 3:1 sobre un KG de prueba de 1MB
- [ ] `.gitattributes` actualizado automáticamente con `merge=ours`
- [ ] Import falla gracefully (nunca bloquea sesión)
- [ ] Tests: 10/10, score SPEC-055 ≥ 80

---

## Slice 3 — Qualified names en el KG (`scripts/knowledge-graph.py` + `scripts/kg-query.sh`) ~2h

### Problema

El KG actual usa nombres cortos sin namespace (ej: `memory-store`, `pr-plan`). Colisiones entre proyectos
son posibles. codebase-memory-mcp demuestra que el contrato `<project>.<path_parts>.<name>` resuelve
ambigüedades y hace las queries reproducibles entre sesiones.

### Solución

Añadir campo `qualified_name` a los nodos del KG con formato `<project_slug>.<module>.<name>`:

```python
# Ejemplo: en pm-workspace
"qualified_name": "pm-workspace.scripts.memory-store"
"qualified_name": "pm-workspace.docs.rules.domain.radical-honesty"
"qualified_name": "trazabios.src.auth.jwt-validator"
```

`scripts/kg-query.sh` acepta qualified names como selector primario:

```bash
# Buscar por qualified name exacto
bash scripts/kg-query.sh get "pm-workspace.scripts.memory-store"

# Buscar por patrón (sigue funcionando)
bash scripts/kg-query.sh search "memory-store"

# Listar todos los qualified names de un proyecto
bash scripts/kg-query.sh list --project pm-workspace
```

La generación del qualified name es determinista: `slugify(project) + "." + path_without_ext.replace("/",".")`.

### Tests

- `test-kg-qualified-names.bats`: 8 tests
  - nodo generado tiene campo qualified_name
  - qualified_name sigue formato <project>.<path>.<name>
  - qualified_name es único por nodo (no colisiones en fixture)
  - kg-query.sh get con QN exacto retorna el nodo correcto
  - kg-query.sh search sigue funcionando con nombre corto
  - kg-query.sh list --project filtra por proyecto
  - QN de dos proyectos distintos no colisionan
  - QN es estable entre re-indexaciones del mismo nodo

### Criterios de aceptación

- [ ] Todos los nodos nuevos tienen `qualified_name`
- [ ] `kg-query.sh get <qn>` resuelve sin ambigüedad
- [ ] Backward compatible: búsqueda por nombre corto sigue funcionando
- [ ] Tests: 8/8, score SPEC-055 ≥ 80

---

## Slice 4 — Exportación en dos tiers de session-action-log ~1h

### Problema

`session-action-log.sh` escribe entradas síncronamente en el hot path de hooks. codebase-memory-mcp
demuestra que la compresión pesada (best tier) no debe ejecutarse en el path de escritura frecuente:
el watcher usa compresión rápida (`zstd -3`) y solo el comando explícito usa compresión máxima.

Aplicado al log: comprimir el log al cierre de sesión (Stop hook), no en cada append.

### Solución

Añadir a `session-action-log.sh` dos modos de flush:

```bash
# Flush rápido — escribe entrada sin comprimir (comportamiento actual)
bash scripts/session-action-log.sh log "pr-plan" "main" "pass" "G5b"

# Flush best — comprime el log del día al cerrar sesión (Stop hook)
bash scripts/session-action-log.sh flush --mode best

# Flush fast — comprime con ratio bajo (invocado por Pre-compact hook)
bash scripts/session-action-log.sh flush --mode fast
```

El Stop hook existente llama a `flush --mode best`. El Pre-compact hook llama a `flush --mode fast`.
Ambos son no-bloqueantes (exit 0 siempre).

### Tests

- `test-session-action-log-flush.bats`: 6 tests
  - log escribe entrada sin comprimir (comportamiento actual preservado)
  - flush --mode best comprime el log del día
  - flush --mode fast comprime con latencia menor que best
  - flush en log vacío: no crash, exit 0
  - flush --mode desconocido: exit 2
  - log tras flush --mode fast sigue funcionando (appends al fichero restaurado)

### Criterios de aceptación

- [ ] `log` no cambia comportamiento actual (no regresión)
- [ ] `flush --mode best` reduce tamaño del log ≥ 30%
- [ ] Stop hook actualizado para llamar `flush --mode best`
- [ ] Tests: 6/6, score SPEC-055 ≥ 80

---

## Slice 5 — `.saviaignore` — exclusiones específicas de herramienta ~1h

### Problema

`confidentiality-scan.sh`, `shield`, y otros scripts tienen listas de exclusión hardcodeadas en bash.
Añadir un nuevo patrón de exclusión requiere editar el script. codebase-memory-mcp resuelve esto con
`.cbmignore`: un fichero con sintaxis gitignore, aplicado en cascada después de `.gitignore`, específico
de la herramienta.

### Solución

`.saviaignore` en la raíz del repo con sintaxis gitignore estándar. Los scripts que hoy tienen listas
hardcodeadas leen este fichero como capa adicional:

```
# .saviaignore — exclusiones específicas de herramientas Savia
# Sintaxis: gitignore estándar
# Se aplica después de .gitignore

# Directorios de output temporales
output/agent-run-log-*.tsv

# Snapshots KG
.savia-kg/

# Ficheros de test fixtures sensibles
tests/fixtures/secrets/
```

`scripts/savia-ignore.sh` — helper que evalúa si un path está excluido:

```bash
# Retorna 0 si el path debe ignorarse, 1 si no
bash scripts/savia-ignore.sh "output/agent-run-log-20260610.tsv"
# EXIT: 0 (ignorado)

bash scripts/savia-ignore.sh "scripts/memory-store.sh"
# EXIT: 1 (no ignorado)
```

Los scripts que usan `savia-ignore.sh`: `confidentiality-scan.sh`, `session-action-log.sh`, `kg-export.sh`.

### Tests

- `test-savia-ignore.bats`: 8 tests
  - path en .saviaignore retorna exit 0
  - path no en .saviaignore retorna exit 1
  - patrón glob (*.tsv) funciona correctamente
  - directorio en .saviaignore: todos sus paths retornan exit 0
  - sin .saviaignore: todos los paths retornan exit 1 (no crash)
  - .saviaignore vacío: todos los paths retornan exit 1
  - comentarios en .saviaignore son ignorados
  - negación de patrón (!) funciona

### Criterios de aceptación

- [ ] `.saviaignore` es leído por `confidentiality-scan.sh`
- [ ] `savia-ignore.sh` implementa sintaxis gitignore completa (via `git check-ignore`)
- [ ] Sin `.saviaignore`: comportamiento actual preservado (no regresión)
- [ ] Tests: 8/8, score SPEC-055 ≥ 80

---

## Orden de implementación recomendado

| Slice | Esfuerzo | Prioridad | Dep |
|---|---|---|---|
| S5 `.saviaignore` | ~1h | P2 | — |
| S4 tiered flush | ~1h | P2 | — |
| S1 hook augmentation | ~2h | P2 | — |
| S3 qualified names | ~2h | P2 | SE-162 ✓ |
| S2 KG snapshot | ~3h | P2 | SE-162 ✓ · S3 recomendado |

**Total estimado**: ~9h. Todos independientes excepto S2 que se beneficia de S3.

## Developer type

`agent-single` para S4 y S5 (patrones repetitivos, contrato claro).
`human` para S1 y S2 (tocan hooks existentes con invariantes delicadas).
`agent-single` para S3 (transformación de datos determinista).
