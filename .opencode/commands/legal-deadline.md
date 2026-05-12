---
name: legal-deadline
description: >
  Gestiona plazos legales de casos con alertas automáticas.
  Subcomandos: set (crear plazo), list (listar con filtros),
  alert (mostrar próximos), complete (marcar completado),
  extend (extender plazo con justificación).
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
---

# Gestor de Plazos Legales

Administra plazos procesales, contractuales y regulatorios con alertas inteligentes.

## Uso

```
legal-deadline set <caso> <descripción> <fecha> [tipo] [prioridad]
legal-deadline list [filtro]
legal-deadline alert [días]
legal-deadline complete <caso> <plazo> [evidencia]
legal-deadline extend <caso> <plazo> <justificación>
```

## Subcomandos

### set
Crea nuevo plazo legal.
- `caso`: referencia del caso (ej: C-2024-001)
- `descripción`: descripción del plazo
- `fecha`: fecha vencimiento (YYYY-MM-DD)
- `tipo`: procesal|contractual|regulatorio (default: procesal)
- `prioridad`: alta|normal|baja (default: normal)

Almacena en: `projects/{proyecto}/legal/deadlines.json`

### list
Muestra plazos con opciones de filtrado.
- `filtro`: upcoming|overdue|all|por-caso
- Muestra: referencia, descripción, fecha, tipo, estado

### alert
Muestra plazos próximos a vencer.
- `días`: rango de alerta (default: 7)
- Color-coded por urgencia:
  - Crítico: <48h (rojo)
  - Advertencia: <7d (amarillo)
  - Información: <14d (azul)

### complete
Marca plazo como completado.
- `caso`: referencia del caso
- `plazo`: identificador del plazo
- `evidencia`: URL/ruta de comprobante (opcional)

### extend
Extiende plazo con justificación.
- `justificación`: motivo de la prórroga
- Crea registro de extensión
- Notifica cambio de fecha

## Almacenamiento

```json
{
  "deadlines": [
    {
      "id": "plazo-001",
      "case": "C-2024-001",
      "description": "Contestación demanda",
      "due_date": "2026-03-20",
      "type": "procesal",
      "priority": "alta",
      "status": "pending",
      "created": "2026-03-06",
      "extensions": []
    }
  ]
}
```

## Alertas Automáticas

- **Crítica**: <48h → notificación inmediata
- **Advertencia**: <7d → alerta diaria
- **Información**: <14d → alerta semanal
