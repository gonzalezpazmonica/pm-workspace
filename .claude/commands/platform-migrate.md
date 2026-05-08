---
name: platform-migrate
description: Migración asistida entre plataformas — Azure DevOps ↔ Jira ↔ GitHub Projects ↔ Linear
developer_type: all
agent: task
context_cost: high
---

# /platform-migrate

> 🦉 Savia migra tus datos entre plataformas sin perder historia.

---

## Cargar perfil de usuario

Grupo: **Infrastructure** — cargar:

- `identity.md` — nombre, empresa
- `projects.md` — proyectos a migrar
- `preferences.md` — platform_preference

---

## Subcomandos

- `/platform-migrate plan {origen} {destino}` — plan de migración
- `/platform-migrate execute` — ejecutar migración planificada
- `/platform-migrate validate` — verificar integridad post-migración
- `/platform-migrate rollback` — revertir última migración

---

## Flujo

### Paso 1 — Análisis de compatibilidad

```
🔍 Migration Analysis — {origen} → {destino}

  Items a migrar:
  ├─ PBIs/Issues: {N}
  ├─ Sprints/Cycles: {N}
  ├─ Comentarios: {N}
  ├─ Attachments: {N}
  └─ Historia de estados: {N} transiciones

  Compatibilidad:
  ├─ ✅ Items y estados: mapeo directo
  ├─ ✅ Estimaciones: traducción automática
  ├─ 🟡 Custom fields: {N} requieren mapeo manual
  └─ ⚠️ Workflows: {N} estados sin equivalente
```

### Paso 2 — Plan de migración

```
📋 Migration Plan

  Fase 1 — Exportar datos de {origen} (read-only)
  Fase 2 — Transformar campos según mapeo
  Fase 3 — Importar en {destino} (dry-run primero)
  Fase 4 — Verificar integridad (conteos, links, historia)
  Fase 5 — Activar sync bidireccional (periodo transición)
  Fase 6 — Desactivar origen (cuando equipo confirme)

  Tiempo estimado: {N} minutos
  Riesgo: {bajo/medio/alto}
```

### Paso 3 — Ejecutar con dry-run

Siempre ejecutar primero en modo dry-run:
1. Simular todas las operaciones
2. Reportar qué se crearía/modificaría
3. Pedir confirmación explícita antes de ejecutar

### Paso 4 — Validación post-migración

```
✅ Migration Validation — {origen} → {destino}

  Conteos:
  ├─ Items: {N}/{N} migrados (100%)
  ├─ Sprints: {N}/{N} mapeados
  ├─ Comentarios: {N}/{N} preservados
  └─ Attachments: {N}/{N} transferidos

  Integridad:
  ├─ ✅ IDs mapeados correctamente
  ├─ ✅ Historia de estados preservada
  ├─ 🟡 {N} custom fields sin mapear (documentados)
  └─ ✅ Links internos actualizados
```

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: platform_migrate
source: "azure-devops"
target: "jira"
items_migrated: 234
sprints_mapped: 12
validation: "passed"
rollback_available: true
```

---

## Restricciones

- **NUNCA** ejecutar migración sin dry-run previo
- **NUNCA** eliminar datos del origen durante la migración
- **NUNCA** migrar sin backup previo del destino
- Siempre mantener periodo de transición con sync bidireccional
- Rollback disponible durante 30 días post-migración
