---
name: hub-audit
description: Auditar dependencias entre reglas de dominio, comandos y agentes — recalcular el índice de hubs
developer_type: all
agent: none
context_cost: medium
---

# /hub-audit

> 🦉 Savia audita su propia topología para detectar hubs y reglas huérfanas.

---

## Cargar perfil de usuario

Grupo: **Memory & Context** — cargar:

- `identity.md` — slug

Leer `@docs/rules/domain/semantic-hub-index.md` como referencia.

---

## Flujo

### Paso 1 — Escanear referencias

Para cada fichero en `docs/rules/domain/*.md`:

1. Buscar cuántos ficheros en `.claude/commands/` lo referencian (por `@` o nombre)
2. Buscar cuántos ficheros en `.claude/agents/` lo referencian
3. Buscar cuántos skills en `.claude/skills/` lo referencian

### Paso 2 — Clasificar

| Refs | Categoría |
|---|---|
| ≥5 | Hub — requiere minimización y estabilidad |
| 3-4 | Near-hub — monitorizar crecimiento |
| 2 | Paired — relación específica |
| 1 | Isolated — uso puntual |
| 0 | Dormant — candidata a auditoría |

### Paso 3 — Comparar con índice anterior

Si existe `semantic-hub-index.md`:

1. Detectar nuevos hubs (promociones)
2. Detectar hubs degradados (menos refs que antes)
3. Detectar nuevas reglas dormant
4. Calcular delta de métricas

### Paso 4 — Mostrar informe

```
🦉 Hub Audit — {fecha}

📊 Red de reglas:
  Total: {N} reglas · {hubs} hubs · {near} near-hubs · {dormant} dormant

🔄 Cambios desde última auditoría:
  + {regla} promovida a hub
  - {regla} degradada de hub
  ⚠️ {regla} nueva sin referencias

💡 Recomendaciones:
  {lista de acciones sugeridas}
```

### Paso 5 — Actualizar índice (con confirmación)

Si el usuario acepta, actualizar `semantic-hub-index.md` con los nuevos datos.

---

## Subcomandos

- `/hub-audit` — auditoría completa con comparación
- `/hub-audit quick` — solo conteo, sin comparación
- `/hub-audit update` — auditoría + actualizar índice

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: hub_audit
total_rules: 41
hubs: 1
near_hubs: 2
paired: 3
isolated: 10
dormant: 25
changes:
  promoted: []
  degraded: []
  new_dormant: []
```

---

## Restricciones

- **NUNCA** modificar reglas de dominio automáticamente
- **NUNCA** eliminar reglas dormant sin confirmación
- Solo actualizar `semantic-hub-index.md` con confirmación
- Ejecutar máximo 1 vez por release
