# Spec: Advisor Strategy — Executor+Advisor para pipeline SDD

**Task ID:**        SPEC-ADVISOR-STRATEGY
**PBI padre:**      SDD cost optimization (Anthropic Advisor Strategy)
**Sprint:**         2026-08
**Fecha creacion:** 2026-04-09
**Creado por:**     Savia (research: claude.com/blog/the-advisor-strategy)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     5h
**Estado:**         Pendiente
**Max turns:**      25
**Modelo:**         claude-sonnet-4-6

---

## 1. Contexto y Objetivo

En el pipeline SDD actual, los agentes developer corren en Sonnet y los agentes
de analisis (architect, business-analyst, reflection-validator) en Opus. Cuando
un developer Sonnet encuentra una decision arquitectonica compleja, no tiene
forma de consultar a Opus — produce su mejor intento y espera al code review.

Anthropic ha lanzado el Advisor Strategy: un tool type `advisor_20260301` que
permite a un executor (Sonnet/Haiku) consultar a un advisor (Opus) dentro del
mismo API request, sin roundtrips adicionales. El advisor nunca ejecuta tools
ni produce output final — solo guia al executor.

Metricas publicadas:
- Sonnet + Opus advisor: +2.7pp en SWE-bench Multilingual, -11.9% coste/tarea
- Haiku + Opus advisor: 41.2% en BrowseComp (vs 19.7% solo), -85% coste vs Sonnet

**Objetivo:** Integrar el Advisor Strategy en pm-workspace para que los agentes
developer (Sonnet) puedan consultar a Opus cuando encuentran decisiones complejas.
Implementar como configuracion en el pipeline SDD, no como cambio en cada agente.

**Criterios de Aceptacion:**
- [ ] Script `scripts/advisor-config.sh` genera la configuracion advisor para cualquier agente
- [ ] Integracion con dev-session-protocol.md: agents en Fase 3 usan advisor
- [ ] max_uses configurable por proyecto (default: 3)
- [ ] Metricas de uso de advisor capturadas en agent-trace
- [ ] Degradacion limpia si la API no soporta advisor (fallback a modelo unico)
- [ ] Test BATS con >=80 score

---

## 2. Contrato Tecnico

### 2.1 Configuracion del Advisor

```bash
# scripts/advisor-config.sh
# Usage: bash scripts/advisor-config.sh [options]
#
# Options:
#   --executor MODEL     Executor model. Default: claude-sonnet-4-6
#   --advisor MODEL      Advisor model. Default: claude-opus-4-6
#   --max-uses N         Max advisor calls per request. Default: 3
#   --enabled BOOL       Enable/disable advisor. Default: true
#   --output json|yaml   Output format. Default: json
#
# Output: advisor tool configuration block (JSON or YAML)
# Exit:   0 success, 1 error
```

### 2.2 Output JSON (para API calls)

```json
{
  "type": "advisor_20260301",
  "name": "advisor",
  "model": "claude-opus-4-6",
  "max_uses": 3
}
```

### 2.3 Configuracion por proyecto

En `CLAUDE.md` o `pm-config.local.md` del proyecto:

```
# ── Advisor Strategy ──────────────────────────────────────────────────────
ADVISOR_ENABLED             = true
ADVISOR_MODEL               = "claude-opus-4-6"
ADVISOR_MAX_USES            = 3
ADVISOR_EXECUTOR_DEFAULT    = "claude-sonnet-4-6"
ADVISOR_EXECUTOR_LIGHT      = "claude-haiku-4-5-20251001"
```

### 2.4 Matriz de aplicacion por agente

No todos los agentes necesitan advisor. La decision depende de la complejidad
de las decisiones que toma el agente:

| Agente | Executor | Advisor | max_uses | Justificacion |
|--------|----------|---------|----------|---------------|
| dotnet-developer | Sonnet | Opus | 3 | Decisiones de arquitectura en implementacion |
| typescript-developer | Sonnet | Opus | 3 | Idem |
| frontend-developer | Sonnet | Opus | 2 | Menos decisiones arquitectonicas |
| java-developer | Sonnet | Opus | 3 | Idem dotnet |
| python-developer | Sonnet | Opus | 3 | Idem |
| go-developer | Sonnet | Opus | 3 | Idem |
| rust-developer | Sonnet | Opus | 3 | Idem |
| test-engineer | Sonnet | Opus | 2 | Consulta en estrategia de test |
| dev-orchestrator | Sonnet | Opus | 3 | Slicing complejo |
| commit-guardian | Sonnet | — | 0 | Checks deterministas, no necesita |
| tech-writer | Haiku | — | 0 | Escritura simple |
| azure-devops-operator | Haiku | — | 0 | Queries simples |
| architect | Opus | — | 0 | YA es Opus |
| code-reviewer | Opus | — | 0 | YA es Opus |
| security-guardian | Opus | — | 0 | YA es Opus |

