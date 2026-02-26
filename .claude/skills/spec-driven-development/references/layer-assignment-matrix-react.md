# Matriz de Asignación de Tareas — React/Next.js Clean Architecture

> Matriz de referencia para proyectos React 19+ y Next.js App Router con Server Components y TanStack Query.
> Cada proyecto puede sobreescribir esta matriz en su `CLAUDE.md` bajo la sección `sdd_layer_assignment`.

---

## Principio General

```
Capas que favorecen `agent`:  Componentes UI puros, hooks simples, queries mecánicas
Capas que favorecen `human`:  Componentes servidor complejos, lógica de estado global, integraciones
```

El Tech Lead tiene siempre la última palabra.

---

## Matriz Principal por Capa y Tipo de Task

### 🔵 Components Layer (`src/components/` y `app/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Componente presentacional (UI puro)** | `agent:single` | Sin estado, sin efectos; solo props y JSX |
| **Componente Container (Client)** | `agent:single` si patrón simple / `human` si lógica compleja | Integra hooks y pasa props a presentacionales |
| **Server Component** (Next.js) | `agent:single` si data fetch simple / `human` si transformación compleja | Patrón: `async` component → `<Suspense>` |
| **Componente con children polymórfico** | `agent:single` | Composición con `React.ReactNode` claro |
| **Componente con estado local (`useState`)** | `agent:single` | State management simple dentro del componente |

---

### 🟢 Hooks Layer (`src/hooks/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Custom hook simple** (wrapping single state) | `agent:single` | Patrón fijo: `useState` + lógica + return `[state, handler]` |
| **Custom hook con efectos simples** | `agent:single` | `useEffect` directo sin dependencias complejas |
| **Custom hook con TanStack Query** | `agent:single` | Patrón: `useQuery` wrapper tipado con QueryFn clara |
| **Custom hook con múltiples efectos** | `human` | Orquestación de efectos requiere expertise |
| **Custom hook con reducer** | `agent:single` si reducer simple / `human` si acciones complejas | Depende de complejidad del estado |

---

### 🟡 State Layer (`src/store/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Zustand store simple** (un slice) | `agent:single` | Patrón mecánico: `create()` → state + actions |
| **Zustand store con múltiples slices** | `human` | Arquitectura de estado global requiere decisión |
| **TanStack Query mutation** (POST/PUT/DELETE) | `agent:single` | Patrón fijo: `useMutation` → `mutate` → invalidar |
| **TanStack Query query** | `agent:single` | Patrón: `useQuery` con QueryKey + QueryFn tipadas |
| **Computed/derived state** | `agent:single` | `useMemo` o Zustand selector claro |

---

### 🟠 Pages/Routes Layer (`app/` o `src/pages/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Route page (Next.js)** | `agent:single` | Composición de componentes en `page.tsx` |
| **Layout (Next.js)** | `agent:single` si estructura simple / `human` si providers complejos | Puede requerir Context/Providers |
| **Error boundary** | `agent:single` | Patrón predecible: `error.tsx` captura y display |
| **Loading UI** (`loading.tsx`) | `agent:single` | Simple skeleton o spinner |
| **Route handler** (`route.ts` API) | `human` | Lógica de negocio en el borde servidor/cliente |

---

### 🔴 Tests

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Unit Test — Presentational component** | `agent:single` | Render + snapshot + props variations claras |
| **Unit Test — Hook** (`renderHook`) | `agent:single` | Entrada/salida determinada |
| **Unit Test — Utility function** | `agent:single` | Sin dependencias externas |
| **Component Test — Container component** | `agent:single` si mocks simples / `human` si complejos | Puede requerir MockedProvider, fixtures |
| **Integration Test — Feature** | `human` | Flujos completos, múltiples componentes |
| **E2E Test** (Playwright, Cypress) | `human` | Flujos de usuario completos |

---

### ⚪ Tareas Transversales

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Code Review** | `human` siempre | Por definición, requiere un humano |
| **Documentación de componentes** (Storybook) | `agent:single` con revisión humana | Generar historias automáticas |
| **Migración de propTypes a TypeScript** | `agent:single` | Mapeo mecánico de tipos |
| **Optimización de performance** (React.memo, lazy loading) | `human` | Decisiones de arquitectura |
| **Type safety refactor** | `agent:single` | Añadir tipos a código existente |

---

## Heurísticas de Decisión Rápida

### ✅ Task ideal para `agent:single`

Marca al menos 4 de estos:
- [ ] Existe componente similar en el codebase
- [ ] El componente solo recibe props sin estado
- [ ] Los test scenarios están en la Spec
- [ ] Sin lógica de transformación compleja en el hook
- [ ] Sin dependencias circulares o contexto complicado
- [ ] El Tech Lead puede verificar revisando el code

### ✅ Task ideal para `agent:team`

Además de criterios de `agent:single`:
- [ ] Feature completa con múltiples componentes + hook + tests
- [ ] ≥ 6h de trabajo
- [ ] Roles separados: UI vs Logic vs Tests

### ❌ Task que DEBE ser `human`

Si aplica:
- Spec con "TBD" o incompleta
- Primera implementación del patrón
- Estado global o multi-store (Zustand)
- API no documentada o sin contrato claro
- Decisiones de UX/layout
- Optimización de performance
- Server Actions complejos

---

## Impacto Esperado por Tipo de Task

| Capa/Tipo | Frecuencia | % Agentizable | Tiempo Ahorrado/Sprint |
|-----------|-----------|--------------|----------------------|
| Componentes presentacionales | Alta | 95% | ~8h |
| Componentes container simples | Media | 75% | ~5h |
| Custom hooks simples | Media | 85% | ~4h |
| TanStack Query queries | Alta | 85% | ~6h |
| Unit Tests | Alta | 85% | ~10h |
| Zustand stores simples | Media | 80% | ~3h |
| **Total estimado** | | | **~36h/sprint** |

---

## Referencias

→ Spec template: `spec-template.md`
→ Convenciones React: `rules/react-conventions.md`
→ Next.js Best Practices: `docs/nextjs-guide.md`
→ TanStack Query: https://tanstack.com/query/latest
