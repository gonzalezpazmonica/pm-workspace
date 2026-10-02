---
layer: peripheral
name: savia-memory
description: "Usar cuando se lee, escribe, busca o consolida la memoria persistente entre sesiones de Savia."
license: MIT
compatibility: opencode
metadata:
  audience: pm
  savia.maturity: stable
  workflow: memory-management
  # --- metadata.savia.* (SE-333) ---
  savia.consumes: session_data
  savia.produces: memory_entry
  savia.trigger_keywords: "recuerda, memory, guarda, memoriza, olvidas, recall"
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
# Guardar una entrada (tipo, título y contenido obligatorios; --source con formato válido)
bash scripts/memory-store.sh save --type decision --title "<título>" --content "<contenido>" \
  --source user:explicit          # o tool:<nombre> · file:<ruta>:<línea> · verified:<sha>

# Buscar en memoria (search o recall)
bash scripts/memory-store.sh search "<query>"
bash scripts/memory-store.sh recall "<query>"

# Ver estadísticas de memoria
bash scripts/memory-store.sh stats

# Reconstruir el índice auto/MEMORY.md desde el JSONL
bash scripts/memory-index-rebuild.sh

# Validar una entrada antes de guardarla (no escribe)
bash scripts/memory-write-gate.sh --content "<contenido>" --type decision \
  --topic-key "<tema>" --confidence 0.8 --concepts '["<concepto>"]'

# Sincronizar markdown de auto-memory al índice (escritura explícita)
bash scripts/memory-sync-index.sh "<directorio-auto-memory>"

# Proponer resolución de conflictos (informe, no modifica el store)
python3 scripts/memory-conflict-resolve.py --store output/.memory-store.jsonl \
  --output output/memory-conflicts-proposed.json

# Consultar estado del backup cifrado (no crea ni restaura backups)
bash scripts/memory-backup-pm.sh status
```

`backup`, `restore`, `--auto-resolve` y la sincronización del índice son
operaciones explícitas. No ejecutarlas automáticamente ni añadirlas a hooks o CI.
`restore` requiere además confirmación humana interactiva.

## Lectura de contexto al inicio

1. Leer `~/.savia-memory/auto/MEMORY.md` — índice de memoria auto
2. Si hay perfil activo en `.claude/profiles/active-user.md`, leer preferencias y contexto
3. Cargar decisiones previas relevantes al proyecto actual

## Protocolo Lazy

- NO cargar toda la memoria al inicio. Solo el índice (`auto/MEMORY.md`).
- Cargar entradas específicas bajo demanda según el contexto de la tarea.
- Usar `search` (o `recall`) para búsqueda semántica cuando necesites contexto relacionado.

## Escritura de memoria

`save` exige `--type` y `--title`. La forma posicional `save "<tipo>" "<contenido>"` se rechaza.
Antes de guardar algo dudoso, pásalo por `memory-write-gate.sh`: rechaza contenido corto,
especulativo o de baja confianza. Un contenido idéntico a otro ya guardado se omite como
duplicado. Cada `save` actualiza el índice `~/.savia-memory/auto/MEMORY.md` (o
`SAVIA_MEMORY_INDEX_FILE`); dentro de BATS nunca se toca el índice real del usuario.

Tipos habituales: decision, pattern, bug, discovery, convention, architecture, config,
feedback, reference.

## Anti-patterns

**❌ Guardar sin tipo**: usar `--type custom` para todo en lugar del tipo semántico correcto (`decision`, `discovery`, `bug`, etc.) → memoria no recuperable por topic, búsquedas devuelven ruido.
**✓ Correcto**: seleccionar el tipo que mejor describe la naturaleza del dato antes de guardar.

**❌ Guardar sin source**: omitir `--source` → trazabilidad rota, entries huérfanas sin origen verificable. `--source session` o `skill:<name>` no son formatos válidos y se rechazan.
**✓ Correcto**: `--source tool:<nombre>`, `file:<ruta>:<línea>`, `verified:<sha>` o `user:explicit`.
**❌ Bulk-dump**: guardar todo indiscriminadamente al final de la sesión → memoria saturada con ruido, las entradas valiosas quedan enterradas.
**✓ Correcto**: guardar sólo los datos que tienen valor de recuperación real (decisiones, patrones, bugs con causa-raíz).

**❌ No-recall**: guardar sin consultar nunca la memoria previa → la memoria crece pero no se usa, el agente repite los mismos errores sesión tras sesión.
**✓ Correcto**: al inicio de cada sesión relevante, hacer recall del contexto anterior antes de proponer soluciones.

**❌ Stale-reads**: usar entradas antiguas de memoria sin verificar frescura → decisiones basadas en contexto obsoleto, especialmente peligroso para rutas de ficheros y versiones.
**✓ Correcto**: para entradas con fecha anterior a 30 días, verificar que siguen siendo válidas antes de actuar sobre ellas.
