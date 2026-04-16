# Spec: Semantic Context Maps — Representacion comprimida para agentes

**Task ID:**        SPEC-SEMANTIC-CONTEXT-MAPS
**PBI padre:**      Context optimization initiative (inspirado en ix-infrastructure/Ix)
**Sprint:**         2026-08
**Fecha creacion:** 2026-04-09
**Creado por:**     Savia (research: Feynman + Ix)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     6h
**Estado:**         Pendiente
**Max turns:**      30
**Modelo:**         claude-sonnet-4-6

---

## 1. Contexto y Objetivo

Cada vez que un subagente (dotnet-developer, test-engineer, architect, etc.) se
invoca via Task, recibe los ficheros target como texto crudo. Un fichero de 300
lineas consume ~1200 tokens. En un dev-session tipico con 5 slices y 3 agentes
por slice, el coste acumulado de contexto crudo es ~18K-25K tokens solo en
ficheros fuente — sin contar specs, reglas ni conversacion.

Ix (ix-infrastructure/Ix) demuestra que mapas semanticos pre-computados reducen
el consumo de tokens entre un 30% y un 99.7% manteniendo la informacion
estructural necesaria para razonar sobre el codigo.

**Objetivo:** Crear `scripts/semantic-map.sh` que genera un resumen semantico
comprimido de uno o mas ficheros fuente. El resumen captura: exports publicos,
dependencias, patrones de arquitectura y puntos de extension — sin incluir
implementacion interna. Los agentes reciben el mapa en vez del codigo crudo
cuando su tarea no requiere modificar esas lineas especificas.

**Criterios de Aceptacion:**
- [ ] Reduccion >=40% de tokens para ficheros >100 lineas (medido con tiktoken)
- [ ] Agentes que reciben mapa semantico producen output equivalente a los que reciben codigo crudo (test A/B en 3 specs existentes)
- [ ] Generacion del mapa <2s por fichero en hardware tipico
- [ ] Soporte para los 6 lenguajes mas usados: TypeScript, C#, Python, Go, Rust, Java
- [ ] Integracion con dev-session-protocol.md Fase 2 (Context Prime)

---

## 2. Contrato Tecnico

### 2.1 Interfaz / Firma

```bash
# scripts/semantic-map.sh
# Usage: bash scripts/semantic-map.sh [options] <file1> [file2] [...]
#
# Options:
#   --format compact|full    Output detail level. Default: compact
#   --lang auto|ts|cs|py|go|rs|java   Language override. Default: auto (detect)
#   --output-dir DIR         Write .smap files to DIR. Default: stdout
#   --max-tokens N           Target max tokens per file. Default: 300
#
# Input:  file paths (source code files)
# Output: stdout or .smap files (structured markdown summary)
# Exit:   0 success, 1 parse error (fallback: first+last 50 lines)
```

### 2.2 Formato de salida (.smap)

```markdown
# {filename} — Semantic Map
> lang: typescript | lines: 247 | exports: 8 | deps: 5

## Public Interface
- class UserService — constructor(repo: UserRepository, cache: CacheService)
- async createUser(dto: CreateUserDto): Promise<User> — validates, persists, emits event
- async findById(id: string): Promise<User | null> — cache-first, fallback to repo
- type CreateUserDto = { name: string; email: string; role?: Role }

## Dependencies
- UserRepository (injected) — persistence layer
- CacheService (injected) — cache
- EventBus (injected) — domain events
- zod — input validation

## Architecture Patterns
- Repository pattern (data access abstracted)
- Constructor injection (DI)
- Cache-aside pattern (read-through)

## Extension Points
- Event listeners can react to UserCreatedEvent
- CacheService is interface-based (swappable)
```

### 2.3 Estrategia de extraccion por lenguaje

La extraccion se basa en patrones de texto (grep/awk), NO en AST completo.
Esto mantiene la dependencia en zero (solo bash + grep) y la latencia baja.

