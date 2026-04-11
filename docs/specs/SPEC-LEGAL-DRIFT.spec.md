# Spec: /legal-drift — Deteccion de reformas legislativas en reglas auditadas

**Task ID:**        SPEC-LEGAL-DRIFT
**PBI padre:**      Legal compliance continuity
**Sprint:**         2026-08
**Fecha creacion:** 2026-04-11
**Creado por:**     Savia (research: github.com/legalize-dev/legalize-es)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     4h
**Estado:**         Pendiente
**Max turns:**      25
**Modelo:**         claude-sonnet-4-6

---

## 1. Contexto y Objetivo

pm-workspace integra `legalize-es` (corpus BOE + 17 CCAA, ~12.235 normas)
via el agente `legal-compliance` y el comando `/legal-audit`. La integracion
actual usa GREP estatico: lee los .md del corpus, busca coincidencias,
cruza contra reglas de negocio.

El valor no explotado: **cada reforma de ley es un commit en el repo
legalize-es**. Con `git log` sobre un fichero de norma se puede reconstruir
CUANDO cambio un articulo y QUE cambio. Ningun competidor hace esto.

Caso de uso real: una spec SDD aprobada hace 6 meses cruza con el articulo
X de la LOPDGDD. El articulo X se reformo hace 3 semanas. La spec sigue
referenciando el texto antiguo. `/legal-audit` no lo detecta porque el
corpus actualizado ya no contiene el texto antiguo. Pero `/legal-drift`
puede detectarlo via `git log`.

**Objetivo:** nuevo command `/legal-drift` que, dado un proyecto, cruza
las reglas de negocio contra el historial git de legalize-es y alerta
de reformas desde la ultima auditoria.

**Criterios de Aceptacion:**
- [ ] Command `/legal-drift [--project X] [--since DATE]` funcional
- [ ] Detecta reformas en articulos referenciados por reglas del proyecto
- [ ] Output con diff del texto reformado (antes/despues)
- [ ] Recomendacion de accion: reviewar regla N de proyecto X
- [ ] Performance aceptable con corpus de 12K+ ficheros
- [ ] Test BATS con >=80 score

---

## 2. Contrato Tecnico

### 2.1 Flujo de deteccion

```
1. Leer projects/{p}/business-rules/LEGAL-REFS.md (o similar)
   formato: RN-XXX -> BOE-A-YYYY-NNNN articulo Z
2. Para cada referencia:
   a. Resolver path en legalize-es: es/leyes/{id}.md
   b. Ejecutar: git -C $LEGALIZE_ES_PATH log --since={fecha} -- {path}
   c. Si hay commits nuevos, diff el contenido del articulo
3. Agrupar reformas por regla del proyecto
4. Generar reporte con severidad segun magnitud del diff
```

### 2.2 Estructura de LEGAL-REFS.md

Convencion en cada proyecto:

```markdown
# Referencias legales del proyecto

## RN-001 — Consentimiento para tratamiento de datos
- Norma: BOE-A-2018-16673 (LOPDGDD)
- Articulo: 6
- Ultima auditoria: 2026-01-15

## RN-042 — Derecho de supresion
- Norma: BOE-A-2016-06091 (RGPD consolidado)
- Articulo: 17
- Ultima auditoria: 2026-02-01
```

### 2.3 Resolucion de paths en legalize-es

legalize-es tiene estructura:
```
es/
  leyes/
    BOE-A-2018-16673.md
  ccaa/
    es-an/
      ...
```

El script normaliza:
- `BOE-A-2018-16673` -> `es/leyes/BOE-A-2018-16673.md`
- `DOGC-2023-XXX` -> `ccaa/es-ct/DOGC-2023-XXX.md`

### 2.4 Git log query

```bash
git -C "$LEGALIZE_ES_PATH" log \
  --since="$SINCE_DATE" \
  --format="%H|%aI|%s" \
  -- "$NORMA_PATH"
```

Por cada commit devuelto, verificar si el articulo especifico fue tocado:

```bash
git -C "$LEGALIZE_ES_PATH" show "$COMMIT" -- "$NORMA_PATH" | \
  grep -A 30 "^## Articulo $ART_NUM"
```

### 2.5 Severidad del diff

| Magnitud | Severidad | Accion |
|----------|-----------|--------|
| Solo tipografico/puntuacion | INFO | Log, no alertar |
| Cambio de palabras sin cambiar sentido | WARNING | Review recomendado |
| Cambio de obligaciones/plazos | CRITICAL | Revisar regla inmediatamente |
| Articulo derogado | BLOCKER | Bloquear release que dependa |

La clasificacion usa LLM (legal-compliance agent en modo review) para
evaluar el diff semanticamente.

### 2.6 Comando slash

```bash
/legal-drift                             # todos los proyectos, since ultima auditoria
/legal-drift --project proyecto-alpha         # un proyecto
/legal-drift --project X --since 2026-01-01  # desde fecha especifica
/legal-drift --severity critical         # solo criticas
/legal-drift --update-audit-date         # tras revisar, actualiza fechas
```

