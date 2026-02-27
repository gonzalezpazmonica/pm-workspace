# API de Capacidades — Estructura de Respuestas

## GET /teamsettings/iterations/{iterationId}/capacities

Respuesta esperada:

```json
{
  "value": [
    {
      "teamMember": {
        "displayName": "Juan García",
        "uniqueName": "juan@empresa.com",
        "id": "abc123-def456-...",
        "imageUrl": "..."
      },
      "activities": [
        {
          "name": "Development",
          "capacityPerDay": 6
        },
        {
          "name": "Testing",
          "capacityPerDay": 2
        }
      ],
      "daysOff": [
        {
          "start": "2026-03-05T00:00:00Z",
          "end": "2026-03-05T00:00:00Z"
        }
      ]
    }
  ],
  "count": 5
}
```

## GET /teamsettings/iterations/{iterationId}/teamdaysoff

Días off del equipo (festivos, vacaciones colectivas):

```json
{
  "daysOff": [
    {
      "start": "2026-03-01T00:00:00Z",
      "end": "2026-03-02T00:00:00Z"
    }
  ]
}
```

## PATCH /teamsettings/iterations/{iterationId}/capacities/{teamMemberId}

Actualizar capacidad de una persona:

```json
{
  "activities": [
    { "name": "Development", "capacityPerDay": 6 }
  ],
  "daysOff": [
    {
      "start": "2026-03-10T00:00:00Z",
      "end": "2026-03-14T00:00:00Z"
    }
  ]
}
```
