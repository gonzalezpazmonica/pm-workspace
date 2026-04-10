# Spec: Verification Middleware — Verificacion automatica post-implementacion

**Task ID:**        SPEC-VERIFICATION-MIDDLEWARE
**PBI padre:**      SDD quality improvement (inspirado en getcompanion-ai/feynman)
**Sprint:**         2026-08
**Fecha creacion:** 2026-04-09
**Creado por:**     Savia (research: Feynman verification-as-middleware pattern)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     5h
**Estado:**         Pendiente
**Max turns:**      25
**Modelo:**         claude-sonnet-4-6

---

## 1. Contexto y Objetivo

En el pipeline SDD actual, la verificacion post-implementacion es OPCIONAL:
el dev-session-protocol sugiere coherence-validator en Fase 4, pero no lo
impone. En Feynman, el agente Verifier es MIDDLEWARE obligatorio: ningun output
llega al usuario sin pasar por verificacion de fuentes.

El problema real: en dev-sessions, ~15% de los slices pasan a Fase 5 (Review)
con desalineaciones spec-codigo que el code-reviewer humano detecta y devuelve.
Cada devolucion cuesta un ciclo completo de re-implementacion.

**Objetivo:** Crear un step obligatorio entre Fase 3 (Implement) y Fase 5
(Review) que ejecuta 3 verificaciones automaticas en paralelo. Si alguna falla,
el slice vuelve a Fase 3 automaticamente (max 2 reintentos). El code-reviewer
humano recibe solo slices pre-verificados.

**Criterios de Aceptacion:**
- [ ] Verificacion se ejecuta automaticamente tras cada Fase 3 (no es opt-in)
- [ ] 3 checks paralelos: trazabilidad, tests, consistencia
- [ ] Slices que fallan vuelven a Fase 3 con contexto del fallo (max 2 retries)
- [ ] Reduccion >=50% en devoluciones del code-reviewer humano
- [ ] Tiempo adicional <60s por slice (3 checks en paralelo)

---

## 2. Contrato Tecnico

### 2.1 Los 3 Checks del Middleware

```yaml
checks:
  traceability:
    agent: coherence-validator
    input: spec-slice + ficheros implementados
    question: Cada requisito del spec tiene implementacion correspondiente?
    output: { score: 0-100, gaps: [{req_id, status: covered|missing|partial}] }
    threshold: score >= 90

  tests:
    agent: test-engineer (o test-runner segun lenguaje)
    input: ficheros implementados + tests existentes
    question: Los tests cubren los criterios de aceptacion del spec-slice?
    output: { pass: bool, coverage_pct: number, failures: [string] }
    threshold: pass == true AND coverage_pct >= 80

  consistency:
    agent: coherence-validator
    input: ficheros implementados + patrones del proyecto
    question: El codigo sigue los patrones y convenciones del proyecto?
    output: { score: 0-100, issues: [{file, line, issue, severity}] }
    threshold: score >= 75 AND zero critical issues
```

### 2.2 Interfaz del Middleware

```bash
# scripts/verification-middleware.sh
# Usage: bash scripts/verification-middleware.sh \
#          --spec-slice PATH \
#          --files FILE1,FILE2,... \
#          --project PROJECT_NAME \
#          --session-id SESSION_ID \
#          --slice-number N
#
# Output: JSON to stdout + report to output/dev-sessions/{id}/verification/
# Exit:   0 = all pass, 1 = failures (with retry context), 2 = fatal error
```

### 2.3 Orquestacion

```
Fase 3 completa (agente developer termina)
  |
  v
verification-middleware.sh lanza 3 checks en paralelo (Task)
  |
  +-- traceability (coherence-validator) --> score
  +-- tests (test-engineer) -----------------> pass/fail
  +-- consistency (coherence-validator) -----> score
  |
  v
Todos completan (timeout: 60s)
  |
  v
Todos pasan umbrales?
  +-- SI --> Fase 5 (Review) con verification-report adjunto
  +-- NO --> Generar retry-context --> Fase 3 (re-implement)
             Max 2 retries. Tras 2 fallos --> escalar humano.
```

### 2.4 Retry Context

Cuando un check falla, el middleware genera un brief para el agente developer:

```markdown
## Verification Failed — Retry Context

### Traceability (FAILED: 72/100)
Gaps encontrados:
- REQ-03: Validar email unico — NO implementado
- REQ-07: Rate limiting en endpoint — implementacion parcial

### Tests (PASSED: 85%)
OK

### Consistency (FAILED: 60/100)
Issues criticos:
- UserController.cs:47 — SQL string concatenation (usar parametros)
- UserService.cs:23 — async void (debe ser async Task)

### Instruccion para re-implementacion
Corregir los gaps de trazabilidad y los issues criticos de consistencia.
NO tocar lo que ya pasa verificacion.
```

