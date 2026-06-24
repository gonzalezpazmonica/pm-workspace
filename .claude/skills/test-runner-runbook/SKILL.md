---
name: test-runner-runbook
description: "Protocolo de ejecución paso a paso, tabla de delegación, formato de informe y decision trees del agente test-runner. Cargar cuando se necesita el detalle completo del flujo de tests y cobertura."
summary: |
  Runbook auxiliar del agente test-runner.
  Contiene: protocolo de 5 pasos completo, tabla de delegación,
  formato de informe ASCII, decision trees y métricas.
maturity: stable
context: fork
context_cost: low
---

# Test Runner — Runbook Completo

## Protocolo de ejecución (5 pasos)

### Paso 1 — Identificar proyecto afectado

```bash
git diff --name-only HEAD~1 HEAD | grep "^projects/"
```

### Paso 2 — Localizar solución .NET

```bash
find projects/[proyecto]/ -name "*.sln" -o -name "*.slnx" | head -5
```

### Paso 3 — Ejecutar todos los tests

```bash
dotnet test [path-al-sln] --configuration Release --verbosity normal 2>&1
```
- ✅ Todos pasan → continuar Paso 4
- 🔴 Fallan → Paso 3b (delegar a dotnet-developer)

### Paso 3b — Tests fallidos: delegar corrección

- Usar `Task` para delegar a `dotnet-developer`
- Incluir: tests fallidos + error completo + ficheros commit
- Re-ejecutar todos los tests (máx 2 intentos)
- Si siguen fallando → escalar humano

### Paso 4 — Verificar cobertura

Ver detalles de scripts en `docs/rules/domain/coverage-scripts.md`.

```bash
dotnet test [sln] --configuration Release \
  --collect "XPlat Code Coverage" \
  --results-directory ./output/test-results
reportgenerator \
  -reports:"./output/test-results/**/coverage.cobertura.xml" \
  -targetdir:"./output/coverage-report" \
  -reporttypes:"TextSummary"
cat ./output/coverage-report/Summary.txt
```
- ✅ Cobertura ≥ 80% → éxito
- 🔴 Cobertura < 80% → Paso 5

### Paso 5 — Cobertura insuficiente: orquestar mejora

5a. **architect** → análisis de gaps (qué clases/métodos necesitan tests)
5b. **business-analyst** → definición de casos (Given/When/Then)
5c. **dotnet-developer** → implementación de tests (xUnit + FluentAssertions)
5d. **Verificación final** → re-ejecutar todo (máx 2 ciclos antes de escalar)

## Tabla de delegación

| Problema | Agente | Información a pasar |
|---|---|---|
| Tests fallan | `dotnet-developer` | Error completo + ficheros commit |
| Tests fallan 2+ veces | ❌ Humano | Informe completo de ambos intentos |
| Cobertura análisis | `architect` | Cobertura actual + umbral + gaps |
| Cobertura casos | `business-analyst` | Análisis architect + reglas negocio |
| Cobertura código | `dotnet-developer` | Análisis + casos test |
| No alcanzo 80% en 2 ciclos | ❌ Humano | Informe + gaps restantes |

## Formato del informe

```
═════════════════════════════════════════════════════════════
  TEST RUNNER — [proyecto] — [rama]
═════════════════════════════════════════════════════════════

  Proyecto .......................... [nombre]
  Solución .......................... [path al .sln]
  Commit ............................ [hash] — [mensaje]

  ── Tests ──────────────────────────────────────────────────
  Tests unitarios ................... ✅ XX/XX passed
  Tests integración ................. ✅ XX/XX / ⏭️ no aplica
  Total ............................. ✅ XX tests passed, 0 failed

  ── Cobertura ──────────────────────────────────────────────
  Cobertura global .................. XX.X%
  Umbral mínimo ..................... 80%
  Estado ............................ ✅ CUMPLE / 🔴 NO CUMPLE

  ── Acciones tomadas ───────────────────────────────────────
  [Lista delegaciones y resultados]

  RESULTADO: ✅ APROBADO / 🔴 ESCALADO AL HUMANO
═════════════════════════════════════════════════════════════
```

## Decision Trees

- Tests fallan → delegar fix a `dotnet-developer` con contexto completo, máx 2 reintentos antes de escalar a humano.
- Cobertura bajo umbral → orquestar `architect` (análisis de gaps) + `business-analyst` (casos) + `dotnet-developer` (implementación).
- Proyecto sin infraestructura de tests → reportar a humano y proponer crearla, nunca omitir verificación de cobertura.
- Agente delegado falla dos veces → parar y escalar a humano con logs completos de ambos intentos.
- Spec ambigua sobre comportamiento esperado de tests → marcar y solicitar aclaración antes de aceptar resultados de cobertura.

## Métricas de éxito

- Todos los tests pasan antes de reportar éxito
- Cobertura ≥ TEST_COVERAGE_MIN_PERCENT (80%) en cada ejecución
- Máx 2 ciclos de corrección antes de escalar — sin bucles indefinidos
- Cada informe de fallo incluye nombre exacto del test, mensaje de error y ficheros afectados
