# Compliance Matrix — Verificación de Implementación contra Spec

Documento de referencia para mapear escenarios de spec con tests reales.

---

## ¿Qué es una Compliance Matrix?

Tabla que cruza cada requisito/escenario de la spec con:
- Fichero de test donde se verifica
- Estado del test (PASA / FALLA / NO EXISTE)
- Línea exacta del código de test

**Regla cardinal:** Un escenario es COMPLIANT solo si:
1. Existe un test que lo cubre
2. El test PASA
3. El código fuente **no es evidencia** — solo el test

---

## Formato de Matriz

```markdown
| # | Requisito | Escenario (Given/When/Then) | Test File:Línea | Estado |
|---|-----------|----------------------------|-----------------|--------|
| 1 | Crear sala | Given valid data, When create, Then saved | CreateSalaTests.cs:L42 | ✅ PASS |
| 2 | Validar duplicado | Given existing name, When create error | CreateSalaTests.cs:L67 | ✅ PASS |
| 3 | Permiso editor | Given guest user, When create, Then 403 | AuthorizationTests.cs:L125 | ❌ FALLA |
| 4 | Límite caracteres | Given name > 255 chars, Then error | ValidationTests.cs:L89 | ❌ SIN TEST |
```

### Símbolos de estado
- `✅ PASS` — Test existe y pasa
- `❌ FALLA` — Test existe pero falla
- `⚠️ SIN TEST` — No existe test que cubra escenario

---

## Reglas de Compliance

### 1. Test MUST EXIST
- No es suficiente que el código implemente la lógica
- No es suficiente que el dev diga "está implementado"
- **Un test de verdad debe existir en el codebase**

### 2. Test MUST PASS
- Si test existe pero falla → NO COMPLIANT
- Fix: corregir código o test (usualmente código)

### 3. Código Existente NO ES Evidencia
```
❌ MAL:
  "La validación está en CreateSalaHandler línea 42"
  → No → no hay test

✅ BIEN:
  "CreateSalaTests.cs línea 67 verifica validación con Assert"
  → Sí → hay test
```

---

## Gap Analysis

Después de generar la matriz, analizar gaps:

```markdown
## Gaps Identificados

| # | Requisito | Razón | Acción |
|---|-----------|-------|--------|
| 4 | Límite caracteres | No existe test de validación | Crear ValidationTests |
| 7 | Permiso editor | Test existe pero aserciones incompletas | Revisar test |
```

Prioridad: BLOCKER (funcionalidad falta) > MAJOR (test incompleto) > MINOR (coverage bajo)

---

## Ciclo de Consolidación (Sprint Closing)

Al cerrar sprint:

1. **Generar compliance matrix** del spec final
2. **Consolidar deltas** si hubo modificaciones
3. **Archivar** matrix en `output/verifications/{sprint}-{proyecto}-consolidated.md`
4. **Actualizar** spec: marcar como "VERIFIED" si compliance = 100%
5. **Registrar** en deuda técnica si compliance < 100%

---

## Ejemplo Completo

```markdown
# Compliance Matrix — AB1234: CreateSala

| # | Requisito | Escenario | Test | Estado |
|---|-----------|-----------|------|--------|
| 1 | Crear sala básica | Given name=«Sala 1», When create, Then ID generado | CreateSalaHandlerTests.cs:L42 | ✅ PASS |
| 2 | Validación nombre | Given name vacío, When create, Then error validation | CreateSalaHandlerTests.cs:L67 | ✅ PASS |
| 3 | Unicidad nombre | Given name existe, When create, Then error duplicate | CreateSalaHandlerTests.cs:L89 | ✅ PASS |
| 4 | Autorización | Given user no-editor, When create, Then 403 | AuthorizationTests.cs:L125 | ✅ PASS |
| 5 | Auditoria | Given crear, When evento creación logged, Then BDD | AuditingTests.cs:L156 | ❌ SIN TEST |

## Análisis de Gaps
- **Total escenarios:** 5
- **Con test y PASS:** 4 (80%)
- **Gaps:** 1 (auditoría sin test)
- **Acción:** Crear AuditingTests antes de cerrar sprint

## Consolidación
- **Especificación:** ✅ COMPLETA (5/5 requisitos documentados)
- **Implementación:** ⚠️  PARCIAL (4/5 escenarios con test)
- **Compliance:** 80%
- **Estado sprint:** Cerrar CON DEUDA (auditoría para próximo sprint)
```

---

## Anti-Patrones

```
❌ "El código está allí, se ve correcto"
✅ "El test en línea 42 lo verifica"

❌ "El test está pero no lo ejecuté"
✅ "El test ejecutado y PASA"

❌ "Se puede ver que funciona"
✅ "El test assert lo verifica"
```
