# /spec:implement

Implementa una Spec usando el developer_type definido en ella: lanza el agente adecuado o asigna al desarrollador humano correspondiente.

## Uso
```
/spec:implement {spec_file} [--dry-run] [--override-type human|agent:single|agent:team]
```

- `{spec_file}`: Ruta al fichero `.spec.md` (relativa al workspace)
- `--dry-run`: Muestra qué haría sin ejecutar nada
- `--override-type`: Sobreescribe el developer_type de la Spec para esta ejecución

## Pasos de Ejecución

### Paso 1 — Validar la Spec antes de implementar

```bash
# Leer la spec y verificar los criterios de calidad mínimos
SPEC_FILE="{spec_file}"
cat $SPEC_FILE
```

Verificar que la Spec cumple TODOS estos criterios (si alguno falla → no ejecutar):

```
Checklist de Spec ejecutable:
[ ] developer_type está definido (no vacío o "?")
[ ] Sección 2: Las interfaces/firmas están definidas con tipos concretos
[ ] Sección 3: Reglas de negocio sin "a criterio del dev" ni "TBD"
[ ] Sección 4: Al menos un test scenario definido
[ ] Sección 5: Todos los ficheros a crear están listados con rutas exactas
[ ] Sección 6: Hay al menos un fichero de código de referencia
[ ] Estado: "Pendiente" (no "Bloqueado" ni "Completado")
```

Si algún criterio falla:
```
❌ La Spec no está lista para implementar.
   Problemas detectados:
   - {problema 1}
   - {problema 2}

   Edita la Spec y vuelve a ejecutar /spec:implement
   O ejecuta /spec:review para análisis completo.
```

### Paso 2 — Leer el developer_type

```bash
DEVELOPER_TYPE=$(grep "^\*\*Developer Type:\*\*" $SPEC_FILE | awk '{print $NF}')
# Resultado: "human" | "agent:single" | "agent:team"
```

### Paso 3 — Ejecutar según developer_type

#### Si `developer_type = human`

```
📋 Esta Spec está asignada a un desarrollador humano.

   Asignado a: {nombre del dev en la Spec}
   Task en Azure DevOps: AB#{task_id}

   Acciones disponibles:
   - Notificar al desarrollador (requiere confirmación)
   - Mover la task a "Active" en Azure DevOps (requiere confirmación)
   - Ver la Spec: {spec_file}

¿Quieres que notifique al desarrollador o cambie el estado de la task?
```

#### Si `developer_type = agent:single`

```bash
BASE="projects/{proyecto}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
TASK_ID=$(grep "^\*\*Task ID:\*\*" $SPEC_FILE | grep -oE '[0-9]+')
LOG_FILE="output/agent-runs/${TIMESTAMP}-AB${TASK_ID}-single.log"

# Mostrar plan antes de ejecutar
echo "🤖 LANZAR AGENTE — AB#${TASK_ID}"
echo "   Modelo:  claude-opus-4-5-20251101"
echo "   Spec:    $SPEC_FILE"
echo "   Log:     $LOG_FILE"
echo "   Max turns: 40"
echo ""
echo "¿Procedo a lanzar el agente? (s/n)"
```

Tras confirmación:
```bash
claude --model claude-opus-4-5-20251101 \
  --system-prompt "$(cat $BASE/CLAUDE.md)" \
  --max-turns 40 \
  "Implementa la siguiente Spec exactamente como se describe.
   No tomes decisiones de diseño que no estén en la Spec.
   Si encuentras ambigüedad, detente y documenta la duda en la sección 'Blockers' de la Spec y para INMEDIATAMENTE.
   Al terminar:
   1. Actualiza la sección 'Estado de Implementación' a 'Completado'
   2. Actualiza el log de implementación con los ficheros creados
   3. Ejecuta: dotnet build  (reporta resultado)
   4. Ejecuta: dotnet test {test_project} --filter '{test_filter}'  (reporta resultado)

   $(cat $SPEC_FILE)

   Directorio de trabajo: $BASE/source
   Reglas adicionales:
   - EXACTAMENTE los ficheros de la sección 5 (ni más ni menos)
   - Sigue el patrón del código de referencia en la sección 6
   - Si build o tests fallan, corrígelos (máx 3 intentos por error)" \
  2>&1 | tee "$LOG_FILE"

echo ""
echo "✅ Agente terminado. Log: $LOG_FILE"
echo "🔍 Ejecuta: /spec:review $SPEC_FILE para validar el resultado"
```

#### Si `developer_type = agent:team`

```bash
# Leer el team pattern de la spec (si lo especifica) o usar impl-test por defecto
TEAM_PATTERN=$(grep "^\*\*Team Pattern:\*\*" $SPEC_FILE | awk '{print $NF}')
TEAM_PATTERN=${TEAM_PATTERN:-"impl-test"}  # default

echo "🤖🤖 LANZAR AGENT TEAM — AB#${TASK_ID}"
echo "   Patrón: $TEAM_PATTERN"
echo "   Ver detalles: .claude/skills/spec-driven-development/references/agent-team-patterns.md"
echo ""
echo "¿Procedo a lanzar el equipo de agentes? (s/n)"
```

Tras confirmación, ejecutar el patrón según `agent-team-patterns.md`.

### Paso 4 — Actualizar la Task en Azure DevOps (tras implementación por agente)

```bash
PAT=$(cat $AZURE_DEVOPS_PAT_FILE)

# Cambiar estado a "In Review" y añadir tag "agent-implemented"
curl -s -u ":$PAT" \
  -H "Content-Type: application/json-patch+json" \
  -X PATCH \
  "$AZURE_DEVOPS_ORG_URL/{proyecto}/_apis/wit/workitems/{task_id}?api-version=7.1" \
  -d '[
    {"op": "replace", "path": "/fields/System.State", "value": "In Review"},
    {"op": "add", "path": "/fields/System.Tags", "value": "spec-driven;agent-implemented"},
    {"op": "add", "path": "/fields/System.History", "value": "Implementado por claude-agent (spec-driven). Log: output/agent-runs/{log_filename}"}
  ]'

echo "✅ Task AB#${TASK_ID} movida a 'In Review' en Azure DevOps"
```

> ⚠️ La implementación por agente siempre requiere Code Review humano antes de merge.
> Ejecuta `/spec:review {spec_file}` para un pre-check automático antes del review humano.
