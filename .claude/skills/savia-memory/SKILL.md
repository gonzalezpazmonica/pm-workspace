---
name: savia-memory
description: Gestión de memoria canónica externa de Savia (.savia-memory). Lectura, escritura, búsqueda y consolidación de memoria entre sesiones.
license: MIT
compatibility: opencode
metadata:
  audience: pm
  workflow: memory-management
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
- Para buscar memoria previa: `scripts/memory-store.sh recall <query>`
- Para ver estadísticas: `scripts/memory-store.sh stats`
- Para consolidar memoria al final de sesión

## Comandos

```bash
# Guardar una entrada en memoria
bash ~/claude/scripts/memory-store.sh save "<tipo>" "<contenido>"

# Buscar en memoria
bash ~/claude/scripts/memory-store.sh recall "<query>"

# Ver estadísticas de memoria
bash ~/claude/scripts/memory-store.sh stats
```

## Lectura de contexto al inicio

1. Leer `~/.savia-memory/auto/MEMORY.md` — índice de memoria auto
2. Si hay perfil activo en `.claude/profiles/active-user.md`, leer preferencias y contexto
3. Cargar decisiones previas relevantes al proyecto actual

## Protocolo Lazy

- NO cargar toda la memoria al inicio. Solo el índice (`auto/MEMORY.md`).
- Cargar entradas específicas bajo demanda según el contexto de la tarea.
- Usar `recall` para búsqueda semántica cuando necesites contexto relacionado.

## Escritura de memoria

Usar `scripts/memory-store.sh save` con el formato:
```
<tipo>: <descripción>
<contenido>
```

Tipos: decision, pattern, context, feedback, lesson, reference
