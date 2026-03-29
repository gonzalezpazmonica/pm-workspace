# SPEC-042: Live Progress Feedback — Visibilidad en tiempo real del trabajo de Savia

> Status: **DRAFT** · Fecha: 2026-03-29
> Origen: PM — "veinte minutos sin saber qué estás haciendo, tengo que interrumpirte"
> Impacto: La PM puede ver en todo momento qué hace Savia, qué tiene encolado y cuánto queda

---

## Problema

Cuando Savia trabaja en tareas largas (revisiones, specs, refactors, revisiones
ortográficas...) la PM ve silencio durante 5-20 minutos. No sabe si:
- Savia sigue trabajando
- Se ha colgado
- En qué paso está
- Cuánto queda
- Qué tiene pendiente

Actualmente tiene que interrumpir el trabajo solo para preguntar "¿con qué estás?",
lo que rompe el contexto y cansa a ambas.

---

## Investigación: Mecanismos disponibles en Claude Code

| Mecanismo | Visible en UI | Tiempo real | Dinámico | Limitación |
|-----------|:---:|:---:|:---:|---|
| `statusMessage` en hooks | ✅ | ✅ | ❌ texto fijo | Solo al ejecutar el hook |
| TaskCreate/TaskUpdate | ✅ | ✅ | ✅ | Requiere Agent Teams activos |
| Log file + `tail -f` | ✅ (terminal) | ✅ | ✅ | Requiere segunda terminal |
| `/statusline` | ✅ | ✅ | ❌ | Config estática, no por tarea |
| Anuncios en conversación | ✅ | ✅ | ✅ | Depende de disciplina de Savia |

**Conclusión:** No hay un mecanismo nativo de live feed. La solución óptima combina
tres capas: comportamiento, hooks y un fichero de estado watchable.

---

## Solución: 3 capas complementarias

### Capa 1 — Protocolo de Anuncio (comportamiento, zero setup)

**Qué es:** Savia anuncia en la conversación el plan ANTES de ejecutarlo.

**Cuándo aplica:** Cualquier tarea con ≥3 pasos o duración estimada >2 min.

**Protocolo obligatorio:**

```
Al iniciar trabajo multi-paso:
  1. Mostrar plan explícito con pasos numerados
  2. Estimar duración ("~5 min")
  3. Indicar qué ficheros tocará

Al completar cada paso:
  → "✓ Paso 2/5 — [descripción breve]"

Al cambiar de tarea o bloqueo:
  → "⏸ Pausando [X] — [motivo]"
  → "▶ Reanudando [X]"

Al finalizar:
  → Resumen: qué se hizo, qué ficheros, siguiente acción
```

**Ejemplo:**

```
━━ Plan: Revisión ortográfica docs/guides_en/ (17 ficheros) ━━
Paso 1/4 — Leer README + ficheros de referencia
Paso 2/4 — Revisar guías ES (guide-*.md) → correcciones inline
Paso 3/4 — Revisar guías EN (guides_en/) → correcciones inline
Paso 4/4 — Commit + PR
Duración estimada: ~15 min
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Paso 1/4 — README y referencias cargadas (3 ficheros)
✓ Paso 2/4 — 12 guías ES revisadas, 47 correcciones
▶ Paso 3/4 — Revisando guide-sovereignty.md (1/5)...
```

---

### Capa 2 — Live Log File (watch en terminal)

**Qué es:** Savia escribe cada operación en `~/.savia/live.log`.
La PM puede tener una segunda terminal con `tail -f` siempre visible.

**Script:** `scripts/savia-watch.sh`

```bash
#!/usr/bin/env bash
# Muestra actividad de Savia en tiempo real
# Uso: bash scripts/savia-watch.sh [--compact]

LOG="$HOME/.savia/live.log"
mkdir -p "$HOME/.savia"

if [[ "$1" == "--compact" ]]; then
  tail -f "$LOG" | grep -E "^(▶|✓|⚠|❌|━)"
else
  tail -f "$LOG"
fi
```

**Hook:** `PreToolUse` con matcher `.*` escribe al log antes de cada tool use:

