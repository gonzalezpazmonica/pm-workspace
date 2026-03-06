---
name: conflict-check
description: >
  Verifica conflictos de interés entre clientes y materias.
  Subcomandos: client (buscar conflictos cliente), matter (buscar conflictos materia),
  report (generar informe), register (registrar comprobación).
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
---

# Gestor de Conflictos de Interés

Verifica conflictos entre clientes, materias y partes relacionadas con privacidad.

## Uso

```
conflict-check client <nombre>
conflict-check matter <descripción>
conflict-check report [rango-fechas]
conflict-check register <resultado>
```

## Subcomandos

### client
Busca nuevo cliente contra clientes/partes existentes.
- `nombre`: nombre del cliente o parte interesada
- Comprueba: mismo cliente, entidades relacionadas, terceros anteriores
- Output: lista de posibles conflictos sin detalles de otros casos

Almacena en: `projects/{proyecto}/legal/conflicts/registry.json`

### matter
Busca materia nueva contra materias existentes.
- `descripción`: tipo de asunto (contrato, litigio, etc.)
- Comprueba: clientes enfrentados, materias idénticas, partes correlacionadas
- Detecta: si nueva materia conflictúa con acuerdos de confidencialidad

### report
Genera informe consolidado de conflictos.
- `rango-fechas`: YYYY-MM-DD a YYYY-MM-DD (opcional)
- Muestra: hallazgos, clientes potencialmente conflictivos, recomendaciones
- Formatea: tabla de conflictos detectados + acciones recomendadas

### register
Registra comprobación completada y autorizada.
- `resultado`: APROBADO|CONFLICTO_DETECTADO|PENDIENTE_REVISIÓN
- Documentos firmante, fecha, conclusión
- Mantiene audit trail de validaciones

## Reglas de Privacidad

- NUNCA mostrar detalles de casos de otras materias
- Solo confirmar/negar existencia de conflicto
- Información sensible cifrada en la persistencia
- Acceso restringido por rol (solo socios/compliance)

## Almacenamiento

```json
{
  "conflicts": [
    {
      "id": "conf-001",
      "client": "cliente-nuevo",
      "type": "client_overlap|matter_conflict|party_conflict",
      "severity": "critical|high|medium",
      "status": "open|resolved",
      "created": "2026-03-06",
      "reviewer": "socio",
      "notes": "detalles de conflicto"
    }
  ]
}
```

## Comprobaciones Automáticas

- Bases de datos de clientes y partes
- Histórico de materias cerradas
- Acuerdos de confidencialidad y restricciones
- Partes relacionadas y holdings
