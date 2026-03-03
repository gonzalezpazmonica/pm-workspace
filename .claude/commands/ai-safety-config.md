---
name: ai-safety-config
description: Configurar 4 niveles de supervisión humana (inform/recommend/decide/execute) por tipo de acción
developer_type: all
agent: none
context_cost: low
---

# /ai-safety-config

> 🦉 Configurar niveles de supervisión: qué hace Savia sola vs qué requiere tu aprobación.

Basado en **AI Safety Report 2025 framework** con 4 niveles de supervisión.

---

## Niveles de Supervisión

- **Nivel 1 (Inform)** — Savia ejecuta y te notifica
- **Nivel 2 (Recommend)** — Savia propone, espera confirmación
- **Nivel 3 (Decide)** — Savia presenta opciones, tú eliges
- **Nivel 4 (Execute)** — Control total, requiere comando explícito

---

## Categorías Configurables

| Categoría | Ejemplos | Defecto |
|---|---|---|
| Read | `/sprint-status`, `/team-workload` | Inform |
| Report | `/ceo-report`, `/qa-dashboard` | Recommend |
| Create | Crear PBI, Bug, Task | Decide |
| Update | Cambiar prioridad, asignar | Recommend |
| Delete | Archivar, eliminar | Execute |
| External APIs | Notificaciones, webhooks | Recommend |
| File Operations | Crear/modificar archivos | Recommend |
| Git Operations | Commits, ramas | Execute |
| Infrastructure | Recursos cloud | Decide |
| Security | Permisos, secrets | Execute |

---

## Flujo

1. **Paso 1** — Leer `company/policies.md` (crear si no existe)
2. **Paso 2** — Presentar tabla interactiva con niveles actuales
3. **Paso 3** — Permitir personalización por categoría
4. **Paso 4** — Definir excepciones (acciones específicas con nivel override)
5. **Paso 5** — Guardar en `company/policies.md` con timestamp

---

## Restricciones

- **NUNCA** Inform para operaciones que afecten código
- **NUNCA** Recommend/Inform para operaciones de seguridad
- Delete y Git Operations **mínimo Execute**
- Validar coherencia: Create no puede ser más permisivo que Update

---

## Integración

Los límites configurados aquí informan:
- `/ai-boundary` — matriz de límites por rol
- `/ai-confidence` — qué requiere validación
- `/ai-incident` — monitorizar cumplimiento

Ver `@.claude/rules/domain/pm-config.md` para configuración completa.
