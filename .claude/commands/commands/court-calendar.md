---
name: court-calendar
description: >
  Gestiona calendario de comparecencias judiciales.
  Subcomandos: import (añadir fecha), sync (importar ICS),
  list (listar próximas), conflict (detectar conflictos),
  export (exportar a ICS).
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
---

# Calendario Judicial

Organiza y sincroniza comparecencias y vistas judiciales con detección de conflictos.

## Uso

```
court-calendar import <caso> <juzgado> <fecha> <hora> [tipo]
court-calendar sync <archivo-ics>
court-calendar list [próximos-días]
court-calendar conflict
court-calendar export <formato>
```

## Subcomandos

### import
Añade fecha judicial manualmente.
- `caso`: referencia del caso
- `juzgado`: nombre/número del juzgado
- `fecha`: fecha (YYYY-MM-DD)
- `hora`: hora (HH:MM)
- `tipo`: vista|juicio|comparecencia (default: comparecencia)

Almacena en: `projects/{proyecto}/legal/court-calendar.json`

### sync
Lee e importa fechas desde archivo ICS.
- `archivo-ics`: ruta del archivo de calendario
- Parsea eventos y crea entradas
- Vincula a plazos legales existentes

### list
Muestra próximas comparecencias judiciales.
- `próximos-días`: rango de visualización (default: 30)
- Muestra: caso, juzgado, fecha, hora, tipo, abogado

### conflict
Detecta conflictos de agenda.
- Identifica: mismo abogado, horarios superpuestos
- Considera tiempo de desplazamiento (1h por defecto)
- Sugerencias de reprogramación
- Filtra por abogado/período

### export
Exporta calendario a formato ICS.
- Compatible con Outlook, Google Calendar, Apple Calendar
- Incluye detalles: caso, juzgado, contactos

## Almacenamiento

```json
{
  "court_dates": [
    {
      "id": "cd-001",
      "case": "C-2024-001",
      "court": "Juzgado 5 Mercantil",
      "date": "2026-03-25",
      "time": "10:30",
      "type": "vista",
      "assigned_to": "Abogado 1",
      "address": "Paseo de Recoletos 25",
      "deadline_id": "plazo-001"
    }
  ]
}
```

## Vinculación

- Cada entrada de juzgado vincula a plazo legal
- Alertas sincronizadas con deadline
- Historial de cambios registrado
