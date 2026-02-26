# Skill: Product Discovery

## Cuándo usar esta skill

Invocar **antes** de descomponer un PBI en tasks técnicas cuando:
- El PBI es de tipo **feature** o **user story** (no bug ni chore)
- Los criterios de aceptación son vagos o inexistentes
- Se necesita formalizar el *por qué* del usuario antes del *cómo* técnico
- El `business-analyst` necesita un workflow estructurado de análisis

## Qué produce

Dos documentos que preceden la descomposición técnica:

1. **JTBD (Jobs to be Done)** — captura el *por qué* del comportamiento del usuario
2. **PRD (Product Requirements Document)** — captura el *qué* del producto

## Flujo completo

```
PBI en Azure DevOps
    ↓
/pbi:jtbd {id}          ← business-analyst genera JTBD
    ↓
/pbi:prd {id}           ← business-analyst genera PRD (lee JTBD)
    ↓
/pbi:decompose {id}     ← flujo existente (architect + spec-writer + ...)
```

## Cuándo NO usar

- PBIs tipo `Bug` → no necesitan discovery, necesitan diagnóstico
- PBIs tipo `Chore` → mantenimiento técnico sin impacto de usuario
- PBIs con criterios de aceptación ya detallados y validados por el PO
- Tasks individuales que ya tienen spec SDD aprobada

## Almacenamiento

Los documentos se guardan en el directorio del proyecto:
```
projects/{proyecto}/discovery/
├── PBI-{id}-jtbd.md
└── PBI-{id}-prd.md
```

Si el directorio `discovery/` no existe, crearlo automáticamente.

## Plantillas

Las plantillas JTBD y PRD están en `references/`:
- `references/jtbd-template.md` — plantilla Jobs to be Done
- `references/prd-template.md` — plantilla Product Requirements Document

## Agente responsable

El agente `business-analyst` es quien ejecuta ambos documentos.
No delegar a `architect` ni a `sdd-spec-writer` — esto es análisis de producto,
no diseño técnico.
