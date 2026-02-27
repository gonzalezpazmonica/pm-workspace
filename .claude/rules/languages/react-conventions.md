---
paths:
  - "**/*.tsx"
  - "**/*.jsx"
---

# Regla: Convenciones y Prácticas React
# ── Aplica a todos los proyectos React (Vite, Next.js, Remix) en este workspace ──

## Verificación obligatoria en cada tarea

```bash
npx tsc --noEmit                               # 1. ¿Type-check sin errores?
npm run lint                                   # 2. ¿ESLint + Prettier?
npm run test                                   # 3. ¿Tests pasan?
```

Si es Next.js:
```bash
next build                                     # Build completo con SSR/SSG
next lint                                      # Lint específico de Next.js
```

## Convenciones de código React

- **Naming:** `PascalCase` para componentes y archivos de componente, `camelCase` para hooks (`useAuth`), utils y variables, `kebab-case` para archivos no-componente
- **Componentes:** Functional components siempre; nunca class components
- **Hooks rules:** Nunca llamar hooks condicionalmente; nunca en loops; siempre en top-level del componente
- **Estado local:** `useState` para simple, `useReducer` para estado complejo con múltiples transiciones
- **Estado global:** Zustand (preferido por simplicidad) o TanStack Query (para server state)
- **Data fetching:** TanStack Query (React Query) — nunca `useEffect` + `fetch` para data fetching
- **Effects:** `useEffect` SOLO para sincronización con sistemas externos; NUNCA para derivar estado
- **Memoización:** `useMemo` y `useCallback` solo cuando hay evidencia de problema de rendimiento; React Compiler (React 19) los hace innecesarios en la mayoría de casos
- **Props:** Interfaces tipadas para todos los componentes; `children: React.ReactNode` cuando aplique
- **CSS:** Tailwind CSS (preferido), CSS Modules, o styled-components; nunca CSS global sin scope
- **Imports:** Absolute imports con alias (`@/components/`, `@/hooks/`)

## Patterns

### Composición sobre props drilling
```typescript
// ❌ Noncompliant — prop drilling
<Parent user={user}><Child user={user}><GrandChild user={user} /></Child></Parent>

// ✅ Compliant — composición o context
<UserProvider user={user}><Parent><Child><GrandChild /></Child></Parent></UserProvider>
```

### Custom hooks para lógica reutilizable
```typescript
// ✅ Extraer lógica a custom hook
function useDebounce<T>(value: T, delay: number): T { /* ... */ }
function useLocalStorage<T>(key: string, initialValue: T): [T, (v: T) => void] { /* ... */ }
```

### Server Components (Next.js App Router)
- Componentes server por defecto; `'use client'` solo cuando necesite interactividad
- `async` components para data fetching en server
- Streaming con `<Suspense>` boundaries

## Meta-frameworks

### Next.js (App Router — preferido para SSR/SSG)
- `app/` directory con file-based routing
- `layout.tsx`, `page.tsx`, `loading.tsx`, `error.tsx`
- Server Actions para mutations
- Route Handlers (`route.ts`) para APIs

### Vite (SPA sin SSR)
- React Router para routing client-side
- Lazy loading con `React.lazy()` + `Suspense`

## Tests

- **Framework:** Vitest (preferido) o Jest
- **Component testing:** `@testing-library/react` — testear comportamiento, no implementación
- **Hooks testing:** `@testing-library/react` → `renderHook()`
- **MSW (Mock Service Worker)** para mock de APIs en tests
- Naming: `describe('ComponentName')` → `it('renders {what} when {condition}')`
- Nunca testear detalles de implementación (state interno, re-renders)

```bash
npx vitest run                                 # todos los tests
npx vitest run --coverage                      # con cobertura
npx playwright test                            # E2E
```

## Gestión de dependencias

```bash
npm outdated                                   # paquetes obsoletos
npm audit                                      # vulnerabilidades
npx npm-check-updates -u                       # actualizar package.json
```

## Estructura de proyecto

```
src/
├── components/              ← componentes compartidos (UI library interna)
│   ├── ui/                  ← componentes base (Button, Input, Card, etc.)
│   └── layout/              ← layouts compartidos (Header, Footer, Sidebar)
├── features/                ← módulos por funcionalidad
│   └── {feature}/
│       ├── components/      ← componentes del feature
│       ├── hooks/           ← custom hooks del feature
│       ├── api/             ← queries y mutations (TanStack Query)
│       ├── types/           ← TypeScript interfaces del feature
│       └── utils/           ← utilidades del feature
├── hooks/                   ← hooks globales reutilizables
├── lib/                     ← utilidades, config, constantes, helpers
├── store/                   ← state global (Zustand slices)
├── types/                   ← tipos globales compartidos
├── styles/                  ← Tailwind config, global styles
└── app/                     ← Next.js App Router (si aplica)
    ├── layout.tsx
    ├── page.tsx
    └── {route}/
        ├── page.tsx
        └── layout.tsx
```

## Hooks recomendados

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "run": "cd $(git rev-parse --show-toplevel) && npx tsc --noEmit 2>&1 | head -10"
    }],
    "PreToolUse": [{
      "matcher": "Bash(git commit*)",
      "run": "npx vitest run --reporter verbose 2>&1 | tail -20"
    }]
  }
}
```
