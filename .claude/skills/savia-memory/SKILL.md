---
name: savia-memory
description: "Usar cuando se lee, escribe, busca o consolida la memoria persistente entre sesiones de Savia."
license: MIT
compatibility: opencode
metadata:
  audience: pm
  workflow: memory-management
trigger:
  type: keyword
  keywords: [recuerda, memory, guarda, memoriza, olvidas, recall]
consumes:
  - session_data
produces:
  - memory_entry
---

# Skill: savia-memory

Gestión de la memoria canónica externa del pm-workspace (`.savia-memory/`).

## Estructura

```
~/.savia-memory/
├── auto/          memoria auto (user/feedback/project/reference)
├── sessions/      snapshots de sesión
├── projects/      memoria por proyecto PM
├── agents/        memoria de agentes (public/private/projects)
├── shield-maps/   mapas mask/unmask Shield
├── pm-radar/      state.json del radar PM
└── jsonl-archive/ archivos JSONL de memoria
```

## Cuándo usar esta skill

- Al inicio de cada sesión: leer `~/.savia-memory/auto/MEMORY.md`
- Para guardar decisiones o aprendizajes: usar `scripts/memory-store.sh`
- Para buscar memoria previa: `scripts/memory-store.sh search <query>`
- Para buscar (alias corto): `scripts/memory-store.sh recall <query>`
- Para ver estadísticas: `scripts/memory-store.sh stats`
- Para consolidar memoria al final de sesión

## Comandos

```bash
# Guardar una entrada en memoria
bash ~/claude/scripts/memory-store.sh save "<tipo>" "<contenido>"

# Buscar en memoria (search o recall)
bash ~/claude/scripts/memory-store.sh search "<query>"
bash ~/claude/scripts/memory-store.sh recall "<query>"

# Ver estadísticas de memoria
bash ~/claude/scripts/memory-store.sh stats

# Reconstruir índice desde JSONL
bash ~/claude/scripts/memory-index-rebuild.sh
```

## Lectura de contexto al inicio

1. Leer `~/.savia-memory/auto/MEMORY.md` — índice de memoria auto
2. Si hay perfil activo en `.claude/profiles/active-user.md`, leer preferencias y contexto
3. Cargar decisiones previas relevantes al proyecto actual

## Protocolo Lazy

- NO cargar toda la memoria al inicio. Solo el índice (`auto/MEMORY.md`).
- Cargar entradas específicas bajo demanda según el contexto de la tarea.
- Usar `search` (o `recall`) para búsqueda semántica cuando necesites contexto relacionado.

## Escritura de memoria

Usar `scripts/memory-store.sh save` con el formato:
```
<tipo>: <descripción>
<contenido>
```

Tipos: decision, pattern, context, feedback, lesson, reference

## Anti-patterns

**❌ Guardar sin tipo**: usar `--type custom` para todo en lugar del tipo semántico correcto (`decision`, `discovery`, `bug`, etc.) → memoria no recuperable por topic, búsquedas devuelven ruido.
**✓ Correcto**: seleccionar el tipo que mejor describe la naturaleza del dato antes de guardar.

**❌ Guardar sin source**: omitir `--source skill:<name>` o `--source session` → trazabilidad rota, entries huérfanas sin origen verificable.
**✓ Correcto**: siempre incluir `--source` con el skill, comando o sesión que originó la entrada.
