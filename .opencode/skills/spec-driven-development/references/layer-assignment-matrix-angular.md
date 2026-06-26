# Matriz de Asignación de Tareas — Angular Clean Architecture

> Matriz de referencia para proyectos Angular 17+, arquitectura limpia con standalone components y signals.
> Cada proyecto puede sobreescribir esta matriz en su `CLAUDE.md` bajo la sección `sdd_layer_assignment`.

---

## Principio General

```
Capas que favorecen `agent`:  Componentes UI estructurados, pipes, servicios mecánicos
Capas que favorecen `human`:  Lógica compleja de estado, integraciones de datos, decisiones UX
```

El Tech Lead tiene siempre la última palabra.

---

## Matriz Principal por Capa y Tipo de Task

### 🔵 Core Layer (`src/app/core/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| Crear Guard funcional (autenticación simple) | `agent-single` | Patrón fijo: verificar token → retornar true/false/redirect |
| Implementar Guard con lógica compleja | `human` | Decisiones de autorización multi-rol requieren revisión |
| Crear Interceptor (logging, timing) | `agent-single` | Patrón predecible: wrap request → call next → return response |
| Implementar Interceptor de error global | `human` | Decisiones de manejo de errores afectan a toda la app |
| Servicio singleton (Auth, Config) | `agent-single` si patrón existe / `human` si es nuevo | Verificar si existe servicio similar |

---

### 🟢 Shared Layer (`src/app/shared/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| Componente presentacional (UI puro) | `agent-single` | Sin lógica de estado; entrada=@Input, salida=@Output |
| Pipe simple (formato fecha, moneda) | `agent-single` | Transformación mecánica de datos |
| Directiva de utilidad (highlight, autofocus) | `agent-single` | Patrón fijo: @Directive + @HostListener/Binding |
| Componente con @Input/@Output clara | `agent-single` | Contrato definido: inputs/outputs especificados |
| Componente con lógica de estado | `human` | Requiere entendimiento de flujos de datos |

---

### 🟡 Features Layer (`src/app/features/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Smart Component** (con Signal + consulta) | `agent-single` si spec clara / `human` si lógica compleja | Patrón: `signal()` + servicio + `computed()` |
| **Dumb Component** (presentación) | `agent-single` | Recibe data por @Input, emite eventos por @Output |
| **Servicio local del feature** (queries, mutations) | `agent-single` | Métodos CRUD delegados a backend |
| **RxJS observable con lógica de transformación** | `human` | `switchMap`, `mergeMap`, operadores requieren expertise |
| **Manejo de estado con NgRx (feature store)** | `human` | Actions, reducers, effects requieren diseño arquitectónico |
| **Formulario Reactive complejo** | `agent-single` si validadores simples / `human` si validators custom | Depende de reglas de negocio |

---

### 🟠 API / HTTP Layer

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **HTTP GET/POST básico** (HttpClient) | `agent-single` | Patrón fijo: `this.http.get<T>(url)` |
| **Query con parámetros** | `agent-single` | Construcción de HttpParams mecánica |
| **Error handling genérico** | `human` | Decisiones de retry, fallback, logging |
| **Request/Response mapping** | `agent-single` | Transformación de DTOs mecánica |

---

### 🔴 Tests

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Unit Test — Pipe** | `agent-single` | Entrada/salida determinada |
| **Unit Test — Directive** | `agent-single` | Comportamiento DOM predecible |
| **Component Test — Presentacional** | `agent-single` | Sin dependencias complejas; inputs/outputs claros |
| **Component Test — Smart component** | `agent-single` si spec clara / `human` si mocking complejo | Puede requerir MockService, fixture setup |
| **Service Test** | `agent-single` | Métodos desacoplados, mocks de HTTP claros |
| **E2E Test** (Cypress) | `human` | Flujos completos de usuario; criterios de test |
| **Visual Regression Test** | `human` | Decisiones sobre umbrales visuales |

---

### ⚪ Tareas Transversales

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Code Review** | `human` siempre | Por definición, requiere un humano |
| **Documentación de componentes** (Storybook) | `agent-single` con revisión humana | Generar historias de componentes |
| **Actualización de Angular** (ng update) | `human` | Cambios de breaking, dependencias |
| **Optimización de performance** (OnPush, lazy loading) | `human` | Decisiones de arquitectura |

---

## Heurísticas de Decisión Rápida

### ✅ Task ideal para `agent-single`

Marca al menos 4 de estos:
- [ ] Existe componente similar en el codebase
- [ ] El componente solo tiene @Input/@Output sin estado interno
- [ ] No tiene dependencias de servicios complejos
- [ ] Los test scenarios están en la Spec
- [ ] Sin lógica de validación custom
- [ ] El Tech Lead puede verificar solo revisando el code

### ✅ Task ideal para `agent-team`

Además de criterios de `agent-single`:
- [ ] Feature completa con smart + dumb components + tests
- [ ] ≥ 6h de trabajo
- [ ] Roles separados: UI vs Logic vs Tests

### ❌ Task que DEBE ser `human`

Si aplica:
- Spec con "TBD" o vago
- Primera vez implementando ese patrón
- Estado global complejo (NgRx)
- Integración con API externa sin documentación
- Decisiones de UX/diseño
- Tech Lead no puede verificar sin ejecutar

---

## Impacto Esperado por Tipo de Task

| Capa/Tipo | Frecuencia | % Agentizable | Tiempo Ahorrado/Sprint |
|-----------|-----------|--------------|----------------------|
| Pipes y Directives | Alta | 95% | ~3h |
| Componentes dumb | Alta | 85% | ~8h |
| Services básicos | Media | 80% | ~4h |
| Componentes smart | Media | 60% | ~5h |
| Formularios simples | Media | 75% | ~4h |
| Unit Tests | Alta | 85% | ~10h |
| **Total estimado** | | | **~34h/sprint** |

---

## Referencias

→ Spec template: `spec-template.md`
→ Convenciones Angular: `rules/angular-conventions.md`
→ Storybook: `docs/ui-library.md`
