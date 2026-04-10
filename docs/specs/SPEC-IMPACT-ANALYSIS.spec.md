# Spec: Impact Analysis Pre-Slice — Grafo de impacto antes de implementar

**Task ID:**        SPEC-IMPACT-ANALYSIS
**PBI padre:**      Dev-session quality improvement (inspirado en ix-infrastructure/Ix)
**Sprint:**         2026-08
**Fecha creacion:** 2026-04-09
**Creado por:**     Savia (research: Ix Map-Explain-Trace-Impact pattern)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     5h
**Estado:**         Pendiente
**Max turns:**      25
**Modelo:**         claude-sonnet-4-6

---

## 1. Contexto y Objetivo

En el dev-session actual, Fase 1 (Spec Load and Slice) divide el spec en slices
ejecutables, pero NO analiza el impacto de cada slice en el resto del codebase.
El desarrollador descubre dependencias rotas en Fase 4 (Validate), cuando ya ha
invertido tokens y tiempo en la implementacion.

Ix demuestra que un paso de Impact Analysis ANTES de implementar reduce
sorpresas drasticamente: al visualizar que ficheros se ven afectados, que tests
podrian romperse y que dependencias existen, el agente puede planificar mejor.

**Objetivo:** Crear scripts/impact-analysis.sh que, dado un slice (lista de
ficheros a modificar), analiza el codebase y produce un informe de impacto:
ficheros dependientes, tests afectados, y riesgo estimado. Este informe se
inyecta en Fase 2 (Context Prime) para que el agente developer tenga visibilidad
completa ANTES de escribir una linea de codigo.

**Criterios de Aceptacion:**
- [ ] Analisis de impacto se ejecuta automaticamente en Fase 1 para cada slice
- [ ] Detecta >=80% de ficheros afectados por cambios en los ficheros del slice
- [ ] Identifica tests que cubren los ficheros modificados
- [ ] Tiempo de analisis <5s por slice
- [ ] Output integrado en Fase 2 como contexto adicional para el agente

---

## 2. Contrato Tecnico

### 2.1 Interfaz / Firma

```bash
# scripts/impact-analysis.sh
# Usage: bash scripts/impact-analysis.sh [options] <file1> [file2] [...]
#
# Options:
#   --project DIR          Project root directory. Default: current dir
#   --depth N              Max dependency depth to trace. Default: 2
#   --include-tests        Include test files in impact graph. Default: true
#   --format compact|full  Output detail level. Default: compact
#   --output FILE          Write report to file. Default: stdout
#
# Input:  paths of files that WILL BE modified (the slice targets)
# Output: impact report (structured markdown)
# Exit:   0 success, 1 error
```

### 2.2 Formato de salida

```markdown
# Impact Analysis — Slice {N}: {description}

## Ficheros modificados (directos)
- src/services/UserService.ts — target del slice
- src/controllers/UserController.ts — target del slice

## Ficheros impactados (dependientes)
| Fichero | Relacion | Riesgo |
|---------|----------|--------|
| src/services/AuthService.ts | importa UserService | MEDIO |
| src/middleware/auth.ts | importa AuthService (transitivo) | BAJO |
| src/routes/index.ts | registra UserController | BAJO |

## Tests afectados
| Test | Cubre | Estado esperado |
|------|-------|-----------------|
| tests/user.service.spec.ts | UserService directamente | ROJO si firma cambia |
| tests/auth.service.spec.ts | AuthService (transitivo) | AMARILLO si contrato cambia |
| tests/e2e/user.e2e.spec.ts | Endpoint completo | ROJO si comportamiento cambia |

## Riesgo del slice
- Score: 45/100 (MEDIO)
- Razon: 2 dependientes directos, 3 tests afectados, 1 transitivo
- Recomendacion: Ejecutar tests de UserService + AuthService tras implementar

## Dependencias externas
- Ninguna API externa afectada
```

### 2.3 Algoritmo de deteccion de impacto

El analisis se basa en grep de imports/requires/use, NO en AST:

```
Para cada fichero target del slice:
  1. Extraer nombre del modulo/clase exportado
  2. Grep recursivo en el proyecto: quien importa este modulo?
     --> Estos son dependientes directos (profundidad 1)
  3. Para cada dependiente directo (si depth >= 2):
     --> Repetir paso 2 (dependientes transitivos)
  4. Grep en directorio de tests: que tests importan el target o dependientes?
     --> Estos son tests afectados
```

Patrones de import por lenguaje:

| Lenguaje | Patron de import |
|----------|-----------------|
| TypeScript | import .* from .*{module} |
| C# | using .*{namespace} + project references |
| Python | from {module} import / import {module} |
| Go | {module_path} in import block |
| Rust | use {crate}::{module} |
| Java | import {package}.{class} |

### 2.4 Scoring de riesgo

```
risk_score =
  (dependientes_directos x 15) +
  (dependientes_transitivos x 5) +
  (tests_afectados x 10) +
  (ficheros_publicos_API x 20)   # controllers, handlers, endpoints

0-25:   BAJO   — cambio aislado, pocos afectados
26-50:  MEDIO  — cambio con dependientes, tests necesarios
51-75:  ALTO   — cambio con impacto amplio, review cuidadoso
76-100: CRITICO — cambio transversal, considerar dividir slice
```

---

