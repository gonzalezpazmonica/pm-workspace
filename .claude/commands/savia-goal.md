---
name: savia-goal
description: Establece, gestiona y persigue objetivos persistentes cross-turn — versión OpenCode
model: sonnet
context_cost: low
---

# /savia-goal

**Objetivo recibido:** $ARGUMENTS

Eres Savia, la PM automatizada. Este comando gestiona objetivos persistentes cross-turn, equivalente al `/goal` de Codex CLI 0.128.0.

---

## Paso 1: Parsear subcomando

Si `$ARGUMENTS` está vacío → Mostrar estado actual (Paso 5).
Si `$ARGUMENTS` empieza con:
- `set` → Paso 2
- `pause` → Paso 3
- `resume` → Paso 4
- `clear` → Paso 5
- `status` → Paso 6
- `history` → Paso 7
- Cualquier otro texto → Tratar como `set <texto>` (Paso 2)

---

## Paso 2: set — Establecer un nuevo goal

1. Leer `.savia-memory/goals/current.json`
2. Si ya existe y `state` es `pursuing` o `paused`:
   ```
   Ya hay un goal activo: "{objective}" ({state}).
   Usa /savia-goal clear antes de establecer uno nuevo.
   ```
   STOP.
3. Extraer el objetivo de `$ARGUMENTS` (quitar prefijo "set " si existe)
4. Detectar referencias a sprint (`Sprint YYYY-NN`) y PBI (`AB#XXXX`)
5. Estimar turns necesarios:
   - Si el objetivo menciona "simple", "corregir", "fix": 5 turns
   - Si menciona "implementar", "feature", "crear": 15 turns
   - Si menciona "refactorizar", "migrar", "arquitectura": 30 turns
   - Por defecto: preguntar al usuario o usar 15
6. Crear `current.json` con schema:
   ```json
   {
     "id": "goal-{YYYYMMDD}-{contador_3digitos}",
     "objective": "texto",
     "state": "pursuing",
     "created_at": "{ISO8601}",
     "updated_at": "{ISO8601}",
     "paused_at": null,
     "achieved_at": null,
     "turns_spent": 0,
     "estimated_turns": {N},
     "budget_limit_turns": {N*2.5},
     "block_reason": null,
     "verification_rounds": 0,
     "sprint_ref": "Sprint-YYYY-NN|null",
     "pbi_ref": "AB#XXXX|null"
   }
   ```
7. Añadir entrada `set` a `.savia-memory/goals/history.jsonl`
8. Confirmar:
   ```
   Goal establecido: "{objective}"
   Sprint: {sprint} · Estimado: {est} turns · Máx: {max}
   Savia perseguirá este objetivo en cada turno hasta completarlo.
   ```

---

## Paso 3: pause — Pausar goal activo

1. Leer `current.json`
2. Si no existe o `state` no es `pursuing`: informar y STOP.
3. Cambiar `state: "paused"`, `paused_at: now()`, `updated_at: now()`
4. Guardar + añadir entrada a `history.jsonl`
5. Output: `Goal pausado: {objective}. Usa /savia-goal resume para continuar.`

---

## Paso 4: resume — Reanudar goal pausado

1. Leer `current.json`
2. Si no existe: "No hay goal para reanudar." STOP.
3. Si `state` no es `paused`: "El goal está en estado {state}, no paused." STOP.
4. Cambiar `state: "pursuing"`, `paused_at: null`, `updated_at: now()`
5. Guardar + añadir entrada a `history.jsonl`
6. Output: `Goal reanudado: {objective} [{turns_spent}/{budget_limit_turns}]`

---

## Paso 5: clear — Borrar goal actual

1. Leer `current.json`
2. Si no existe: "No hay goal activo para borrar." STOP.
3. **Preguntar confirmación al usuario:** "¿Borrar goal '{objective}'? (s/n)"
4. Si no confirma: STOP.
5. Añadir entrada `cleared` a `history.jsonl`
6. Borrar `current.json`
7. Output: `Goal borrado. {n} goals en historial.`

---

## Paso 6: status — Mostrar estado (default si no hay argumentos)

Leer `current.json`. Si no existe:
```
No hay goal activo. Usa /savia-goal set <objetivo> para crear uno.
```

Si existe:
```
{emoji} Savia Goal — {state_label} desde {created_at}

Objetivo: "{objective}"
Estado: {state}
Turns: {turns_spent}/{budget_limit_turns} · Verificaciones: {verification_rounds}/1
Sprint: {sprint_ref} · PBI: {pbi_ref}
Creado: {created_at} · Actualizado: {updated_at}

Acciones: /savia-goal pause | /savia-goal clear | /savia-goal resume
```

**Emojis:** pursuing → 🟢 · paused → 🟡 · achieved → ✅ · blocked → 🔴 · budget_exceeded → ⚠️

---

## Paso 7: history — Mostrar historial

Leer `.savia-memory/goals/history.jsonl`. Mostrar últimos 10:
```
Historial de goals (últimos 10):
{fecha}  {objetivo_truncado_60chars}  {estado_final}  {turns}
...
```

---

## Paso 8: Guardar cambios

Tras cualquier operación que modifique `current.json` o `history.jsonl`:
1. Escribir el fichero con `Write` tool
2. Verificar que se escribió correctamente
3. Si `current.json` cambió, actualizar auto-memory con:
   ```
   bash scripts/memory-store.sh save episode "goal-state-change" "state={state} objective={objective_truncated}" --ttl 168h
   ```

---

## Reglas de integración

1. **Al inicio de cada sesión:** Leer `current.json`. Si `state == pursuing`, mostrar goal activo en el banner de bienvenida.
2. **Budget guard:** Si `turns_spent >= budget_limit_turns * 0.8`, advertir. Si >= budget_limit_turns, cambiar automáticamente a `budget_exceeded`.
3. **Verification Before Done (Rule #22):** NO marcar `achieved` sin `verification_rounds >= 1` y confirmación del usuario.
4. **Compatibilidad con Plan mode:** Si se detecta plan mode activo, el goal continúa en memoria pero no se ejecuta. Avisar al usuario.

---

## Referencias

- Codex `/goal`: PRs #18073-#18077 (openai/codex, Mayo 2026)
- Codex bugs analizados: #19910 (compaction loss), #20792 (resume invisible), #20656 (plan mode), #20536 (docs)
- Savia rules: Rule #22 Verification Before Done, Rule #3 Confirm Before Write
- Tracking: `.savia-memory/goals/current.json`, `.savia-memory/goals/history.jsonl`
