# Lógica de Agrupación — Transformación de Datos

## Estructura de Output

```python
report = {
    "persona": {
        "actividad": {
            "estimado": 0,
            "completado": 0,
            "restante": 0,
            "items": [
                {
                    "id": 123,
                    "titulo": "Task title",
                    "estado": "In Progress",
                    "estimado": 8,
                    "completado": 4,
                    "restante": 4
                }
            ]
        }
    }
}
```

## Algoritmo de Agrupación

```python
import json

with open('/tmp/task-details.json') as f:
    data = json.load(f)

report = {}

for item in data['value']:
    fields = item['fields']
    
    # Extraer campos
    persona = fields.get('System.AssignedTo', {}).get('displayName', 'Sin asignar')
    actividad = fields.get('Microsoft.VSTS.Common.Activity', 'Sin clasificar')
    estimado = fields.get('Microsoft.VSTS.Scheduling.OriginalEstimate', 0) or 0
    completado = fields.get('Microsoft.VSTS.Scheduling.CompletedWork', 0) or 0
    restante = fields.get('Microsoft.VSTS.Scheduling.RemainingWork', 0) or 0
    
    # Inicializar estructura si no existe
    if persona not in report:
        report[persona] = {}
    if actividad not in report[persona]:
        report[persona][actividad] = {
            'estimado': 0,
            'completado': 0,
            'restante': 0,
            'items': []
        }
    
    # Agregar horas
    report[persona][actividad]['estimado'] += estimado
    report[persona][actividad]['completado'] += completado
    report[persona][actividad]['restante'] += restante
    
    # Agregar item a la lista
    report[persona][actividad]['items'].append({
        'id': item['id'],
        'titulo': fields.get('System.Title'),
        'estado': fields.get('System.State'),
        'estimado': estimado,
        'completado': completado,
        'restante': restante
    })

# Calcular totales por persona
for persona in report:
    total_estimado = sum(act['estimado'] for act in report[persona].values())
    total_completado = sum(act['completado'] for act in report[persona].values())
    total_restante = sum(act['restante'] for act in report[persona].values())
```

## Campos Utilizados

| Campo | Origen | Significado |
|-------|--------|-------------|
| `System.Id` | Work Item | ID único |
| `System.Title` | Work Item | Descripción |
| `System.State` | Work Item | Estado actual |
| `System.AssignedTo` | Work Item | Persona asignada |
| `Microsoft.VSTS.Scheduling.OriginalEstimate` | Task | Horas estimadas originales |
| `Microsoft.VSTS.Scheduling.CompletedWork` | Task | Horas completadas/imputadas |
| `Microsoft.VSTS.Scheduling.RemainingWork` | Task | Horas restantes |
| `Microsoft.VSTS.Common.Activity` | Task | Tipo actividad (Development, Testing, etc.) |
