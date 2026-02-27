# Regla: Context Health — Gestión proactiva del contexto
# ── Prevenir saturación que inutiliza los comandos ───────────────────────────

## Principio

> El contexto es un recurso finito. Si se agota, pm-workspace deja de funcionar.
> Cada decisión de diseño debe optimizar el uso de contexto.

## 1. Patrón output-first (OBLIGATORIO en todos los comandos)

Los comandos NUNCA deben volcar información extensa en la conversación.

**Regla:** Si un resultado supera 30 líneas → guardar en fichero, mostrar resumen.

```
❌ MAL: Volcar 200 líneas de audit en la conversación
✅ BIEN: Guardar en output/audits/..., mostrar 10 líneas de resumen + ruta
```

Formato obligatorio para resultados extensos:
```
📊 Resumen (5-10 líneas máximo en conversación)
   Score global: 6.2/10 | 🔴 3 críticos | 🟡 5 mejorables | 🟢 4 correctos
   Top crítico: SQL injection en AuthController (3 sprints sin resolver)

📄 Detalle completo: output/audits/YYYYMMDD-audit-proyecto.md
💡 Siguiente paso: /project-release-plan --project proyecto
```

## 2. Uso de subagentes para tareas pesadas

Cuando un comando necesita análisis profundo (leer muchos ficheros, comparar
datos, generar informes largos), DEBE usar `Task` (subagente).

El subagente trabaja en contexto aislado y devuelve solo el resumen.
Esto evita que el análisis intermedio contamine el contexto principal.

**Comandos que DEBEN usar subagente:**
- `/project-audit` → subagente analiza repo, devuelve scores + hallazgos
- `/evaluate-repo` → subagente clona y analiza, devuelve puntuaciones
- `/legacy-assess` → subagente evalúa 6 dimensiones, devuelve scoring
- `/spec-generate` → subagente genera spec, guarda en fichero
- Cualquier comando que lea más de 5 ficheros internamente

## 3. Compactación proactiva

### Cuándo sugerir `/compact`
- Después de 10+ turnos de conversación
- Después de ejecutar 3+ comandos en la misma sesión
- Antes de ejecutar un comando pesado (audit, spec, evaluate)
- Si el PM cambia de tema o proyecto

### Mensaje de sugerencia
```
💡 Llevamos N turnos. Para mantener la precisión de los comandos,
   te recomiendo ejecutar /compact antes de continuar.
   (Preservará las decisiones y resultados de esta sesión)
```

### Instrucciones de compactación para CLAUDE.md
Al compactar, SIEMPRE preservar:
- Lista de ficheros modificados en la sesión
- Resultados de audits/evaluaciones (scores, hallazgos críticos)
- Decisiones tomadas por el PM
- Estado del sprint/proyecto activo
- Errores encontrados y cómo se resolvieron

## 4. Sesiones enfocadas

### Regla de una tarea por sesión
Cada sesión debería tener UN objetivo claro:
- "Auditar pm-workspace" → audit + actions
- "Planificar Sprint 5" → planning + asignación
- "Implementar feature X" → spec + implement + test

Si el PM cambia de objetivo, sugerir `/clear` + nuevo `/context-load`.

### Antipatrones a evitar
- ❌ Mezclar auditoría + implementación + reporting en una sesión
- ❌ Ejecutar 10+ comandos sin compactar
- ❌ Pedir informes detallados en la conversación en vez de fichero

## 5. Memoria persistente entre sesiones

### Ficheros de estado del proyecto
Cada proyecto mantiene estado en disco (no en contexto):
- `projects/{p}/debt-register.md` — deuda técnica
- `projects/{p}/risk-register.md` — riesgos
- `projects/{p}/retro-actions.md` — acciones de retro
- `output/audits/` — histórico de audits
- `output/dora/` — histórico de métricas DORA

Los comandos LEEN estos ficheros cuando los necesitan.
No necesitan que la información esté en el contexto de conversación.

### `/context-load` como punto de partida
Al iniciar sesión, `/context-load` lee el estado de disco y muestra
un resumen conciso. No carga todo — solo lo justo para orientar al PM.

## 6. Límites de carga bajo demanda

Cuando un comando referencia un fichero con `@`, Claude lo carga en contexto.
Para evitar cargas excesivas:

- Máximo 3 ficheros `@` por comando (los imprescindibles)
- Skills: cargar solo el SKILL.md, no las references (cargar references
  solo si el paso actual las necesita específicamente)
- Si un comando necesita datos de otro comando anterior, leer del fichero
  de output, no repetir la ejecución
