# Test Runner: Coverage Scripts y Comandos por Lenguaje

> Referencia extraída de `test-runner.md`. Contiene scripts de ejecución, cálculo de cobertura y per-language test commands.

## Instalación de herramientas

```bash
# ReportGenerator para .NET
dotnet tool install -g dotnet-reportgenerator-globaltool 2>/dev/null || true
```

## Paso 3 — Ejecutar todos los tests

### .NET (C#)
```bash
# Ejecutar TODOS los tests (unitarios + integración)
dotnet test [path-al-sln] --configuration Release --verbosity normal 2>&1
```

Interpretar resultado:
- ✅ Todos los tests pasan → continuar con Paso 4
- 🔴 Tests fallidos → ir a Paso 3b (delegación a `dotnet-developer`)

### Paso 3b — Tests fallidos: delegar corrección

Usar herramienta `Task` para delegar a `dotnet-developer`:
- Descripción: Corrección de tests fallidos tras commit
- Incluir: Lista completa de tests fallidos + mensajes de error
- Ficheros: Lista de ficheros del commit
- Indicación: Corregir código o tests según corresponda
- Verificación: Ejecutar `dotnet test` antes de terminar

Después de corrección:
1. Re-ejecutar TODOS los tests (no solo los fallidos)
2. Si pasan → continuar Paso 4
3. Si fallan tras 2 intentos → escalar al humano

## Paso 4 — Verificar cobertura de código

### .NET (.NET 8+ con XPlat Code Coverage)
```bash
# Instalar reportgenerator si no existe
dotnet tool install -g dotnet-reportgenerator-globaltool 2>/dev/null || true

# Ejecutar tests con recopilación de cobertura
dotnet test [path-al-sln] \
  --configuration Release \
  --collect "XPlat Code Coverage" \
  --results-directory ./output/test-results 2>&1

# Generar informe de cobertura
reportgenerator \
  -reports:"./output/test-results/**/coverage.cobertura.xml" \
  -targetdir:"./output/coverage-report" \
  -reporttypes:"TextSummary" 2>&1

# Leer el resumen
cat ./output/coverage-report/Summary.txt
```

Interpretar resultado:
- ✅ Cobertura ≥ TEST_COVERAGE_MIN_PERCENT (80%) → informe de éxito
- 🔴 Cobertura < 80% → ir a Paso 5 (orquestación de mejora)

## Paso 5 — Cobertura insuficiente: orquestar mejora

### 5a — Análisis de cobertura (agente `architect`)

Delegar con:
- Informe de cobertura (resumen por ensamblado/namespace)
- Umbral requerido: TEST_COVERAGE_MIN_PERCENT%
- Priorizar: código negocio > infraestructura, métodos públicos sin cobertura, ramas no cubiertas

### 5b — Análisis de casos de test (agente `business-analyst`)

Delegar con:
- Output del architect (áreas sin cobertura)
- Reglas de negocio: `projects/[proyecto]/reglas-negocio.md`
- Formato requerido: Given/When/Then con datos concretos

### 5c — Implementación de tests (agente `dotnet-developer`)

Delegar con:
- Análisis del architect + casos del business-analyst
- Instrucción: xUnit + FluentAssertions
- Traits: `[Trait("Category", "Unit")]` para unitarios
- Verificación: `dotnet test --filter "Category=Unit"` y cobertura

### 5d — Verificación final

1. Re-ejecutar Paso 3 (todos los tests deben pasar)
2. Re-ejecutar Paso 4 (cobertura debe superar umbral)
3. Si sigue por debajo tras 1ª iteración → repetir Paso 5 (máx 2 ciclos)
4. Si tras 2 ciclos no alcanza → escalar al humano

## Tabla de delegación

| Problema | Agente a llamar | Información a pasar |
|---|---|---|
| Tests unitarios fallan | `dotnet-developer` | Tests fallidos + error completo + ficheros commit |
| Tests de integración fallan | `dotnet-developer` | Tests fallidos + contexto infraestructura |
| Cobertura insuficiente (análisis) | `architect` | Informe cobertura + umbral + áreas con gaps |
| Cobertura insuficiente (casos) | `business-analyst` | Análisis architect + reglas negocio |
| Cobertura insuficiente (código) | `dotnet-developer` | Análisis architect + casos business-analyst |
| Tests fallan 2+ veces | ❌ Humano | Informe completo ambos intentos |
| Cobertura no alcanzada 2 ciclos | ❌ Humano | Informe cobertura + tests creados + gaps |

## Formato del informe de ejecución

```
═════════════════════════════════════════════════════════════
  TEST RUNNER — [proyecto] — [rama]
═════════════════════════════════════════════════════════════

  Proyecto .......................... [nombre]
  Solución .......................... [path al .sln]
  Commit ............................ [hash corto] — [mensaje]

  ── Tests ──────────────────────────────────────────────
  Tests unitarios ................... ✅ XX/XX passed
  Tests integración ................. ✅ XX/XX passed / ⏭️ no aplica
  Total ............................. ✅ XX tests passed, 0 failed

  ── Cobertura ──────────────────────────────────────────
  Cobertura global .................. XX.X%
  Umbral mínimo ..................... 80%
  Estado ............................ ✅ CUMPLE / 🔴 NO CUMPLE (faltan X.X%)

  ── Acciones tomadas ───────────────────────────────────
  [Lista de delegaciones y resultados]

  RESULTADO: ✅ APROBADO / 🔴 ESCALADO AL HUMANO
═════════════════════════════════════════════════════════════
```

## Restricciones absolutas

- **NUNCA** ignorar tests fallidos — todos deben pasar
- **NUNCA** falsificar cobertura — siempre ejecutar con `--collect "XPlat Code Coverage"`
- **NUNCA** reducir umbral de cobertura — solo configurable por humano en `pm-config.md`
- **NUNCA** borrar tests existentes para mejorar métricas
- **Máximo 2 ciclos** de corrección automática antes de escalar
- Si proyecto no tiene infraestructura de tests → proponer crearla