```bash
# .claude/hooks/live-progress-hook.sh
#!/usr/bin/env bash
TOOL_NAME="$CLAUDE_TOOL_NAME"          # Bash, Edit, Write, Read, Task...
TOOL_INPUT="$CLAUDE_TOOL_INPUT"        # JSON del input
LOG="$HOME/.savia/live.log"
QUEUE="$HOME/.savia/work-queue.json"
TS=$(date "+%H:%M:%S")

# Formatear mensaje según tipo de tool
case "$TOOL_NAME" in
  Bash)   echo "[$TS] ⚙  Ejecutando: $(echo $TOOL_INPUT | jq -r '.description // .command[:60]')" >> "$LOG" ;;
  Edit)   echo "[$TS] ✏  Editando:   $(echo $TOOL_INPUT | jq -r '.file_path' | sed 's|.*/||')" >> "$LOG" ;;
  Write)  echo "[$TS] 📝 Escribiendo: $(echo $TOOL_INPUT | jq -r '.file_path' | sed 's|.*/||')" >> "$LOG" ;;
  Read)   echo "[$TS] 👁  Leyendo:    $(echo $TOOL_INPUT | jq -r '.file_path' | sed 's|.*/||')" >> "$LOG" ;;
  Task)   echo "[$TS] 🤖 Agente:     $(echo $TOOL_INPUT | jq -r '.description[:60]')" >> "$LOG" ;;
  Glob)   echo "[$TS] 🔍 Buscando:   $(echo $TOOL_INPUT | jq -r '.pattern')" >> "$LOG" ;;
  Grep)   echo "[$TS] 🔎 Grep:       $(echo $TOOL_INPUT | jq -r '.pattern[:40]')" >> "$LOG" ;;
esac
exit 0
```

**Formato del log:**
```
[09:15:32] ⚙  Ejecutando: Check current branch
[09:15:33] 👁  Leyendo:    guide-sovereignty.md
[09:15:34] ✏  Editando:   guide-sovereignty.md
[09:15:34] 👁  Leyendo:    guide-startup.md
[09:15:35] ✏  Editando:   guide-startup.md
[09:15:36] 🔍 Buscando:   docs/guides_en/*.md
```

**Rotación:** El log se trunca al inicio de cada sesión (SessionStart hook).
Máximo 500 líneas (head circular o logrotate).

---

### Capa 3 — Work Queue File (estado persistente)

**Qué es:** Savia mantiene `~/.savia/work-queue.json` con la cola de trabajo actual.
La PM puede consultarlo con `/savia-status` o leerlo directamente.

**Formato:**
```json
{
  "session": "2026-03-29T09:15:00Z",
  "current_task": {
    "title": "Revisión ortográfica docs/guides_en/",
    "step": 3,
    "total_steps": 4,
    "current_file": "guide-sovereignty.md",
    "started_at": "09:12:00",
    "estimated_end": "09:27:00"
  },
  "completed": [
    "Paso 1/4 — README y referencias (09:12)",
    "Paso 2/4 — 12 guías ES revisadas (09:18)"
  ],
  "pending": [
    "Paso 3/4 — Revisar 5 guías EN",
    "Paso 4/4 — Commit + PR"
  ],
  "last_update": "09:21:34"
}
```

**Script de consulta:** `scripts/savia-status.sh`
```bash
#!/usr/bin/env bash
# /savia-status — qué está haciendo Savia ahora mismo
QUEUE="$HOME/.savia/work-queue.json"
[[ ! -f "$QUEUE" ]] && echo "Sin trabajo activo." && exit 0
python3 -c "
import json, datetime
d = json.load(open('$QUEUE'))
ct = d.get('current_task', {})
print(f'━━ Savia ahora ━━')
print(f'  {ct.get(\"title\",\"—\")}')
print(f'  Paso {ct.get(\"step\")}/{ct.get(\"total_steps\")} — {ct.get(\"current_file\",\"\")}')
print(f'  ETA: {ct.get(\"estimated_end\",\"?\")}')
print()
print('✓ Completado:')
for c in d.get('completed', []):
    print(f'  {c}')
print()
print('⏳ Pendiente:')
for p in d.get('pending', []):
    print(f'  {p}')
"
```