## 3. Reglas de Negocio

| ID | Regla | Error si viola |
|----|-------|----------------|
| IA-01 | Analisis se ejecuta automaticamente en Fase 1 para CADA slice | Pipeline roto |
| IA-02 | Si risk_score >= 76, sugerir dividir el slice en sub-slices | Warning en output |
| IA-03 | Tests afectados se listan SIEMPRE, incluso si el score es bajo | Completitud |
| IA-04 | Profundidad maxima 3 (depth <= 3) para evitar explosion combinatoria | Performance |
| IA-05 | Ficheros en node_modules/, vendor/, .git/ se excluyen siempre | Ruido |
| IA-06 | El informe se cachea por hash de los ficheros target | Performance |

---

## 4. Constraints

| Dimension | Requisito |
|-----------|-----------|
| Performance | <5s por slice (depth=2), <15s (depth=3) |
| Dependencias | Zero dependencias externas (solo bash, grep, awk) |
| Compatibilidad | bash 4.0+, macOS + Linux |
| Cache | Reports en output/dev-sessions/{id}/impact/slice-{n}.md |
| Precision | >=80% de dependientes reales detectados |

---

## 5. Test Scenarios

### Happy path — slice con dependientes

```
GIVEN   slice que modifica UserService.ts (exporta createUser)
AND     AuthService.ts importa UserService
AND     tests/user.service.spec.ts importa UserService
WHEN    bash scripts/impact-analysis.sh src/services/UserService.ts
THEN    output lista AuthService.ts como dependiente directo
AND     output lista user.service.spec.ts como test afectado
AND     risk_score entre 25-50 (MEDIO)
AND     duracion <5s
```

### Slice aislado — sin dependientes

```
GIVEN   slice que modifica utils/formatDate.ts (no importado por nadie)
WHEN    bash scripts/impact-analysis.sh src/utils/formatDate.ts
THEN    dependientes directos = 0
AND     risk_score < 25 (BAJO)
```

### Slice critico — muchos dependientes

```
GIVEN   slice que modifica core/Database.ts (importado por 15 servicios)
WHEN    bash scripts/impact-analysis.sh src/core/Database.ts
THEN    risk_score >= 76 (CRITICO)
AND     output incluye recomendacion de dividir slice
```

### Cache hit

```
GIVEN   impact-analysis ya ejecutado para este slice
AND     ficheros target no han cambiado
WHEN    bash scripts/impact-analysis.sh (mismos ficheros)
THEN    output servido desde cache
AND     duracion <200ms
```

### Dependencia transitiva

```
GIVEN   A importa B, B importa C (depth=2)
AND     slice modifica C
WHEN    bash scripts/impact-analysis.sh C --depth 2
THEN    B aparece como dependiente directo
AND     A aparece como dependiente transitivo
AND     riesgo de A es menor que riesgo de B
```

---

## 6. Ficheros a Crear/Modificar

| Accion | Fichero | Que hacer |
|--------|---------|-----------|
| Crear | scripts/impact-analysis.sh | Script principal de analisis |
| Crear | tests/test-impact-analysis.sh | Suite BATS |
| Modificar | .claude/rules/domain/dev-session-protocol.md | Fase 1: ejecutar impact-analysis |
| Modificar | .claude/rules/domain/dev-session-protocol.md | Fase 2: inyectar informe al contexto |

---

## 7. Integracion con dev-session-protocol.md

### Fase 1 — Spec Load and Slice (modificacion)

Despues de que dev-orchestrator genere plan.md con los slices:

```
Para cada slice en plan.md:
  1. Extraer lista de ficheros target
  2. Ejecutar: bash scripts/impact-analysis.sh {ficheros}
  3. Guardar: output/dev-sessions/{id}/impact/slice-{n}.md
  4. Si risk_score >= 76 --> sugerir subdivision del slice
```

### Fase 2 — Context Prime (modificacion)

Anadir al budget de contexto del agente:

| Elemento | Tokens estimados |
|----------|-----------------|
| Spec-slice excerpt | 1.5-2K |
| Ficheros target (source) | 6-8K |
| Impact report | 0.5-1K (NUEVO) |
| Test template/fixture | 2-3K |
| Referencia arquitectura | 1-2K |

El agente recibe el impact report como seccion adicional: sabe que ficheros
OTROS dependen de lo que va a modificar, y que tests deberian pasar.

---

## 8. Metricas de exito

| Metrica | Objetivo | Medicion |
|---------|----------|----------|
| Dependientes detectados | >=80% de reales | Manual review en 3 proyectos |
| Sorpresas en Fase 4 | Reduccion >=60% | Contar re-implementaciones |
| Tiempo de analisis | <5s (depth=2) | Timer en script |
| Slices criticos divididos | >50% aceptan subdivision | Tracking dev-sessions |

---

## Checklist Pre-Entrega

- [ ] scripts/impact-analysis.sh detecta dependientes en 6 lenguajes
- [ ] Tests BATS pasan (>=80 score)
- [ ] Precision >=80% medida en proyecto real (TypeScript)
- [ ] Cache funciona (segundo run <200ms)
- [ ] Risk scoring calibrado contra 5 slices reales
- [ ] dev-session-protocol.md actualizado (Fase 1 + Fase 2)
- [ ] Sin dependencias externas (solo bash+grep+awk)
