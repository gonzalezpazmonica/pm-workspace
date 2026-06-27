# Org Model Schema — Modelo Intermedio Normalizado

> Contrato JSON que todos los parsers producen y las fases 3-6 consumen.

## Schema

```json
{
  "department": {
    "name": "string (obligatorio, no vacio)",
    "responsable": "string|null (@handle o null si desconocido)"
  },
  "teams": [
    {
      "name": "string (obligatorio)",
      "capacity_total": "number (>0, suma de capacidades)",
      "members": [
        {
          "handle": "string (obligatorio, con @ prefijo)",
          "role": "string (obligatorio: developer|qa|tech-lead|architect|pm|designer|member)",
          "is_lead": "boolean (true si es lead del equipo)",
          "capacity": "number (0.1-1.0, dedicacion al equipo)"
        }
      ]
    }
  ],
  "supervisor_links": [
    {
      "from": "string (@handle del supervisor)",
      "to": "string (@handle del supervisado)"
    }
  ]
}
```

## Campos obligatorios

| Campo | Obligatorio | Default si ausente |
|---|---|---|
| department.name | Si | Error |
| department.responsable | No | null |
| teams[].name | Si | Error |
| teams[].capacity_total | No | Suma de members[].capacity |
| teams[].members | Si (>=1) | Error |
| members[].handle | Si | Error |
| members[].role | No | "member" |
| members[].is_lead | No | false |
| members[].capacity | No | capacity_total / num_members |
| supervisor_links | No | [] |

## Reglas de validacion

1. `department.name` no puede estar vacio
2. Cada equipo debe tener al menos 1 miembro
3. `handle` debe empezar con `@`
4. `capacity` debe estar entre 0.1 y 1.0
5. `capacity_total` debe ser >= suma de capacidades individuales
6. No duplicar handles dentro del mismo equipo
7. Handles duplicados entre equipos → warn (multi-equipo valido)

## Ejemplo completo

```json
{
  "department": {
    "name": "Engineering",
    "responsable": "@alice"
  },
  "teams": [
    {
      "name": "Backend",
      "capacity_total": 2.5,
      "members": [
        { "handle": "@bob", "role": "tech-lead", "is_lead": true, "capacity": 1.0 },
        { "handle": "@charlie", "role": "developer", "is_lead": false, "capacity": 1.0 },
        { "handle": "@diana", "role": "developer", "is_lead": false, "capacity": 0.5 }
      ]
    },
    {
      "name": "Frontend",
      "capacity_total": 1.5,
      "members": [
        { "handle": "@eve", "role": "tech-lead", "is_lead": true, "capacity": 1.0 },
        { "handle": "@diana", "role": "developer", "is_lead": false, "capacity": 0.5 }
      ]
    }
  ],
  "supervisor_links": [
    { "from": "@alice", "to": "@bob" },
    { "from": "@alice", "to": "@eve" }
  ]
}
```

Note: `@diana` aparece en 2 equipos con capacity 0.5 cada uno (total 1.0).
