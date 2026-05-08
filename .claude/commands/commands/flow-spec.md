---
name: flow-spec
description: Crear spec ejecutable desde outcome de exploración (puente exploration → production)
developer_type: pm
agent: sdd-spec-writer
context_cost: moderate
max_context: 4000
allowed_modes: [pm, lead, all]
---

# /flow-spec — Crear Spec Ejecutable desde Outcome

> Puente entre Exploración y Producción: convierte outcome en spec estructurado listo para builders.

## Uso
`/flow-spec [--epic {outcome-id}] [--from-file {path}] [--template {tipo}]`

## Subcomandos
- `--epic {AB#XXXX}`: Crear spec vinculado a epic outcome (interactive si no especifica)
- `--from-file {path}`: Cargar outcome desde fichero markdown local
- `--template {tipo}`: Plantilla: sdd (default), discovery, minimal

## Flujo principal

### 1. Seleccionar Outcome
Si `--epic` no especificado:
```
¿Qué outcome exploraste?
1. AB#345 — Pagos internacionales
2. AB#346 — Dashboard ejecutivo
3. AB#347 — Integración proveedores
→ Elegir (1-3):
```

Leer epic: descripción, aceptance criteria, outcome ID.

### 2. Validación de Outcome
- ✅ Tiene descripción clara (>50 caracteres)
- ✅ Tiene acceptance criteria (≥2 items)
- ⚠️ Sin outcome ID → generar automáticamente
- ⚠️ Sin story points → asignar estimado (default 21)

Si falta validación → no bloquea, solo aviso.

### 3. Cargar plantilla
Copiar estructura de `task-template-sdd.md` con 5 secciones:
1. **Outcome & Context**: descripción del outcome (1-2 párrafos)
2. **Metrics & Success**: qué éxito medir, KPIs
3. **Functional Design**: qué construir (user stories, funcionalidades)
4. **Technical Design**: cómo hacerlo (stack, patrones, constraints)
5. **Definition of Done**: checklist minimalista (5-8 items)

### 4. Pre-rellenar datos
- Outcome ID
- Equipo responsable (por proyecto config)
- Story Points (inherited de epic si aplica)
- Tech stack, patterns (from project config `TECH_STACK`, `ARCHITECTURE_PATTERNS`)
- Compliance requerido (if project compliance)

### 5. Crear User Story en Azure DevOps
- Tipo: User Story
- Area Path: {Project}/Exploration
- State: Spec-Writing (no Ready aún)
- Tags: exploration, spec, outcome-{outcome-id}
- Parent: Epic outcome (link)

### 6. Output

```
✅ Spec creado

📋 Spec ID ..................... PBI#8901
   Estado ....................... Spec-Writing
   Outcome linkado .............. AB#345
   Plantilla .................... SDD estándar

📄 Contenido:
   - Outcome & Context
   - Metrics & Success
   - Functional Design (vacío, rellenar)
   - Technical Design (pre-rellenado)
   - Definition of Done

🔗 Enlace ...................... {azure-devops-url}/PBI/8901
💡 Próximo: Completar Functional Design, luego setear a Spec-Ready
```

Si >30 líneas → guardar en `projects/{proyecto}/.flow/spec-created-{date}.md`

## UX y guías

- Plantilla **SDD** (default): 5 secciones estructuradas, enfocadas en spec ejecutable
- Plantilla **Discovery**: más ligera, para outcomes experimentales
- Plantilla **Minimal**: 3 secciones (outcome, qué, cómo)

No bloquear si outcome no tiene todos los datos. El spec se refina en la escritura.
