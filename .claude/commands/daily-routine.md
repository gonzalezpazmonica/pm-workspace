---
name: daily-routine
description: Rutina diaria adaptativa según el rol del usuario — Savia sugiere los comandos más relevantes para tu jornada
developer_type: all
agent: none
context_cost: low
---

# /daily-routine

> 🦉 Savia conoce tu rol y te propone la rutina del día.

---

## Cargar perfil de usuario

Grupo: **Sprint & Daily** — cargar `identity.md` + `workflow.md` del perfil activo.
Ver `.claude/profiles/context-map.md`.
Leer `@.claude/rules/domain/role-workflows.md` para las rutinas por rol.

## Flujo

### Paso 1 — Identificar rol y modo

1. Leer `identity.md` → `role`
2. Leer `workflow.md` → `primary_mode`, `daily_time`
3. Determinar hora actual y día de la semana
4. Seleccionar rutina diaria del rol según `role-workflows.md`

### Paso 2 — Componer rutina del día

1. Mostrar banner: `🦉 Buenos días, {nombre}. Tu rutina de {rol}:`
2. Listar los comandos de la rutina diaria del rol, en orden
3. Si es día de ritual semanal → añadir sección "Ritual semanal"
4. Si es final de mes y el rol tiene ritual mensual → añadirlo
5. Si hay alertas pendientes del session-init → mostrarlas primero

### Paso 3 — Ejecutar bajo demanda

1. Preguntar: "¿Empezamos con la rutina completa, o prefieres algo concreto?"
2. Si "rutina completa" → ejecutar comandos en secuencia, mostrando resumen entre cada uno
3. Si "algo concreto" → dejar elegir qué comando ejecutar
4. Tras cada comando, mostrar: "Siguiente: {comando} ¿Continuar?"
5. El usuario puede saltar, parar, o cambiar de orden en cualquier momento

### Paso 4 — Resumen

1. Al terminar (o al interrumpir), mostrar resumen:
   - Comandos ejecutados
   - Alertas detectadas
   - Acciones pendientes sugeridas
2. Banner fin: `✅ Rutina completada` o `📋 Rutina parcial — pendiente: {comandos}`

## Rutinas por rol (resumen)

- **PM**: sprint-status → team-workload → board-flow → (alertas)
- **Tech Lead**: pr-pending → spec-status → perf-audit (si aplica)
- **QA**: pr-pending (foco tests) → cobertura → security-alerts
- **Product Owner**: kpi-dashboard → backlog review → validación
- **Developer**: pr-pending → spec-status → items asignados
- **CEO/CTO**: kpi-dashboard → team-workload → alertas críticas

Detalle completo: `@.claude/rules/domain/role-workflows.md`

## Voz de Savia

- Humano: "Buenos días, Mónica. Hoy es miércoles — toca refinamiento. Tu sprint lleva 68% completado y hay 2 items bloqueados. ¿Empezamos por los bloqueos? 🦉"
- Agente (YAML):
  ```yaml
  status: ok
  action: daily_routine
  role: PM
  routine: [sprint-status, team-workload, board-flow]
  alerts: 2
  ```

## Restricciones

- **NUNCA** ejecutar comandos sin confirmación del usuario
- **SIEMPRE** permitir saltar, reordenar o parar la rutina
- **SIEMPRE** respetar el primary_mode del perfil
- Si no hay perfil activo → sugerir `/profile-setup` en lugar de rutina
