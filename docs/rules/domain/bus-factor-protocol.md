---
context_tier: L2
token_budget: 1200
spec: SE-252
resource: internal://docs/rules/domain/bus-factor-protocol.md
---

# Regla: Bus Factor Protocol

> SE-252 -- Bus Factor Shield. Aplica a todos los proyectos gestionados
> con pm-workspace que tengan historial git accesible.

## Cuando ejecutar el scan (triggers)

### Triggers automaticos

| Evento | Accion | Prioridad |
|--------|--------|-----------|
| Dev sale del equipo (baja, dimision, traslado) | Scan inmediato + plan de redistribucion | P0 |
| Dev en baja medica > 1 semana | Scan del proyecto donde trabaja | P0 |
| Vacaciones > 2 semanas (unico conocedor de modulo critico) | Scan pre-vacaciones | P1 |
| Incorporacion de nuevo dev | Scan + plan de onboarding | P1 |
| Pre-release / milestone critico | Scan completo | P1 |
| Revision mensual rutinaria | Scan todos los proyectos activos | P2 |

### Triggers manuales

- Se detecta siloizacion en retro ("solo X sabe como funciona esto")
- Un modulo no recibe PR reviews de nadie mas en 3+ sprints
- Alguien pregunta "oye, quien sabe como funciona X?"

## Que hacer cuando se detecta BF=1 (protocolo de accion)

### Paso 1: Generar cupula de contexto (ese mismo dia)

```bash
bash scripts/context-dome-generate.sh \
  --project <path> \
  --module <modulo-critico> \
  --min-risk CRITICAL
```

### Paso 2: Identificar backup owner (esa semana)

```bash
bash scripts/bus-factor-distribute.sh \
  --project <path> \
  --target <candidato-backup>
```

Candidato ideal: dev que ya trabaja en modulos adyacentes.

### Paso 3: Sesion de knowledge transfer (ese sprint)

- El knowledge owner hace una sesion de pair programming guiada
  por el CONTEXT_DOME.md del modulo
- El backup owner resuelve un bug o feature pequena en el modulo
  (aprendizaje activo)
- El backup owner valida el CONTEXT_DOME.md: puede arrancar sin ayuda?

### Paso 4: Actualizar scan y verificar BF (siguiente sprint)

El BF no sube inmediatamente: el historial git tarda en reflejar
el nuevo conocimiento. Verificar despues de 2-3 sprints.

## Umbrales organizativos recomendados

| Nivel | BF | Riesgo | Tiempo de respuesta |
|-------|----|--------|---------------------|
| CRITICAL | 1 | Incapacitante ante cualquier ausencia | < 1 semana |
| HIGH | 2 | Riesgo ante ausencia simultanea de 2 devs | < 1 sprint |
| MEDIUM | 3 | Riesgo moderado | < 1 trimestre |
| LOW | > 3 | Riesgo bajo | Revision mensual |

### Objetivo organizativo sugerido

> Ningún módulo critico (BF_RISK_CRITICAL) debe tener BF=1 al inicio de
> cada sprint. Si se detecta, entra en el sprint como tarea P0.

## Responsabilidades

| Rol | Responsabilidad |
|-----|-----------------|
| Tech Lead / Arquitecto | Ejecutar scan mensual, presentar informe en retro |
| Knowledge Owner | Participar en sesiones de transfer, validar CONTEXT_DOME.md |
| Dev asignado como backup | Completar sesion de transfer, resolver al menos 1 issue en el modulo |
| PM | Incluir tareas de knowledge transfer en sprint planning cuando BF=1 |
| Savia (IA) | Ejecutar scan bajo peticion, generar cupulas, generar planes de distribucion |

## Configuracion minima recomendada

```bash
# .env del proyecto o variables de sesion
export BF_OWNERSHIP_THRESHOLD=0.50
export BF_MIN_COMMITS=5
export BF_MODULE_DEPTH=2
export BF_EXCLUDE_PATTERNS="vendor/,node_modules/,*.lock,*.sum"
export BF_OUTPUT_DIR="output/bus-factor/"
```

## Integraciones con el ecosistema Savia

- `skills/bus-factor-analysis`: skill principal para ejecutar el scan
- `skills/context-dome`: skill para generar cupulas de contexto
- `skills/human-code-map`: usa el plan de distribucion para sesiones de onboarding
- `hooks/bus-factor-warn.sh`: avisa en tiempo real al modificar archivos BF=1
- `codebase-memory-mcp`: enriquece el grafo de conocimiento con datos de BF

## Notas de implementacion

- Los JSONs de scan van a `output/bus-factor/` (gitignored por `output/`)
- El hook `bus-factor-warn.sh` es warn-only: nunca bloquea operaciones
- El scan es read-only: no modifica el repositorio analizado
- Solo requiere git + python3 (stdlib) + bash
