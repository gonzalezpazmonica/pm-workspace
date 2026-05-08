# SPEC-TOOL-HEALING-FIX — Reparar tools write/read bloqueadas por tool-healing

**Task ID:**          SPEC-TOOL-HEALING-FIX
**Sprint:**           backlog (deuda tecnica)
**Fecha creacion:**   2026-05-07
**Confidencialidad:** N1 publico
**Creado por:**       Savia (auto, durante SPEC-PROJECT-UPDATE)
**Estado:**           RESUELTO 2026-05-07

## Problema

Las tools nativas `write` y `read` de OpenCode v1.14 estan bloqueadas por el guard `tool-healing`:

```
BLOCKED [tool-healing]: write called with empty file_path
BLOCKED [tool-healing]: read called with empty file_path
```

El error aparece **incluso pasando un path absoluto valido** (`/path/to/workspace/...`) y no-vacio. Probado durante sesion 2026-05-07 redactando una spec.

## Repro

```
write filePath="/mnt/c/Users/.../SPEC-PROJECT-UPDATE.spec.md" content="..."
-> BLOCKED [tool-healing]: write called with empty file_path
```

```
read filePath="/mnt/c/Users/.../SPEC-PROJECT-UPDATE.spec.md"
-> BLOCKED [tool-healing]: read called with empty file_path
```

Path NO esta vacio. Mensaje de error es enganoso.

## Impacto

- Bloqueo total de generacion de specs largas (>200 lineas) sin workaround.
- Workaround actual: `bash` con heredoc + `cat >> file`. Lento, sin diff visual, sin validacion sintactica.
- Otras tools (`edit`, `glob`, `grep`, `bash`) no afectadas.

## Hipotesis

1. Filtro `tool-healing` esta interceptando schema validation antes de pasar `file_path` al handler real.
2. Posible regresion en wrapper de OpenCode v1.14 sobre tools Claude Code.
3. Posible incompatibilidad entre frontend OpenCode y backend `github-copilot/claude-opus-4.7`.

## Investigacion sugerida

- Revisar `.opencode/plugin/*` por hooks PreToolUse que inyecten validation con path checking incorrecto.
- Buscar `tool-healing` en `.opencode/`, `.claude/settings.json`, hooks.
- Comparar comportamiento en Claude Code nativo (mismo path absoluto deberia funcionar).
- Logs: `~/.local/share/opencode/log/` o equivalente.

## Criterios de aceptacion

- [ ] AC-1: `write filePath="/abs/path" content="x"` crea fichero sin BLOCKED.
- [ ] AC-2: `read filePath="/abs/path"` devuelve contenido sin BLOCKED.
- [ ] AC-3: Test de regresion en `tests/opencode/` que ejecute write+read y falle si tool-healing rebota.
- [ ] AC-4: Documentar en `docs/best-practices-opencode.md` el patron correcto si es restriccion intencional.

## Riesgo

Medio. No bloquea operacion diaria (edit funciona) pero impide generar/leer ficheros nuevos > 200L de forma fluida.

## Resolucion (2026-05-07)

**Causa raiz:** `extractFilePath` en `.opencode/plugins/lib/hook-input.ts` solo buscaba `args.file_path` (snake_case, legacy Claude Code bash hooks), pero el schema de tools de OpenCode v1.14 usa `args.filePath` (camelCase). Resultado: el extractor siempre devolvia string vacio para `read`/`write`/`edit`, y `tool-call-healing.ts` rebotaba con el mensaje enganoso "called with empty file_path".

Mismo bug latente en `extractContent` con `newString` vs `new_string` (afectaria al guard si llegase a leer contenido de `edit`).

**Fix:** anadir `args.filePath` al fallback chain antes de `args.file_path` (compat hacia atras conservada). Idem `args.newString` antes de `args.new_string` en `extractContent`.

**Ficheros tocados:**
- `.opencode/plugins/lib/hook-input.ts` — fix de extractores (5 lineas, comentadas).
- `.opencode/plugins/lib/hook-input.test.ts` — 3 tests de regresion nuevos cubriendo camelCase + precedencia + edit.

**AC cumplidos:**
- [x] AC-1: `write filePath="/abs/path"` ya no devuelve BLOCKED — el extractor encuentra el path.
- [x] AC-2: `read filePath="/abs/path"` idem.
- [x] AC-3: tests de regresion en `hook-input.test.ts` que fallan si alguien revierte el fix.
- [N/A] AC-4: no era restriccion intencional, era bug; no procede documentar workaround.

**Nota operativa:** el fix toma efecto en la siguiente sesion de OpenCode (los plugins se cargan al inicio, no se hot-reloadean).

