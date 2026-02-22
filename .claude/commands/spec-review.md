# /spec:review

Valida una Spec existente: verifica calidad, completitud y alineación con el PBI padre. También puede revisar el código implementado contra la Spec.

## Uso
```
/spec:review {spec_file} [--check-impl] [--project {nombre}]
```

- `{spec_file}`: Ruta al fichero `.spec.md`
- `--check-impl`: Además de la Spec, verifica que el código implementado la cumple
- `--project`: Proyecto AzDO (default: inferido del path de la spec)

## Modo 1: Review de Spec (sin `--check-impl`)

Verifica que la Spec es ejecutable antes de asignarla.

### Checklist automático

```
📋 SPEC REVIEW — {spec_filename}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CALIDAD DE LA SPEC:

Sección 1 — Contexto:
  [✅/❌] Objetivo claro y específico
  [✅/❌] Criterios de aceptación del PBI incluidos

Sección 2 — Contrato:
  [✅/❌] Firma/interfaz definida con tipos concretos (sin "any" ni genéricos sin instanciar)
  [✅/❌] Todos los campos de DTOs tienen tipo y restricciones
  [✅/❌] Dependencias a inyectar están listadas

Sección 3 — Reglas de negocio:
  [✅/❌] Sin lenguaje ambiguo ("según corresponda", "a criterio del dev", "TBD")
  [✅/❌] Cada regla tiene error/excepción definida
  [✅/❌] Cada regla es verificable con un test

Sección 4 — Test Scenarios:
  [✅/❌] Happy path cubierto
  [✅/❌] Al menos 2 casos de error cubiertos
  [✅/❌] Al menos 1 edge case definido
  [✅/❌] Los scenarios tienen formato Given/When/Then o equivalente claro

Sección 5 — Ficheros:
  [✅/❌] Rutas exactas (no relativas ni con wildcards)
  [✅/❌] Ningún fichero crítico marcado como "NO tocar" sin especificar por qué
  [✅/❌] Los ficheros a modificar existen realmente en el codebase

Sección 6 — Código de referencia:
  [✅/❌] Al menos 1 fichero de referencia especificado
  [✅/❌] El fichero de referencia existe en el codebase

Developer Type:
  [✅/❌] Definido (human | agent:single | agent:team)
  [✅/❌] Coherente con la complejidad de la Spec
  [✅/❌] Si es agent: todos los criterios de agentización se cumplen

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RESULTADO:
  ✅ SPEC LISTA — Puede ser implementada tal como está
  ⚠️  SPEC CON ADVERTENCIAS — Revisar los puntos marcados antes de asignar
  ❌ SPEC INCOMPLETA — No asignar a un agente hasta resolver los puntos críticos

PUNTOS CRÍTICOS (si los hay):
  1. {descripción del problema + dónde está en la Spec + cómo corregirlo}
  2. ...

RECOMENDACIÓN:
  {Siguiente paso recomendado}
```

## Modo 2: Review de Implementación (con `--check-impl`)

Verifica que el código implementado cumple la Spec. Se ejecuta después de que un agente o humano termina.

### Pasos

```bash
SPEC_FILE="{spec_file}"
BASE="projects/{proyecto}/source"

# Leer la lista de ficheros creados/modificados según la Spec (sección 5)
# Verificar que existen en el codebase
for FILE in $(grep -A50 "## 5\. Ficheros" $SPEC_FILE | grep "^├\|^└\|^│" | awk '{print $NF}'); do
  if [ -f "$BASE/$FILE" ]; then
    echo "✅ $FILE"
  else
    echo "❌ FALTA: $FILE"
  fi
done
```

### Checklist de implementación

```
📋 IMPL REVIEW — AB#{task_id}: {título}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

FICHEROS:
  [✅/❌] Todos los ficheros de la sección 5 existen
  [✅/❌] No hay ficheros adicionales no especificados en la Spec

CONTRATO:
  [✅/❌] Las firmas de clases/métodos coinciden con la sección 2
  [✅/❌] Los DTOs tienen los campos y tipos correctos
  [✅/❌] Las dependencias inyectadas son las de la sección 2.3

REGLAS DE NEGOCIO:
  [✅/❌] Cada regla de la sección 3 tiene código correspondiente
  [✅/❌] Los errores/excepciones lanzados coinciden con la sección 3

TESTS:
  [✅/❌] Existe test para cada scenario del happy path
  [✅/❌] Existe test para cada scenario de error
  [✅/❌] Existe test para los edge cases

PARA IMPLEMENTACIONES DE AGENTE:
  [✅/❌] No hay decisiones de diseño fuera de la Spec
  [✅/❌] No hay código generado innecesario
  [✅/❌] Nombres siguen las convenciones del proyecto (sección 6)

BUILD Y TESTS:
  [✅/❌] dotnet build → sin errores
  [✅/❌] dotnet test → N/N tests passing

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RESULTADO:
  ✅ LISTO PARA CODE REVIEW — Sin issues bloqueantes
  ⚠️  CON MEJORAS — Issues no bloqueantes encontrados
  ❌ NECESITA CORRECCIONES — Hay issues bloqueantes

ISSUES ENCONTRADOS:
  🔴 BLOQUEANTE: {descripción}
  🟡 MEJORA: {descripción}

PRÓXIMO PASO:
  {Si OK: "Asignar Code Review (E1) a {reviewer}"}
  {Si issues: "Corregir issues y re-ejecutar /spec:review --check-impl"}
```

## Registrar en SDD Metrics

```bash
# Actualizar el fichero de métricas del sprint
METRICS_FILE="projects/{proyecto}/specs/sdd-metrics.md"

# Añadir línea de métricas de esta Spec
echo "| {sprint} | AB#{task_id} | {developer_type} | {spec_quality} | {impl_ok} | {review_issues} | {horas_est} | {horas_real} |" >> $METRICS_FILE
```
