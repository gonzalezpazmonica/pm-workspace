# SPEC-SE-029: Iterative Context Compression

> **Estado**: Draft
> **Prioridad**: P1 (Calidad diaria)
> **Dependencias**: context-health.md (existente)
> **Era**: 231
> **Inspiración**: Hermes Agent `context_compressor.py`

---

## Problema

El `/compact` actual de pm-workspace destruye información entre
compactaciones sucesivas. Cada compact genera un resumen nuevo desde
cero, perdiendo contexto acumulado de compacts anteriores. En sesiones
largas (3+ compacts), la calidad degrada notablemente.

Hermes Agent resuelve esto con compresión iterativa: cada resumen se
actualiza incrementalmente, preservando información de ciclos anteriores.

## Solución

Script `scripts/iterative-compress.sh` que implementa compresión en 3
fases: poda determinista (barata), resumen LLM iterativo (preserva
historia), y reinyección post-compact.

## Algoritmo

```
Fase 1 — Poda determinista (sin LLM, 0 tokens)
  - Eliminar tool results > 500 chars (mantener primeras 3 líneas)
  - Eliminar confirmaciones simples (ok, si, vale, hecho)
  - Eliminar banners UX y separadores decorativos
  - Eliminar output de git status/log/diff sin decisiones
  - Preservar integridad de pares tool_use/tool_result (SPEC-088)

Fase 2 — Resumen iterativo (LLM)
  Si es primer compact:
    Generar resumen estructurado desde contexto completo
  Si es N-ésimo compact:
    Leer resumen anterior (session-hot.md)
    Actualizar con información nueva (no reconstruir)
    Resultado = resumen_previo + delta_nueva_info

Fase 3 — Reinyección
  Post-compact: inyectar resumen actualizado como contexto inicial
  Formato:
    [Session context — updated after N compactions]
    - Decisions: [lista]
    - Current task: [descripción]
    - Files modified: [lista]
    - Open questions: [lista]
    - Corrections applied: [lista]
```

## Formato del resumen iterativo

```markdown
## Session Summary (compact #N, YYYY-MM-DD HH:MM)

### Resolved
- Decision A was taken because X
- Bug in file.cs was caused by Y, fixed with Z

### In Progress
- Implementing feature W, slice 3/5 done
- Files modified: [list]

### Pending Questions
- Need to decide between approach A and B for module M

### Corrections Applied
- User said "don't use X, use Y instead"
- Changed approach from Z to W after test failure

### Key Context
- Project uses framework F with convention C
- Team member T is responsible for module M
```

## Implementación

### Script: `scripts/iterative-compress.sh`

```
Subcomandos:
  prune    — Fase 1 (poda determinista)
  summarize — Fase 2 (resumen iterativo)
  inject   — Fase 3 (reinyectar resumen)
  status   — Mostrar estado del resumen actual
```

### Integración con hooks

Hook `PreCompact`: ejecutar Fase 1 + Fase 2 antes del compact nativo.
Hook `PostCompact`: ejecutar Fase 3 (reinyección).

Ambos hooks ya existen (`pre-compact-backup.sh`, `post-compaction.sh`).
Extenderlos con llamadas a `iterative-compress.sh`.

### Almacenamiento

```
~/.claude/projects/{workspace-hash}/memory/session-hot.md
```

- TTL: 24h (se borra al inicio de nueva sesión)
- Max: 2000 tokens (para no inflar el contexto post-compact)
- Formato: markdown estructurado (secciones fijas)

## Métricas de mejora

| Métrica | Compact actual | Iterativo (objetivo) |
|---|---|---|
| Info preservada tras 1 compact | ~70% | ~90% |
| Info preservada tras 3 compacts | ~30% | ~75% |
| Coherencia post-compact | Degrada | Estable |
| Tokens de resumen | Variable | Max 2000 |

## Tests BATS (mínimo 10)

1. Script existe y es ejecutable
2. Prune elimina tool results largos
3. Prune preserva pares tool_use/tool_result
4. Prune no elimina decisiones del usuario
5. Summarize genera resumen con secciones obligatorias
6. Summarize actualiza resumen existente (no reemplaza)
7. Session-hot.md se crea en path correcto
8. Session-hot.md no excede 2000 tokens
9. Status muestra información del resumen actual
10. Fichero vacío como input no causa crash
