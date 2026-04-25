# Verified Memory Axiom — SE-072

> **"No Execution, No Memory."** Inspirado en GenericAgent (lsdefine/GenericAgent, 6.8k ⭐). Memoria persistente debe reflejar hechos verificados — no intenciones, suposiciones, plans no ejecutados.

## Por qué

Memoria ruidosa con claims sin verificar degrada la señal/ruido. Si una reflexión, draft o suposición queda como "hecho" en memoria, los agentes futuros la tratan como cita autorizada. Errores se compoundean. Decisions se basan en datos falsos.

GenericAgent estableció el axioma: **el contenido de memoria debe estar acompañado de procedencia ejecutable**. Ningún recall es válido sin source verificable.

## Reglas

### Para `scripts/memory-store.sh save` (vector memory cache)

- `--source <origin>` es **obligatorio**.
- Sources válidos:
  - `tool:<tool_name>` — output de una tool real (Bash, Read, Edit, Write, Grep, Glob, Bats)
  - `file:<path>:<line>` — referencia file+line citable
  - `verified:<sha>` — commit hash que prueba persistencia
  - `user:explicit` — user told agent to remember X
- Sources blacklisted (rechazo automático): `speculation`, `plan`, `intent`, `draft`, `hypothesis`.

### Para `Write` a `~/.claude/projects/-home-monica-claude/memory/*.md` (auto-memory)

Hook `memory-verified-gate.sh` (PreToolUse) acepta el write si el contenido contiene **al menos uno** de:

1. **File reference**: `path/to/file.sh` o `path/to/file.sh:42`
2. **Markdown link**: `[name](path/to/file.md)`
3. **Keyword line**: `Source: <where>` | `Ref: <where>` | `See: <where>` | `@ref ...`
4. **URL**: `https://...`
5. **Frontmatter**: `type: reference|feedback|user|project` (procedencia implícita en metadata estructurada)

Si ninguna match → write bloqueado con mensaje didáctico.

### Skipped por design

- `MEMORY.md` (índice — solo links, sin claims)
- `session-journal.md`, `session-hot.md`, `session-summary.md` (ephemeral, scratchpad)
- Files fuera de auto-memory directory

## Escape hatch

`SAVIA_VERIFIED_MEMORY_DISABLED=true` desactiva ambos gates. Solo para:
- Migration scripts (grandfathering)
- Test setup (legacy fixtures)
- Casos donde Monica explícitamente pida bypass

NO usar como atajo casual. Si caes en la tentación, lee `feedback_root_cause_always` antes de continuar.

## Ejemplos

### memory-store.sh save (correcto)

```bash
# Pattern observado al ejecutar un test
bash scripts/memory-store.sh save \
  --type pattern \
  --title "TDD gate detected when missing test" \
  --content "tdd-gate.sh blocks Edit on src/ if no test added" \
  --source tool:Bash

# Después de leer un fichero específico
bash scripts/memory-store.sh save \
  --type discovery \
  --title "memory-save.sh has SPEC-019 contradiction tracking" \
  --content "Old entries are removed before insert via topic_key" \
  --source file:scripts/memory-save.sh:78

# Por petición explícita del usuario
bash scripts/memory-store.sh save \
  --type feedback \
  --title "Monica prefers terse responses" \
  --content "no trailing summaries" \
  --source user:explicit
```

### memory-store.sh save (rechazado)

```bash
# Sin --source: BLOQUEADO
bash scripts/memory-store.sh save --type decision --title "Algo" --content "X"
# Error: --source required (SE-072 Verified Memory axiom).

# Con source blacklisted: BLOQUEADO
bash scripts/memory-store.sh save --type decision --title "Algo" --content "X" --source speculation
# Error: --source 'speculation' is blacklisted by SE-072.

# Con format inválido: BLOQUEADO
bash scripts/memory-store.sh save --type decision --title "X" --content "Y" --source random
# Error: --source 'random' does not match required format.
```

### Auto-memory write (correcto)

Frontmatter `type: feedback` da procedencia implícita:

```markdown
---
name: ...
description: ...
type: feedback
---

Pattern in scripts/memory-save.sh:24 — when --source missing, save fails.
```

O explícito Source:

```markdown
Note about behavior X.

Source: bash session 2026-04-25, observed during batch 57 implementation.
```

### Auto-memory write (rechazado)

```markdown
---
name: ...
description: ...
type: project
---

Random thoughts about something with no citation, no link, no URL.
```

(Frontmatter type: project SÍ es procedencia implícita — pasa. Ejemplo solo si lo cambias a un type sin implícito.)

## Riesgos documentados

| Riesgo | Mitigación |
|---|---|
| Fricción para devs/agentes nuevos | Mensaje de error con 5 opciones copy-paste |
| Bypass via Write directo a auto/MEMORY.md | Hook PreToolUse cubre ambos paths |
| Tests existentes rotos | Update tests para incluir `--source tool:Bats` |
| Edge case: contenido legítimo sin patrón | Escape hatch + 5 patterns aceptados |

## Referencias

- `docs/propuestas/SE-072-verified-memory-axiom.md` — spec original
- `scripts/memory-save.sh:24` — `cmd_save` con `--source` validation
- `.claude/hooks/memory-verified-gate.sh` — PreToolUse Write gate
- GenericAgent `autonomous_operation_sop.md` — axioma original
- `feedback_root_cause_always` — memory rule aligned

## Política de evolución

Slice 1 (MVP). Fases futuras: F2 validar `tool:X` whitelist · F3 validar `file:path` existe · F4 integrar con `confidence-calibrate.sh`.