---

## 3. Reglas de Negocio

| ID | Regla | Error si viola |
|----|-------|----------------|
| VM-01 | El middleware es OBLIGATORIO. No hay flag para saltarselo | N/A — hardcoded en pipeline |
| VM-02 | Los 3 checks se ejecutan en PARALELO, no secuencialmente | Timeout si secuencial |
| VM-03 | Si un check excede 30s, se marca como TIMEOUT (no fallo) | Slice pasa con warning |
| VM-04 | Max 2 retries automaticos. 3er fallo escalar humano | Bucle infinito |
| VM-05 | El retry-context incluye SOLO los fallos, no repite lo correcto | Contexto inflado |
| VM-06 | El verification-report se adjunta al PR como evidencia | Auditabilidad |
| VM-07 | Checks de seguridad (SQL injection, secrets) en consistency son VETO | Seguridad |

---

## 4. Constraints

| Dimension | Requisito |
|-----------|-----------|
| Performance | <60s total (3 checks en paralelo, 30s timeout cada uno) |
| Tokens | Budget de verificacion: 8K tokens (3 agentes x ~2.5K cada uno) |
| Idempotencia | Re-ejecutar verificacion en mismo slice produce mismo resultado |
| Compatibilidad | Funciona con todos los language packs soportados |
| Fallback | Si verificacion esta rota (script falla), slice pasa con WARNING |

---

## 5. Test Scenarios

### Happy path — todos pasan

```
GIVEN   slice implementado correctamente segun spec
WHEN    verification-middleware.sh ejecuta
THEN    traceability >= 90, tests pass, consistency >= 75
AND     slice avanza a Fase 5
AND     verification-report guardado en output/dev-sessions/{id}/verification/
```

### Fallo en trazabilidad — retry exitoso

```
GIVEN   slice con 1 requisito no implementado
WHEN    verification-middleware.sh ejecuta (intento 1)
THEN    traceability = 72 (FAIL)
AND     retry-context generado con gap especifico
WHEN    developer re-implementa con retry-context
AND     verification-middleware.sh ejecuta (intento 2)
THEN    traceability = 95 (PASS)
AND     slice avanza a Fase 5
```

### Fallo persistente — escalacion

```
GIVEN   slice con problema fundamental de diseno
WHEN    verification falla 3 veces consecutivas
THEN    slice se marca como BLOCKED
AND     se genera informe de escalacion para humano
AND     pipeline NO continua automaticamente
```

### Veto de seguridad

```
GIVEN   slice con SQL injection en consistency check
WHEN    verification-middleware.sh ejecuta
THEN    consistency tiene issue critico de seguridad
AND     slice FALLA independientemente de otros scores
AND     retry-context marca el issue como VETO (no negociable)
```

---

## 6. Ficheros a Crear/Modificar

| Accion | Fichero | Que hacer |
|--------|---------|-----------|
| Crear | scripts/verification-middleware.sh | Script orquestador de 3 checks |
| Crear | tests/test-verification-middleware.sh | Suite BATS |
| Modificar | .claude/rules/domain/dev-session-protocol.md | Insertar Fase 4 como obligatoria |
| Modificar | .claude/rules/domain/handoff-templates.md | Anadir template Verification Report |
| Crear | .claude/rules/domain/verification-middleware-config.md | Umbrales configurables |

---

## 7. Configuracion por proyecto

Cada proyecto puede ajustar umbrales en su CLAUDE.md:

```yaml
verification_middleware:
  traceability_threshold: 90    # default
  consistency_threshold: 75     # default
  coverage_threshold: 80        # default
  max_retries: 2                # default
  timeout_per_check_seconds: 30 # default
  security_veto: true           # default, no desactivable
```

---

## 8. Metricas de exito

| Metrica | Objetivo | Medicion |
|---------|----------|----------|
| Devoluciones de code-reviewer | Reduccion >=50% | Contar re-reviews pre/post |
| First-pass review approval | >85% | Tracking en dev-sessions |
| Tiempo de verificacion | <60s por slice | Timer en script |
| Falsos positivos | <5% | Manual review primer mes |

---

## Checklist Pre-Entrega

- [ ] scripts/verification-middleware.sh orquesta 3 checks en paralelo
- [ ] Tests BATS pasan
- [ ] dev-session-protocol.md actualizado con Fase 4 obligatoria
- [ ] Retry-context se genera correctamente con gaps especificos
- [ ] Veto de seguridad funciona (SQL injection, secrets)
- [ ] Timeout no bloquea pipeline (warning, no fallo)
- [ ] Verificacion funciona con al menos 2 language packs (TS + C#)
