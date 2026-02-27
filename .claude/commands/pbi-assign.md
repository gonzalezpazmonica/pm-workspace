# /pbi-assign

Asigna (o reasigna) las Tasks existentes de un PBI según el algoritmo de asignación inteligente, sin recrear las tasks.

## Uso
```
/pbi-assign {pbi_id} [--project {nombre}] [--rebalance]
```

- `{pbi_id}`: ID del PBI padre cuyas tasks se quieren (re)asignar
- `--rebalance`: Redistribuye teniendo en cuenta la carga actual de TODO el sprint, no solo las tasks de este PBI

## Cuándo usar este comando

- Las tasks ya existen en Azure DevOps pero no están asignadas o están mal distribuidas
- Alguien del equipo se ha ido de baja / vacaciones inesperadas y hay que redistribuir
- Tras un cambio de capacity (ej: Pedro no puede trabajar esta semana) y quieres rebalancear
- Como alternativa más rápida a `/pbi-decompose` cuando ya tienes las tasks

## Diferencia con /pbi-decompose

`/pbi-decompose` → Crea tasks nuevas desde cero + asigna
`/pbi-assign` → Solo reasigna tasks que ya existen

## Pasos de Ejecución

1. Obtener las Tasks hijas del PBI:
   ```bash
   PAT=$(cat $AZURE_DEVOPS_PAT_FILE)
   # Obtener el PBI con sus links (tipo Hierarchy-Forward = Tasks hijas)
   curl -s -u ":$PAT" \
     "$AZURE_DEVOPS_ORG_URL/{proyecto}/_apis/wit/workitems/{pbi_id}?\$expand=relations&api-version=7.1" \
     | jq '.relations[] | select(.rel == "System.LinkTypes.Hierarchy-Forward") | .url'
   ```

2. Para cada task, obtener: título, activity, estimated hours, estado actual, asignado actual

3. Cargar estado de capacity del equipo (skill `capacity-planning`)

4. Aplicar el algoritmo de scoring de `references/assignment-scoring.md`
   - Si `--rebalance`: considerar TODA la carga del sprint (WIQL: remaining work de todos los items)
   - Si no `--rebalance`: considerar solo la carga de las tasks de este PBI

5. Presentar la propuesta de (re)asignación:

```
🔄 Reasignación de Tasks — PBI #{id}: {título}

   ┌────┬─────────────────────────────────────┬──────┬──────────────────────────────────┐
   │ ID │ Task                                │ h    │ Asignación propuesta             │
   ├────┼─────────────────────────────────────┼──────┼──────────────────────────────────┤
   │ T1 │ B3: Handler CreatePatientCommand    │ 4h   │ Juan García (antes: Sin asignar) │
   │ T2 │ D1: Unit tests                      │ 3h   │ Ana López (antes: Juan García)   │
   └────┴─────────────────────────────────────┴──────┴──────────────────────────────────┘

   📊 Impacto en capacity tras reasignación:
      Juan García: 32h → 36h de 60h disponibles 🟢
      Ana López: 20h → 23h de 60h disponibles 🟢

¿Aplico estas reasignaciones en Azure DevOps? (s/n)
```

6. Tras confirmación → PATCH en cada task:
   ```bash
   curl -s -u ":$PAT" \
     -H "Content-Type: application/json-patch+json" \
     -X PATCH \
     "$AZURE_DEVOPS_ORG_URL/{proyecto}/_apis/wit/workitems/{task_id}?api-version=7.1" \
     -d '[{"op": "replace", "path": "/fields/System.AssignedTo", "value": "persona@empresa.com"}]'
   ```

> ⚠️ Operación de escritura — siempre confirmar con el usuario antes de ejecutar.
