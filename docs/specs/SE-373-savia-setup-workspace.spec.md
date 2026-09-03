# SE-373 — Savia Setup · módulo `workspace`: composición de repos multi-repo para agentes

**Status:** APPROVED (2026-09-03, aprobada por la operadora — implementar)
**Fecha:** 2026-09-03
**Área:** Setup / Bootstrap / Multi-repo
**Fuente de inspiración:** MarsBased "Why multi-repo workspaces are a must for Claude Code" (2026-08-25) + análisis Savia 2026-09-03 (digestido en `vaults/SaviaDomains/tecnologia/SFT/multirepo-workspaces-agentes-20260903.md`)
**Criterio humano aplicable:** CRIT-001 (composición local; ningún contenido de repo se sube; remoto solo infra propia)

---

## 1. Motivación

Savia opera hoy sobre un repo único con subproyectos (`projects/*`). Pero su uso consultoría/vertical analiza **muchos repos externos hermanos** (30+ ya analizados). Para ese escenario multi-repo, el patrón correcto (MarsBased + análisis Savia) es:

1. Apuntar la sesión del agente a una **carpeta-padre (workspace)** que contiene los repos hermanos.
2. Tener en esa raíz una **composición**: un `AGENTS.md`/`CLAUDE.md` que **referencia** el CLAUDE.md/README de cada repo y un **mapa de relaciones** (qué repo sirve/a quién), **sin cargar el contenido** de todos (coste de contexto + prompt cache SE-371).

Savia tiene los ingredientes sueltos (lazy-loading en CLAUDE.md, codebase-map, agent-invocation-graph, cúpulas N1) pero **no un generador** que, dado un directorio de repos hermanos, produzca esa composición y registre el workspace en Savia. SE-372 (`savia setup`) no lo cubre.

## 2. Alcance

**Dentro:**
- Submódulo `savia-setup.sh workspace <dir>` (o `scripts/savia-workspace.sh` invocado desde setup).
- Detección de repos hermanos en `<dir>` (subdirectorios con `.git`).
- Generación de composición en `<dir>`:
  - `AGENTS.md` (raíz del workspace) con: inventario de repos (nombre, path, git remote, stack si detectable) + instrucción de **lazy load** por repo + mapa de relaciones.
  - `CLAUDE.local.md` (no commiteado) con preferencias del operador si procede.
- **Mapa de relaciones** (qué backend sirve a qué frontend / dependencias entre repos): heurístico por nombres + opción de override manual interactivo.
- Registro del workspace en el estado de Savia (`~/.savia/savia-setup.json` → `workspaces[]`) y opcionalmente en `mcp`/codebase-memory como scope.
- Opción `--dry-run` (solo muestra) y `--answers` (headless).
- Validación: la composición referencia repos existentes; sin duplicados.

**Fuera:**
- No clona ni toca el contenido de los repos (solo lectura + generación de la raíz del workspace).
- No sube nada: composición 100% local (CRIT-001).
- No es un gestor de monorepos ni cambia el flujo interno de pm-workspace (repo único).

## 3. Principios de diseño

1. **Composición = referencias, no contenido**: la raíz lista y describe; los agentes cargan cada repo bajo demanda (patrón CLAUDE.md lazy que ya usa Savia).
2. **Local y de solo lectura sobre los hijos**: solo se escribe en la raíz del workspace (AGENTS.md) y en el estado de Savia.
3. **Relaciones primero por heurística, refinables a mano**: nombres (`*-api`→`*-web`), manifiestos, y override interactivo.
4. **CRIT-001**: sin egress; los remotes solo se leen (para el inventario) y nunca se sube contenido; N3+ de los repos no entra en la composición (solo metadatos públicos del repo).
5. **Idempotente y re-ejecutable**: regenerar la composición no rompe overrides (sección `relaciones.manual` preservada).

## 4. Diseño técnico

### 4.1 Interfaz
```
savia-setup.sh workspace <dir> [--dry-run] [--answers FILE]
  → escribe <dir>/AGENTS.md (+ <dir>/CLAUDE.local.md si procede)
  → registra en ~/.savia/savia-setup.json: workspaces[<dir>] = {repos, relaciones}
```

### 4.2 Composición generada (AGENTS.md raíz)
```markdown
# Workspace — <nombre> (multi-repo)
Instrucción: los repos hermanos se cargan BAJO DEMANDA (lazy). No leas todos.

## Repos (inventario)
- `product-a/api`   (git@…, TypeScript) → sirve a: product-a/web, product-b/web
- `product-a/web`   (git@…, React)

## Mapa de relaciones
| repo | depende de | es servido por |
|---|---|---|
| product-a/web | product-a/api | — |
| product-b/web | product-a/api | — |

## Reglas por repo
Al trabajar en un repo, carga `<repo>/CLAUDE.md` si existe; si no, `README.md`.
```

### 4.3 Registro en estado Savia
`workspaces[]`: path, repos[{name, path, remote, stack}], relaciones, updated_at. Consumible por `--check` y por futuras integraciones (codebase-memory scope, cúpulas N1).

## 5. Criterios de aceptación
- **AC-0** `workspace <dir>` con 2 repos git hermanos (sandbox) genera `AGENTS.md` con ambos repos y mapa de relaciones (test).
- **AC-1** La composición usa lazy-load (contiene instrucción de no leer todos) (test).
- **AC-2** Re-ejecución idempotente: no duplica entradas de repos ni pierde overrides manuales (test: añadir relación manual, re-generar, comprobar que persiste).
- **AC-3** `--dry-run` no escribe nada (test).
- **AC-4** `--answers` con relaciones manuales produce el mapa esperado (test).
- **AC-5** Directorio sin repos → error claro, exit 2 (test).
- **AC-6** Registro en `savia-setup.json.workspaces` y `--check` lo muestra (test).
- **AC-7** No regresión SE-372: suite `test-savia-setup.bats` sigue verde (test).

## 6. OpenCode Implementation Plan
### Bindings touched
- `scripts/savia-setup.sh` (submódulo workspace) o `scripts/savia-workspace.sh` + dispatch
- `tests/bats/test-savia-workspace.bats` (nuevo) · spec nueva · CHANGELOG
### Verification protocol
```bash
bats tests/bats/test-savia-workspace.bats && bats tests/bats/test-savia-setup.bats
bash scripts/savia-setup.sh workspace /tmp/w --dry-run
```
### Portability classification
- Bash + python3; local; portable; CRIT-001.

## 7. Preguntas abiertas
- ¿Generar también una cúpula N1 por workspace o solo composición? Decisión propuesta: solo composición en v1; cúpula si el operador la pide (evita sobre-ingeniería).
- ¿Integrar el mapa de relaciones con el grafo de conocimiento existente? Fuera de alcance v1.

## 8. Referencias
- Artículo MarsBased 2026-08-25 · digest `vaults/SaviaDomains/tecnologia/SFT/multirepo-workspaces-agentes-20260903.md`
- SE-372 (savia setup) · SE-371 (cache/prefijo — motivo del lazy-load) · CLAUDE.md lazy pattern · CRIT-001
