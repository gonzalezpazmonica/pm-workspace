# SPEC-047: Requirement Pushback Pass

> Status: **DRAFT** | Fecha: 2026-03-30
> Origen: garagon/nanostack research — `/think` pattern (mandatory challenge before planning)
> Impacto: Specs mejor fundamentadas, menos rework en implementacion

---

## Problema

`/spec-generate` acepta el PBI tal cual y produce una spec inmediatamente.
No hay un paso que desafie las suposiciones del requerimiento antes de
comprometerse con una solucion tecnica. Consecuencias:

- Specs que resuelven el problema equivocado (optimizan la pregunta literal,
  no el objetivo real — ver adaptive-output.md "Real Objective Check")
- Alcance inflado por requisitos no cuestionados
- Alternativas mas simples que nunca se consideran
- Rework en implementacion cuando el developer descubre ambiguedades

Nanostack resuelve esto con `/think`: un paso obligatorio que reframea el
problema ANTES de planificar. pm-workspace carece de este mecanismo.

---

## Arquitectura

### Pushback Pass — Paso 0 de /spec-generate

Insertar una fase de cuestionamiento entre la recepcion del PBI y la
generacion de la spec. Esta fase produce un `pushback-report.md` que
el PM revisa antes de que la spec se escriba.

### Flujo modificado

```
PBI recibido
  |
  v
[PUSHBACK PASS] — reflection-validator (subagent)
  |
  v
pushback-report.md generado
  |
  v
PM revisa: acepta / ajusta / descarta
  |
  v
/spec-generate procede con el PBI refinado
```

### Pushback Report — 5 secciones obligatorias

1. **Reframing**: "El PBI dice X, pero el objetivo real parece ser Y"
2. **Assumptions exposed**: lista de suposiciones implicitas del PBI
3. **Simpler alternatives**: al menos 1 alternativa con menor scope
4. **Missing context**: informacion que falta para especificar bien
5. **Recommendation**: proceder / simplificar / dividir / rechazar

### Agente responsable

`reflection-validator` (Opus) — ya existe, especializado en meta-cognicion.
Recibe: PBI completo + reglas de negocio del proyecto + contexto de sprint.
Devuelve: pushback-report.md (max 40 lineas).

---

## Integracion

### Con /spec-generate

El comando `/spec-generate` incorpora un Paso 0 antes de su flujo actual:

1. **Paso 0 — Pushback**: invocar reflection-validator como subagent
2. Mostrar pushback-report al PM en conversacion (es corto, <40 lineas)
3. Esperar confirmacion: "Proceder" / "Ajustar PBI" / "Descartar"
4. Si proceder: continuar con flujo actual de spec-generate
5. Si ajustar: PM modifica, loop back a Paso 0
6. Si descartar: salir con mensaje claro

### Con consensus-protocol

Si el pushback-report tiene `recommendation: rechazar`, elevar
automaticamente a consensus-validation antes de proceder.

### Con dev-session-protocol

El pushback-report se incluye en `output/dev-sessions/{id}/` como
contexto para el developer. Reduce preguntas durante implementacion.

### Flag de bypass

`/spec-generate --skip-pushback` para PBIs triviales o ya discutidos.
El bypass se registra en el log para auditoria.

---

## Restricciones

- El pushback pass NO bloquea indefinidamente — max 1 iteracion automatica
- El PM siempre tiene la ultima palabra (Rule #5: el humano decide)
- El report NO se publica en N1 (puede contener contexto de proyecto)
- Budget de contexto: max 5K tokens para el pushback pass completo
- El agente NO modifica el PBI — solo propone, el PM ejecuta

---

## Implementacion por fases

### Fase 1 — Comportamiento (zero code)
- Savia ejecuta el pushback mentalmente antes de /spec-generate
- Muestra las 5 secciones en conversacion
- Sin fichero persistido, sin subagent dedicado

### Fase 2 — Subagent formal (~2h)
- Crear prompt especializado para reflection-validator pushback mode
- Persistir pushback-report.md en output/
- Integrar flag --skip-pushback en spec-generate.md
- Test: verificar que specs generadas tras pushback tienen menos rework

### Fase 3 — Metricas
- Tracking: % de PBIs donde pushback cambio el approach
- Tracking: rework rate pre/post pushback (slices que requieren rewrite)
- Dashboard en /kpi-dashboard

---

## Ficheros afectados

| Fichero | Accion |
|---------|--------|
| `.claude/commands/spec-generate.md` | Modificar — anadir Paso 0 |
| `.claude/agents/reflection-validator.md` | Modificar — anadir pushback mode |
| `output/pushback/` | Nuevo directorio para reports |

---

## Metricas de exito

- Rework rate en dev-sessions: reduccion >20%
- PBIs descartados o simplificados antes de spec: >10% del total
- Tiempo medio de pushback pass: <2 min
