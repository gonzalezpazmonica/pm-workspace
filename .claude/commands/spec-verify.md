# /spec-verify

Verifica implementación contra la spec. Cruza cada escenario Given/When/Then con tests reales. Un escenario es COMPLIANT solo si existe un test que PASA.

## Uso
```
/spec-verify {spec-file}
```

- `{spec-file}`: Ruta a fichero spec (ej: `projects/sala-reservas/specs/2026-04/AB1234-B3-create-sala.spec.md`)

## Pasos de Ejecución

### Paso 1 — Banner de inicio

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✔️  /spec-verify — Matriz de compliance spec vs tests
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Paso 2 — Leer spec y extraer escenarios

Cargar spec file. Extraer:
- Sección 4: Test Scenarios (formato Given/When/Then)
- Número de escenarios
- Requisitos asociados

### Paso 3 — Lanzar subagente de verificación

Usar `Task` para mapear escenarios a tests:

**Búsqueda de tests relacionados:**
- Encontrar test files en codebase
- Buscar tests por nombre/pattern del requisito
- Buscar tests por nombre del módulo

**Mapeo escenario → test:**
- Para cada escenario: ¿existe test que lo cubre?
- Si existe: ¿PASA el test? (ejecutar si es posible)
- Si NO existe: marcar como "SIN TEST"

**Generar compliance matrix:**
- Columnas: #, Requisito, Escenario, Test File/Line, Estado
- Estado: ✅ PASS | ❌ SIN TEST | ⚠️  FALLA

### Paso 4 — Guardar resultado

```
output/verifications/{task-id}-compliance.md
```

Matriz de compliance en formato markdown:

```markdown
| # | Requisito | Escenario | Test | Estado |
|---|-----------|-----------|------|--------|
| 1 | Crear sala | Given valid data, When create, Then saved | CreateSalaTests.cs:L42 | ✅ PASS |
| 2 | Validar duplicado | Given existing name, When create, Then error | CreateSalaTests.cs:L67 | ✅ PASS |
| 3 | Permiso editor | Given guest user, When create, Then forbidden | CreateSalaTests.cs:L95 | ❌ SIN TEST |
```

### Paso 5 — Análisis de gaps

Generar resumen:
- Escenarios totales: N
- Con test PASS: M
- Sin test: X
- Tests que fallan: Y
- Compliance rate: M/N * 100%

### Paso 6 — Banner de finalización

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ /spec-verify — Verificación completada
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Matriz: output/verifications/{task-id}-compliance.md

Escenarios totales ..................... N
Con test y PASS ........................ M (X%)
Sin test ............................... Y
Compliance rate ....................... M/N%

Acción sugerida:
  - Si < 100% → crear tests faltantes
  - Si todos PASS → spec completada

⚡ /compact — Liberar contexto
```

## Notas

- COMPLIANT = test EXISTS y PASSES. Código sin test NO cuenta como evidencia
- "Código ya existe" NO es lo mismo que "test existe"
- Gap analysis muestra explícitamente qué escenarios necesitan test
