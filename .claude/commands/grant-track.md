---
name: grant-track
description: >
  Gestiona ciclo de vida de subvenciones: solicitudes, estados, reportes, plazos.
  Rastrea fondos, hitos y alertas de vencimiento. Genera reportes para financiadores.
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
---

# /grant-track {proyecto} {subcommand} {args}

## Subcomandos

- `submit {organismo} {cantidad} {deadline} {titulo}` — Crea solicitud de beca
- `status {grant-id} {estado}` — Actualiza estado (draft → submitted → review → approved/rejected)
- `report {grant-id} {tipo}` — Genera reporte (progress | final) para financiador
- `list [--filter]` — Lista todas las becas con estado actual
- `deadline [--days N]` — Muestra vencimientos próximos (defecto: 30 días)

## Prerequisitos

1. Verificar que `projects/{proyecto}/` existe
2. Crear `projects/{proyecto}/grants/` si no existe
3. Crear `grants.json` inicial si no existe (formato: [])
4. Obtener último número grant: `ls grants/GRANT-*.md | sort -t'-' -k2 -n | tail -1`

## Ejecución

1. 🏁 Banner: `══ /grant-track — {proyecto}/{subcommand} ══`
2. **submit**: Crear entrada con ID (GRANT-NNNN), organismo, monto, deadline, estado=draft
3. **status**: Buscar grant por ID, validar transición de estado, actualizar con fecha
4. **report**: Generar fichero Markdown con: resumen, hitos completados, budget status, siguiente fase
5. **list**: Tabla con ID, organismo, monto, deadline, estado, % completado
6. **deadline**: Filtrar por fecha próxima, alertar si <7 días
7. Escribir agent-note: `projects/{proyecto}/agent-notes/grant-{grant-id}-{accion}.md`
8. ✅ Banner fin con ID de grant o ruta de reporte

## Output

```
projects/{proyecto}/grants/GRANT-{NNN}-{titulo-slug}.md
projects/{proyecto}/grants/reports/{grant-id}-{tipo}-YYYYMMDD.md
```

## Reglas

- Estados permitidos: draft, submitted, under-review, approved, rejected, completed, closed
- Transiciones válidas: draft → submitted → under-review → {approved|rejected} → {completed|closed}
- Cada grant almacena: id, organismo, titulo, monto, moneda, deadline, estado, fechas, hitos, reportes
- deadline muestra: fecha, días_restantes, prioridad (rojo si <7, amarillo si <14)
- report incluye: resumen ejecución, gastos vs presupuesto, logros, siguiente fase