---

## Integración con Tasks

Cuando Savia inicia trabajo multi-paso, **crea Tasks** para cada paso:

```
TaskCreate — "Paso 1/4: README y referencias" → pending
TaskCreate — "Paso 2/4: Guías ES" → pending
TaskCreate — "Paso 3/4: Guías EN" → pending
TaskCreate — "Paso 4/4: Commit + PR" → pending
```

Al ejecutar cada paso:
```
TaskUpdate paso_actual → in_progress
[... trabajo ...]
TaskUpdate paso_actual → completed
TaskUpdate siguiente_paso → in_progress
```

Esto hace el queue visible en el panel de Tasks de Claude Code.

---

## Regla de comportamiento (Capa 1 — inmediata)

**Obligatorio para Savia en CUALQUIER tarea con ≥3 pasos:**

1. **Antes de empezar**: mostrar plan + duración estimada
2. **Cada paso completado**: `✓ Paso N/M — [descripción]`
3. **Al cambiar fichero en lote**: `  → [nombre-fichero]` (compacto)
4. **Al encontrar bloqueo**: notificar inmediatamente, no trabajar en silencio
5. **Al finalizar**: resumen con métricas (ficheros tocados, cambios, siguiente acción)

**Checkpoint automático cada 10 tool calls:**
```
[09:23] ⏱ Checkpoint — Revisando guide-healthcare.md (3/5)
        Completados: 8 ficheros / Pendientes: 9 ficheros
```

---

## Implementación por fases

### Fase 1 — Inmediata (hoy, solo comportamiento)
- [ ] Savia adopta el protocolo de anuncio (Capa 1)
- [ ] Usa TaskCreate/TaskUpdate para todo trabajo multi-paso
- No requiere código nuevo

### Fase 2 — Hook live log (~1h)
- [ ] Crear `scripts/savia-watch.sh`
- [ ] Crear `.claude/hooks/live-progress-hook.sh`
- [ ] Añadir hook en `settings.json` (PreToolUse, matcher `.*`, async)
- [ ] Añadir hook rotación log en SessionStart
- [ ] Test: verificar que el log se actualiza en tiempo real

### Fase 3 — Work queue JSON (~1h)
- [ ] Crear `scripts/savia-status.sh`
- [ ] Savia escribe en `~/.savia/work-queue.json` al inicio/fin de cada paso
- [ ] Añadir comando `/savia-status` en `.claude/commands/`
- [ ] Test: `watch -n1 bash scripts/savia-status.sh` durante trabajo largo

### Fase 4 — Integración completa
- [ ] `scripts/savia-watch.sh` muestra tanto log como queue
- [ ] Alias en `.bashrc`: `alias qué='bash ~/claude/scripts/savia-status.sh'`
- [ ] Documentar setup en SETUP.md

---

## Setup para la PM

Una vez implementado, abrir dos terminales:

```
Terminal 1 (trabajo): claude code
Terminal 2 (monitor): bash ~/claude/scripts/savia-watch.sh
```

O consultar en cualquier momento:
```
Terminal 1: bash ~/claude/scripts/savia-status.sh
# o simplemente: qué
```

---

## Métricas de éxito

- La PM no necesita interrumpir a Savia para saber en qué está
- El delay máximo entre una acción de Savia y su visibilidad en el log: <1s
- Tasa de interrupciones "¿con qué estás?": → 0

---

## Ficheros afectados

| Fichero | Acción |
|---------|--------|
| `scripts/savia-watch.sh` | Nuevo |
| `scripts/savia-status.sh` | Nuevo |
| `.claude/hooks/live-progress-hook.sh` | Nuevo |
| `.claude/settings.json` | Añadir hook PreToolUse async |
| `.claude/commands/savia-status.md` | Nuevo |
| `~/.savia/live.log` | Runtime (gitignored) |
| `~/.savia/work-queue.json` | Runtime (gitignored) |