### 2.7 Output

```markdown
# Legal Drift — proyecto proyecto-alpha

Auditado: 2026-04-11
Desde: 2026-01-15 (ultima auditoria del proyecto)

## Reformas detectadas

### CRITICAL — RN-001 Consentimiento
- **Norma:** LOPDGDD (BOE-A-2018-16673)
- **Articulo:** 6
- **Commit:** a3f2c1d — 2026-03-20
- **Diff:** [articulo se endurecio, nueva obligacion de...]
- **Accion:** Revisar implementacion de RN-001 en proyecto-alpha antes
  del 2026-05-01 (entrada en vigor de la reforma)

### WARNING — RN-042 Derecho de supresion
- **Norma:** RGPD consolidado
- **Articulo:** 17
- **Commit:** 9d8e7f2 — 2026-02-25
- **Diff:** [aclaracion de plazo...]
- **Accion:** Review opcional, sentido legal no cambia

## Sin cambios detectados: 8 referencias
```

---

## 3. Reglas de Negocio

| ID | Regla | Error si viola |
|----|-------|----------------|
| LDR-01 | git log respeta fecha de ultima auditoria por proyecto | Falsos positivos |
| LDR-02 | Diff clasificado por LLM, no keyword match | Clasificacion superficial |
| LDR-03 | BLOCKER siempre alerta a Monica | Compliance breach |
| LDR-04 | Cache de paths resueltos (performance) | Slow en corpus grande |
| LDR-05 | --update-audit-date requiere confirmacion humana | Actualizacion silenciosa |
| LDR-06 | Corpus legalize-es auto-update antes de audit | Datos obsoletos |

---

## 4. Constraints

| Dimension | Requisito |
|-----------|-----------|
| Dependencias | git + bash + LEGALIZE_ES_PATH (ya en pm-config) |
| Performance | <30s para proyecto con 50 referencias |
| Offline | Funciona sin red si corpus esta local |
| Precision | LLM-judge minimiza falsos positivos |

---

## 5. Test Scenarios

### Sin reformas

```
GIVEN   proyecto con 10 refs, corpus sin cambios desde ultima auditoria
WHEN    /legal-drift --project X
THEN    output "Sin cambios detectados: 10 referencias"
AND     exit 0
```

### Reforma CRITICAL detectada

```
GIVEN   RN-001 del proyecto referencia BOE-A-2018-16673 art 6
AND     corpus tiene commit reciente modificando art 6
WHEN    /legal-drift --project X
THEN    output contiene seccion CRITICAL para RN-001
AND     diff mostrado con contexto
AND     recomendacion de accion
```

### Articulo derogado

```
GIVEN   ref apunta a articulo que aparece en commit con "Articulo derogado"
WHEN    /legal-drift
THEN    severidad = BLOCKER
AND     alerta destacada
```

### Corpus obsoleto

```
GIVEN   LEGALIZE_ES_AUTO_UPDATE=true, corpus con 30 dias sin pull
WHEN    /legal-drift
THEN    git pull automatico antes del audit
AND     log "corpus actualizado desde origin"
```

### Update audit date

```
GIVEN   usuario revisa reformas y confirma
WHEN    /legal-drift --project X --update-audit-date
THEN    LEGAL-REFS.md actualiza "Ultima auditoria" en refs revisadas
AND     siguiente run no las vuelve a alertar
```

---

## 6. Ficheros a Crear/Modificar

| Accion | Fichero | Que hacer |
|--------|---------|-----------|
| Crear | scripts/legal-drift.sh | Orquestador principal |
| Crear | scripts/legal-drift-resolve.sh | Resolver paths en corpus |
| Crear | scripts/legal-drift-classify.sh | LLM classifier wrapper |
| Crear | .claude/commands/legal-drift.md | Command slash |
| Crear | tests/test-legal-drift.bats | Suite BATS |
| Modificar | .claude/agents/legal-compliance.md | Modo classifier |
| Modificar | .claude/rules/domain/pm-config.md | Verificar LEGALIZE_ES_* |
| Crear | projects/PROJECT_TEMPLATE.md | Incluir LEGAL-REFS.md template |
| Modificar | .claude/rules/domain/legal-compliance.md | Cross-ref drift |

---

## 7. Metricas de exito

| Metrica | Objetivo | Medicion |
|---------|----------|----------|
| Deteccion de reformas | 100% de commits en articulos ref | Test sintetico |
| Falsos positivos | <5% | Review manual de 20 detecciones |
| Performance | <30s / proyecto | Benchmark |
| Diferenciador competitivo | Unico en el mercado | Busqueda competencia |

---

## Checklist Pre-Entrega

- [ ] /legal-drift command funcional
- [ ] Deteccion via git log probada
- [ ] Clasificacion por severidad via LLM
- [ ] Output con diff legible
- [ ] --update-audit-date con confirmacion
- [ ] Performance <30s en proyecto real
- [ ] Tests BATS >=80 score