### 2.5 Integracion con agent frontmatter

Anadir campo opcional `advisor:` al frontmatter de los agentes:

```yaml
---
name: dotnet-developer
model: sonnet
advisor: opus
advisor_max_uses: 3
---
```

Si `advisor` no esta definido, el agente corre sin advisor (comportamiento actual).

### 2.6 Logica de inyeccion

Cuando dev-session invoca un agente via Task:

```
1. Leer frontmatter del agente
2. Si advisor definido Y ADVISOR_ENABLED=true:
   a. Generar bloque advisor con advisor-config.sh
   b. Inyectar en la lista de tools del API call
3. Si advisor NO definido o ADVISOR_ENABLED=false:
   a. API call normal (sin advisor tool)
```

---

## 3. Reglas de Negocio

| ID | Regla | Error si viola |
|----|-------|----------------|
| ADV-01 | Advisor NUNCA ejecuta tools ni produce output final | Rol incorrecto |
| ADV-02 | max_uses es hard cap — el executor no puede excederlo | API error |
| ADV-03 | Si la API devuelve error por advisor no soportado, fallback silencioso | Pipeline roto |
| ADV-04 | Agentes que YA corren en Opus (architect, code-reviewer) NO usan advisor | Desperdicio |
| ADV-05 | Cada consulta al advisor se registra en agent-trace | Observabilidad |
| ADV-06 | El coste del advisor se separa en las metricas (tokens executor vs advisor) | Transparencia |

---

## 4. Constraints

| Dimension | Requisito |
|-----------|-----------|
| Dependencias | Zero dependencias externas (solo bash + jq) |
| Compatibilidad | bash 4.0+, macOS + Linux |
| API | Messages API con tool type `advisor_20260301` |
| Fallback | Si advisor no disponible, funciona sin el (degradacion limpia) |
| Observabilidad | Uso de advisor capturado en agent-trace-log.sh |

---

## 5. Test Scenarios

### Happy path — advisor config generada

```
GIVEN   ADVISOR_ENABLED=true, executor=sonnet, advisor=opus, max_uses=3
WHEN    bash scripts/advisor-config.sh --output json
THEN    output es JSON valido con type=advisor_20260301
AND     model=claude-opus-4-6
AND     max_uses=3
```

### Advisor deshabilitado

```
GIVEN   ADVISOR_ENABLED=false
WHEN    bash scripts/advisor-config.sh
THEN    exit code 1
AND     stderr contiene "advisor disabled"
```

### Agente sin advisor en frontmatter

```
GIVEN   agente tech-writer sin campo advisor en frontmatter
WHEN    dev-session invoca tech-writer
THEN    API call sin advisor tool (comportamiento actual)
```

### Agente con advisor

```
GIVEN   agente dotnet-developer con advisor: opus, advisor_max_uses: 3
AND     ADVISOR_ENABLED=true
WHEN    dev-session invoca dotnet-developer
THEN    API call incluye advisor tool con max_uses=3
```

### Fallback por API no soportada

```
GIVEN   advisor configurado
AND     API devuelve error "unknown tool type advisor_20260301"
WHEN    dev-session detecta el error
THEN    reintenta SIN advisor (fallback silencioso)
AND     log warning en agent-trace
```

### Metricas de uso

```
GIVEN   agente dotnet-developer usa advisor 2 veces en una sesion
WHEN    sesion completa
THEN    agent-trace-log contiene advisor_calls=2
AND     advisor_tokens separados de executor_tokens
```

---

## 6. Ficheros a Crear/Modificar

| Accion | Fichero | Que hacer |
|--------|---------|-----------|
| Crear | scripts/advisor-config.sh | Generador de configuracion advisor |
| Crear | tests/test-advisor-config.sh | Suite BATS |
| Modificar | .claude/rules/domain/agents-catalog.md | Documentar advisor por agente |
| Modificar | .claude/rules/domain/dev-session-protocol.md | Fase 3: inyectar advisor |
| Modificar | .claude/rules/domain/pm-config.md | Constantes ADVISOR_* |

---

## 7. Metricas de exito

| Metrica | Objetivo | Medicion |
|---------|----------|----------|
| Coste por dev-session | Reduccion >=10% | Comparar tokens Opus vs Sonnet+advisor |
| Calidad de implementacion | Sin degradacion | First-pass review approval rate |
| Advisor utilization | 1-3 consultas por slice | agent-trace stats |
| Fallback rate | <5% | Contar fallbacks en agent-trace |

---

## 8. Context Safety — Prevencion de bloqueos por herencia de contexto

**Warning critico (2026-04-11):** el advisor hereda el contexto del executor.
Sin controles, un executor Sonnet con 150K tokens consumidos consultando al
advisor Opus puede:

