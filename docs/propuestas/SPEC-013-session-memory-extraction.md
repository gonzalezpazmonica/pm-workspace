# SPEC-013: Session Memory Extraction Hook

> Status: **DRAFT** · Fecha: 2026-03-22
> Origen: OpenViking — end-of-session automatic memory extraction
> Impacto: Auto-persistir decisiones y patrones sin intervencion manual

---

## Problema

Hoy la persistencia de conocimiento entre sesiones depende de:
1. El usuario ejecute `/memory-sync` manualmente (raro)
2. El hook `memory-auto-capture.sh` capture patrones de Edit/Write (limitado)
3. El usuario pida explicitamente "recuerda esto"

Resultado: ~30% de decisiones tomadas en sesion se pierden al cerrar.
OpenViking resuelve esto con extraccion automatica al fin de sesion.

---

## Diseno

### Hook async en Stop event

Nuevo hook `session-memory-extract.sh` registrado como async en Stop:

```json
{
  "hooks": {
    "Stop": [{
      "command": ".claude/hooks/session-memory-extract.sh",
      "async": true
    }]
  }
}
```

### Que extrae

El hook analiza el transcript de la sesion (disponible via Claude Code API)
y clasifica informacion en 4 categorias:

| Categoria | Destino | Ejemplo |
|-----------|---------|---------|
| Decisiones tecnicas | auto-memory `project` | "Elegimos GraphQL sobre REST" |
| Lecciones aprendidas | tasks/lessons.md | "El hook falla si no tiene stdin" |
| Feedback del usuario | auto-memory `feedback` | "No pongas emojis en informes" |
| Patrones de trabajo | auto-memory `user` | "Siempre ejecuta sprint-status primero" |

### Algoritmo de extraccion

```
1. Leer transcript de sesion (ultimo /compact hasta ahora)
2. Identificar:
   a. Correcciones del usuario ("no", "para", "eso no", "cambia")
   b. Decisiones explicitas ("vamos con X", "usaremos Y", "descartamos Z")
   c. Patrones repetidos (mismo comando 3+ veces = workflow)
   d. Nuevos datos de proyecto (nombres, URLs, configs mencionados)
3. Para cada hallazgo:
   a. Clasificar por nivel (N1-N4 segun context-placement-confirmation.md)
   b. Verificar que no existe ya en memoria (dedup por topic_key)
   c. Quality gate: min 50 chars, no trivial
4. Persistir en destino correcto
5. Log: cuantos items extraidos, cuantos descartados, cuantos duplicados
```

### Quality gate (inspirado en Fabrik-Codek)

Rechazar automaticamente:
- Contenido < 50 caracteres
- Saludos, despedidas, confirmaciones simples ("ok", "si", "vale")
- Info ya presente en auto-memory (dedup por similitud semantica)
- Datos efimeros ("estoy en la linea 47" — no util entre sesiones)

---

## Implementacion

### Fase 1 — Hook basico (1 sprint)

1. Crear `.claude/hooks/session-memory-extract.sh`
2. Registrar en settings.json como async Stop hook
3. Extraer solo correcciones del usuario (categoria mas valiosa)
4. Persistir como tipo `feedback` en auto-memory

### Fase 2 — Extraccion completa (1 sprint)

1. Anadir extraccion de decisiones, patrones y datos de proyecto
2. Clasificacion N1-N4 automatica
3. Quality gate con umbrales configurables
4. Metricas: items extraidos por sesion

### Fase 3 — Integracion con /compact (ver SPEC-016)

1. Ejecutar extraccion ANTES de compactar (no solo al cerrar)
2. Compartir extractor entre Stop hook y /compact

---

## Criterios de aceptacion

- [ ] Hook se ejecuta al cerrar sesion sin bloquear al usuario
- [ ] Extrae >= 2 items utiles por sesion de 30+ minutos
- [ ] Quality gate rechaza >= 80% de candidatos triviales
- [ ] Dedup funciona: no duplica memorias existentes
- [ ] Clasificacion N1-N4 correcta en >= 90% de los casos
- [ ] async: true — nunca bloquea la salida del usuario

---

## Ficheros afectados

- `.claude/hooks/session-memory-extract.sh` — nuevo
- `.claude/settings.json` — registrar hook en Stop
- `.claude/rules/domain/async-hooks-config.md` — documentar
- `docs/memory-system.md` — actualizar con nuevo mecanismo

---

## Riesgos

| Riesgo | Mitigacion |
|--------|-----------|
| Extrae ruido en vez de signal | Quality gate estricto + review mensual |
| Transcript no disponible | Graceful degradation: log warning, no fail |
| Memoria crece sin control | Max 5 items por sesion + pruning mensual |
| PII en memorias | Sanitizar con mismas reglas de pii-sanitization.md |
