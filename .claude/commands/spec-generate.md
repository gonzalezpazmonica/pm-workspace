# /spec-generate

Genera una Spec ejecutable (`.spec.md`) a partir de una Task de Azure DevOps, lista para ser implementada por un humano o un agente Claude.

## Uso
```
/spec-generate {task_id} [--project {nombre}] [--sprint {sprint}] [--force-type human|agent-single|agent-team]
```

- `{task_id}`: ID de la Task en Azure DevOps (ej: `1234`)
- `--project`: Proyecto AzDO (default: `AZURE_DEVOPS_DEFAULT_PROJECT`)
- `--sprint`: Sprint para el directorio de la spec (default: sprint activo)
- `--force-type`: Forzar el developer_type (omitir para usar la matrix automática)

## Este comando orquesta

→ `.claude/skills/spec-driven-development/SKILL.md`
→ `.claude/skills/azure-devops-queries/SKILL.md`
→ `references/layer-assignment-matrix.md`
→ `references/spec-template.md`

## Pasos de Ejecución

### Paso 1 — Leer contexto del proyecto

```bash
# Cargar en orden:
# 1. CLAUDE.md raíz
# 2. projects/{proyecto}/CLAUDE.md  (incluye sdd_layer_assignment)
# 3. projects/{proyecto}/reglas-negocio.md
# 4. .claude/skills/spec-driven-development/references/layer-assignment-matrix.md
```

### Paso 2 — Obtener la Task de Azure DevOps

```bash
PAT=$(cat $AZURE_DEVOPS_PAT_FILE)

# Obtener Task completa con todos los campos
curl -s -u ":$PAT" \
  "$AZURE_DEVOPS_ORG_URL/{proyecto}/_apis/wit/workitems/{task_id}?\$expand=all&api-version=7.1" | jq '{
    id: .id,
    title: .fields["System.Title"],
    description: .fields["System.Description"],
    activity: .fields["Microsoft.VSTS.Common.Activity"],
    estimated_hours: .fields["Microsoft.VSTS.Scheduling.OriginalEstimate"],
    state: .fields["System.State"],
    assigned_to: .fields["System.AssignedTo"].displayName,
    iteration: .fields["System.IterationPath"],
    tags: .fields["System.Tags"],
    parent_url: (.relations // [] | map(select(.rel == "System.LinkTypes.Hierarchy-Reverse")) | first | .url // null)
  }'
```

### Paso 3 — Obtener el PBI padre (criterios de aceptación)

```bash
# Extraer el ID del PBI padre de parent_url
PBI_ID=$(echo $PARENT_URL | grep -oE '[0-9]+$')

curl -s -u ":$PAT" \
  "$AZURE_DEVOPS_ORG_URL/{proyecto}/_apis/wit/workitems/$PBI_ID?\$expand=all&api-version=7.1" \
  | jq '.fields | {
    "title": .["System.Title"],
    "description": .["System.Description"],
    "acceptance": .["Microsoft.VSTS.Common.AcceptanceCriteria"],
    "story_points": .["Microsoft.VSTS.Scheduling.StoryPoints"]
  }'
```

### Paso 4 — Detectar el módulo y buscar código de referencia

```bash
PROYECTO_SOURCE="projects/{proyecto}/source"

# Inferir módulo del título de la task (ej: "B3: Handler CreatePatient" → módulo = "Patient")
MODULE="{módulo inferido del título}"

# Buscar handlers/servicios del mismo tipo como referencia
find $PROYECTO_SOURCE/src -name "*Handler.cs" | grep -i "$MODULE" | head -3
find $PROYECTO_SOURCE/src -name "*${TYPE}*.cs" | head -3  # TYPE = Handler|Service|Repository|Controller

# Leer el fichero de referencia más relevante
# (el agente debe elegir el más similar a lo que se va a implementar)
```

### Paso 5 — Determinar el Developer Type

Aplicar la matrix de `references/layer-assignment-matrix.md`:

1. Extraer la capa y tipo de la Task (ej: "B3: Handler" → Application Layer, Command Handler)
2. Buscar el `developer_type` en la matrix del proyecto (en `projects/{proyecto}/CLAUDE.md § sdd_layer_assignment`)
3. Si no hay override de proyecto, usar la matrix global
4. Si `--force-type` está especificado, usar ese valor

Mostrar al usuario: `Developer Type determinado: agent-single (Application / Command Handler)`

### Paso 6 — Construir la Spec

Usando la plantilla `references/spec-template.md`, rellenar:

- **Sección 1** (Contexto y Objetivo): extraído de la description de la Task + PBI
- **Sección 2** (Contrato Técnico): inferido del título + código de referencia
- **Sección 3** (Reglas de Negocio): extraído de los criterios de aceptación del PBI + `reglas-negocio.md`
- **Sección 4** (Test Scenarios): derivado de los criterios de aceptación
- **Sección 5** (Ficheros a Crear): inferido del tipo de task + módulo + estructura del proyecto
- **Sección 6** (Código de Referencia): el fichero encontrado en el Paso 4
- **Sección 7** (Configuración): constantes del proyecto

### Paso 7 — Guardar la Spec

```bash
# Naming convention: AB{task_id}-{tipo_code}-{descripcion-corta}.spec.md
# Ejemplo: AB1234-B3-create-patient-handler.spec.md

SPEC_DIR="projects/{proyecto}/specs/{sprint}"
mkdir -p $SPEC_DIR
SPEC_FILE="$SPEC_DIR/AB{task_id}-{tipo}-{descripcion-corta}.spec.md"
```

### Paso 8 — Mostrar resumen y preguntar

```
📄 SPEC GENERADA — AB#{task_id}: {título}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Developer Type:  agent-single  (Application / Command Handler)
Fichero:         {spec_file_path}
Estimación:      {Xh}
Asignado a:      {dev o "claude-agent"}

Checklist de calidad:
  ✅ Contrato técnico definido
  ✅ Reglas de negocio especificadas (N reglas)
  ✅ Test scenarios escritos (N scenarios)
  ✅ Ficheros a crear listados (N ficheros)
  ✅ Código de referencia incluido
  ⚠️  {advertencia si algún campo quedó incompleto}

¿Está lista para implementar? Puedes:
  - Ejecutar: /spec-implement {spec_file}  (si developer_type es agent)
  - Revisar el fichero manualmente antes de asignar
  - Ejecutar: /spec-review {spec_file}     (para validación adicional)
```

> ⚠️ La Spec generada es un BORRADOR. Siempre revisarla antes de darla a un agente o a un desarrollador.
> Si algún campo tiene {placeholder} sin rellenar, la Spec NO está lista para implementar.
