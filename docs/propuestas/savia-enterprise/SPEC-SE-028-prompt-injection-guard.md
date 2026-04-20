---
id: SPEC-SE-028
title: SPEC-SE-028: Prompt Injection Guard — Context File Scanning
status: PROPOSED
migrated_at: "2026-04-19"
migrated_from: body-prose
---

# SPEC-SE-028: Prompt Injection Guard — Context File Scanning

> **Estado**: Draft
> **Prioridad**: P0 (Seguridad)
> **Dependencias**: Ninguna
> **Era**: 231
> **Inspiración**: Hermes Agent `prompt_builder.py` injection detection

---

## Problema

pm-workspace carga ficheros de contexto dinámicamente: `CLAUDE.md` de
proyectos, `AGENTS.md`, reglas de dominio, specs, memoria. Cualquiera de
estos ficheros podría contener instrucciones adversariales inyectadas
(por un colaborador malintencionado, un fichero descargado, o un digest
de reunión manipulado) que sobrescriban el system prompt de Savia.

Hermes Agent detectó este vector y lo resuelve con un scanner pre-inyección.
pm-workspace no tiene esta defensa.

## Vectores de ataque

1. `CLAUDE.md` de un proyecto editado con "ignore previous instructions"
2. Spec con instrucciones ocultas en comentarios HTML
3. Digest de reunión con prompt injection en transcripción
4. Agent memory con instrucciones adversariales persistidas
5. Unicode homógrafos para camuflar instrucciones

## Solución

Hook `PreToolUse` (matcher: Read) que escanea ficheros de contexto
antes de que se inyecten en la conversación. Si detecta patrones de
inyección, bloquea la lectura y alerta al usuario.

## Patrones a detectar

### Categoría 1 — Override directo (BLOCK)
```
ignore previous instructions
ignore all prior instructions
disregard your instructions
forget everything above
override system prompt
you are now a different
new persona
act as if you have no rules
```

### Categoría 2 — Instrucciones ocultas (BLOCK)
```
<!-- .* --> (HTML comments with instructions)
<div style="display:none"> (hidden content)
\u200B \u200C \u200D (zero-width characters)
\uFEFF (BOM in middle of text)
```

### Categoría 3 — Social engineering (WARN)
```
do not tell the user
don't mention this to
keep this secret from
the user doesn't need to know
```

## Implementación

### Hook: `.claude/hooks/prompt-injection-guard.sh`

```
Trigger: PreToolUse (matcher: Read)
Tier: security (siempre activo)
Scope: ficheros en paths de contexto (.claude/, projects/, docs/)
Exit 2: BLOCK (inyección detectada)
Exit 0: ALLOW
```

Paths escaneados (ficheros que se inyectan como contexto):
- `projects/*/CLAUDE.md`
- `projects/*/reglas-negocio.md`
- `projects/*/specs/**`
- `projects/*/agent-memory/**`
- `docs/rules/**`
- `.claude/agents/**`
- `docs/**`

Paths excluidos (código fuente, no se inyecta como prompt):
- `*.sh`, `*.py`, `*.ts`, `*.cs` (código, no contexto)
- `tests/**`
- `output/**`

### Audit log

Cada detección se registra en `output/injection-audit.jsonl`:
```json
{
  "ts": "2026-04-12T21:00:00Z",
  "file": "projects/{proyecto}/CLAUDE.md",
  "category": "override",
  "pattern": "ignore previous instructions",
  "line": 42,
  "action": "BLOCKED",
  "context": "...surrounding text..."
}
```

## Tests BATS (mínimo 12)

1. Hook existe y es ejecutable
2. Fichero limpio pasa sin problemas
3. "ignore previous instructions" en md → BLOCK
4. "disregard your instructions" → BLOCK
5. HTML comment con instrucciones → BLOCK
6. Zero-width characters → BLOCK
7. "do not tell the user" → WARN (no block)
8. Fichero .sh con "ignore" en comentario → SKIP (no contexto)
9. Fichero en output/ → SKIP
10. Fichero con patron parcial inocuo → ALLOW
11. Audit log se genera correctamente
12. Fichero vacío → ALLOW

## Prohibido

```
NUNCA → Desactivar este hook en ningún perfil (es security tier)
NUNCA → Ignorar detecciones sin log de auditoría
NUNCA → Ejecutar ficheros bloqueados con override
```
