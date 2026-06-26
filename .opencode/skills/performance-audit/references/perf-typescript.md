---
name: TypeScript/JavaScript Performance Patterns
description: Anti-patrones async, React renders, bundle size y DB patterns en TS/JS
context_cost: low
---

# TypeScript/JavaScript Performance Anti-Patterns

## Async Anti-Patterns

### Floating promises (CRITICAL)
- **Detect**: llamada async sin `await`, sin `.then()`, sin `.catch()`
- **Risk**: errores silenciosos, race conditions
- **Fix**: `await`, `.catch()`, o asignar a variable con handler

### Sequential await en loop (CRITICAL)
- **Detect**: `for` / `for...of` con `await` dentro del body
- **Risk**: ejecuta secuencialmente lo que podría ser paralelo
- **Fix**: `Promise.all(items.map(async (item) => ...))` o `Promise.allSettled()`

### Callback hell / pyramid of doom (HIGH)
- **Detect**: callbacks anidados >3 niveles
- **Fix**: refactorizar a async/await, extract functions

### Unhandled promise rejection (HIGH)
- **Detect**: `.then()` sin `.catch()`, missing try/catch en async functions
- **Fix**: añadir `.catch()` o `try/catch`, configurar `unhandledRejection` handler

## React Performance

### Unnecessary re-renders (HIGH)
- **Detect**: componente sin `React.memo()` que recibe nuevos objetos/arrays como props
- **Detect**: inline functions como props (`onClick={() => handleClick(id)}`)
- **Fix**: `React.memo()`, `useMemo()`, `useCallback()`, mover refs estables

### Missing dependency array (HIGH)
- **Detect**: `useEffect(() => {...})` sin segundo argumento
- **Risk**: ejecuta en cada render
- **Fix**: añadir dependency array `[dep1, dep2]`

### Expensive computation en render (MEDIUM)
- **Detect**: `.filter()`, `.map()`, `.sort()` en el body del componente sin `useMemo()`
- **Fix**: envolver en `useMemo(() => computation, [deps])`

## Bundle Size

### Tree-shaking failures (HIGH)
- **Detect**: `import _ from 'lodash'` (importa todo), `import * as moment from 'moment'`
- **Fix**: `import debounce from 'lodash/debounce'`, usar `date-fns` en vez de moment

### Dynamic imports missing (MEDIUM)
- **Detect**: imports pesados en entry point que podrían ser lazy
- **Fix**: `React.lazy()`, dynamic `import()`, code splitting por ruta

## Database / API

### N+1 en Prisma/TypeORM (CRITICAL)
- **Detect**: loop que hace query por iteración, `findMany` seguido de `findUnique` por item
- **Fix**: `include: { relation: true }`, batch queries, `$transaction`

### Missing eager loading (HIGH)
- **Detect**: acceso a relación sin `include`/`populate`/`leftJoinAndSelect`
- **Fix**: eager loading en la query principal

### No query batching (MEDIUM)
- **Detect**: múltiples queries independientes secuenciales
- **Fix**: `Promise.all([query1, query2])`, DataLoader, `$transaction`

## Memory Patterns

### Memory leaks en closures (HIGH)
- **Detect**: event listeners sin `removeEventListener` en cleanup
- **Detect**: `setInterval`/`setTimeout` sin `clearInterval`/`clearTimeout`
- **Fix**: cleanup en `useEffect` return, `AbortController` para fetch

### Large array operations (MEDIUM)
- **Detect**: `.map().filter().reduce()` chains en arrays grandes
- **Fix**: single pass con `.reduce()`, generators para procesamiento lazy

## Herramientas recomendadas

- **Lighthouse**: auditoría web completa (LCP, FID, CLS)
- **webpack-bundle-analyzer**: visualización de bundle
- **clinic.js**: profiling Node.js (doctor, flame, bubbleprof)
- **0x**: flame graphs para Node.js
- **React DevTools Profiler**: render timing y re-renders