| Lenguaje | Exports detectados | Patron |
|----------|-------------------|--------|
| TypeScript | export (class/function/const/type/interface/enum) | grep + awk |
| C# | public (class/interface/record/enum/struct) + metodos publicos | grep + awk |
| Python | class X:, def X(, __all__ | grep + awk |
| Go | Funciones/tipos con mayuscula inicial | grep |
| Rust | pub (fn/struct/enum/trait/mod) | grep |
| Java | public (class/interface/record/enum) + metodos publicos | grep + awk |

Dependencias: extraer de imports/requires/use del fichero.

### 2.4 Fallback

Si la extraccion falla (lenguaje no soportado, fichero binario, error):
- Devolver primeras 30 + ultimas 20 lineas del fichero
- Marcar como fallback: true en el header del .smap

---

## 3. Reglas de Negocio

| ID | Regla | Error si viola |
|----|-------|----------------|
| SCM-01 | Solo generar mapa para ficheros >50 lineas. Ficheros cortos se pasan tal cual | N/A (optimizacion) |
| SCM-02 | El mapa NUNCA omite una funcion/metodo publico. Puede omitir implementacion pero no firma | Test de cobertura |
| SCM-03 | Dependencias listan TODAS las importaciones, no solo las importantes | Test de completitud |
| SCM-04 | Si el agente va a MODIFICAR un fichero, recibe codigo crudo + mapa. Si solo lo CONSULTA, recibe solo mapa | Logica en dev-session |
| SCM-05 | Mapas se cachean por hash SHA256 del fichero fuente. Si el hash no cambia, se reutiliza | Cache invalidation |

---

## 4. Constraints

| Dimension | Requisito |
|-----------|-----------|
| Performance | <2s por fichero, <10s para 20 ficheros |
| Dependencias | Zero dependencias externas (solo bash, grep, awk, sed) |
| Compatibilidad | bash 4.0+, macOS + Linux |
| Cache | .smap files en output/semantic-maps/ con nombre {sha256-8chars}.smap |
| Tamano | Max 300 tokens por mapa (configurable con --max-tokens) |

---

## 5. Test Scenarios

### Happy path

```
GIVEN   fichero UserService.ts de 247 lineas con 8 exports
WHEN    bash scripts/semantic-map.sh UserService.ts
THEN    output contiene las 8 firmas publicas
AND     output contiene lista completa de dependencias
AND     output tiene <300 tokens (estimado: lineas * 0.75)
AND     duracion <2s
```

### Fichero corto (bypass)

```
GIVEN   fichero constants.ts de 30 lineas
WHEN    bash scripts/semantic-map.sh constants.ts
THEN    output es el fichero original sin modificar
```

### Lenguaje no soportado

```
GIVEN   fichero schema.graphql
WHEN    bash scripts/semantic-map.sh schema.graphql
THEN    output es fallback (primeras 30 + ultimas 20 lineas)
AND     header contiene fallback: true
```

### Cache hit

```
GIVEN   UserService.ts ya mapeado y sin cambios
WHEN    bash scripts/semantic-map.sh UserService.ts
THEN    output se sirve desde cache
AND     duracion <100ms
```

---

## 6. Ficheros a Crear/Modificar

| Accion | Fichero | Que hacer |
|--------|---------|-----------|
| Crear | scripts/semantic-map.sh | Script principal de generacion |
| Crear | tests/test-semantic-map.sh | Suite BATS de tests |
| Modificar | docs/rules/domain/dev-session-protocol.md | Fase 2: cargar .smap para ficheros de consulta |
| Modificar | docs/rules/domain/agent-context-budget.md | Documentar reduccion esperada con .smap |
| Crear | output/semantic-maps/.gitkeep | Directorio de cache |

---

## 7. Integracion con dev-session-protocol.md

### Fase 2 — Context Prime (modificacion)

Logica actual: cargar ficheros target como texto crudo.

Logica nueva:
```
Para cada fichero en el slice:
  SI el agente va a MODIFICAR el fichero:
    -> Cargar codigo crudo (como hasta ahora)
  SI el agente solo CONSULTA el fichero (dependencia, referencia):
    -> Generar/cachear .smap
    -> Cargar .smap en vez de codigo crudo
```

Esto reduce el budget de Fase 2 de ~15K tokens a ~8-10K tokens estimados.

---

## 8. Metricas de exito

| Metrica | Objetivo | Medicion |
|---------|----------|----------|
| Token reduction | >=40% en ficheros >100 lineas | tiktoken count antes/despues |
| Agent output quality | Sin degradacion medible | A/B test en 3 specs |
| Cache hit rate | >80% en sesiones de desarrollo | Contador en script |
| Adoption | Integrado en dev-session dentro de 1 sprint | Checklist |

---

## Checklist Pre-Entrega

- [ ] scripts/semantic-map.sh genera mapas para los 6 lenguajes
- [ ] Tests BATS pasan (>=80 score en auditor)
- [ ] Reduccion >=40% medida en ficheros reales del workspace
- [ ] Cache funciona (segundo run <100ms)
- [ ] Fallback funciona para lenguajes no soportados
- [ ] dev-session-protocol.md actualizado
- [ ] Sin dependencias externas (solo bash+grep+awk+sed)