1. **Bloquear la consulta** — Opus rechaza si input > su window efectiva
2. **Explotar el coste** — 150K tokens × max_uses=3 = 450K tokens de consulta
3. **Degradar la calidad** — advisor razonando sobre basura acumulada, no problema
4. **Fallar silenciosamente** — timeout o truncation sin alerta al executor

### 8.1 Reglas de proteccion (obligatorias)

| ID | Regla | Accion si viola |
|----|-------|-----------------|
| CTX-01 | Executor context al consultar advisor <= 60% de su window efectiva | Compactar antes de consultar |
| CTX-02 | Advisor consultation payload <= 40K tokens | Resumir o abortar consulta |
| CTX-03 | Si contexto executor > 80% window, advisor se deshabilita hasta compactacion | Fallback a single-model |
| CTX-04 | Cada consulta advisor tiene timeout independiente (default 30s) | Abortar, no bloquear executor |
| CTX-05 | Si advisor falla 2 veces consecutivas, se deshabilita el resto del turno | Prevenir cascada de fallos |
| CTX-06 | Payload advisor NO incluye tool_results de tools irrelevantes al dilema | Filtro pre-consulta |

### 8.2 Pipeline de consulta segura

```
Executor detecta decision dificil
  |
  v
[pre-check] contexto executor < 60%?
  | NO -> compactar o fallback sin advisor
  | SI
  v
[payload-build] construir dilema + contexto minimo relevante
  (NO incluir: tool_results antiguos, turnos resueltos, ruido)
  |
  v
[budget-check] payload <= 40K tokens?
  | NO -> resumir via executor o abortar
  | SI
  v
[consulta] advisor con timeout 30s
  | FAIL -> incrementar fail_count, fallback a executor-only
  | OK   -> inyectar guidance en executor
```

### 8.3 Budget de consulta por perfil de agente

| Agente | Max payload | Max consultas | Timeout | Razon |
|--------|-------------|---------------|---------|-------|
| dotnet-developer | 30K | 3 | 30s | Decisiones arquitectonicas focalizadas |
| typescript-developer | 30K | 3 | 30s | Idem |
| frontend-developer | 20K | 2 | 25s | Decisiones mas locales |
| test-engineer | 20K | 2 | 25s | Estrategia de test acotada |
| dev-orchestrator | 40K | 3 | 45s | Slicing requiere mas contexto |

### 8.4 Deteccion de bloqueo

El hook `agent-trace-log.sh` debe registrar por consulta:
- `advisor_payload_tokens` — input enviado
- `advisor_latency_ms` — tiempo de respuesta
- `advisor_abort_reason` — uno de {size_exceeded, timeout, api_error, context_pressure}

Si >10% de consultas en una sesion son abort, emitir WARNING al final de la sesion.

### 8.5 Test obligatorios (anadir a seccion 5)

- **Payload size gate**: payload 45K tokens -> consulta abortada, executor continua
- **Context pressure gate**: executor al 85% window -> advisor deshabilitado, log warning
- **Timeout gate**: advisor no responde en 30s -> abort, fallback silencioso, fail_count+=1
- **Cascade prevention**: 2 fallos consecutivos -> advisor deshabilitado resto del turno
- **Resume on compact**: tras /compact bajando a <60%, advisor se reactiva

### 8.6 Fallback jerarquia

Si el advisor no puede consultarse de forma segura, el executor:

1. Intenta resolver con single-model (comportamiento pre-advisor)
2. Si la decision es critica Y el executor no esta seguro, ESCALA a humano via handoff
3. NUNCA produce output especulativo marcandolo como "advised" sin advisor real

### 8.7 Metricas de exito extendidas

| Metrica | Objetivo | Alerta si |
|---------|----------|-----------|
| advisor_abort_rate | <5% | >10% -> revisar limits |
| avg_payload_tokens | <20K | >35K -> payload bloat |
| context_pressure_fallbacks | <2 por sesion | >5 -> bug en executor |
| executor_blocked_by_advisor | 0 | cualquiera -> bug critico |

---

## Checklist Pre-Entrega

- [ ] scripts/advisor-config.sh genera JSON valido
- [ ] Tests BATS pasan (>=80 score)
- [ ] Fallback funciona cuando API no soporta advisor
- [ ] agent-trace captura advisor_calls y advisor_tokens
- [ ] Documentacion en agents-catalog.md actualizada
- [ ] pm-config.md tiene constantes ADVISOR_*
- [ ] dev-session-protocol.md referencia advisor en Fase 3
- [ ] **Section 8 implementada**: payload gates, timeout, cascade prevention
- [ ] **Test de context pressure**: executor 85% -> advisor deshabilitado
- [ ] **Test de payload oversize**: 45K -> abort limpio
- [ ] **Zero bloqueos** en 10 sesiones de prueba con advisor activo
