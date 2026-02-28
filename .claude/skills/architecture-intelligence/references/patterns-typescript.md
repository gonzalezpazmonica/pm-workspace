---
name: patterns-typescript
description: Patrones de arquitectura para TypeScript (Angular, React, Node.js)
context_cost: low
---

# Patrones — TypeScript (Angular / React / Node.js)

## 1. Clean Architecture (⭐ Recomendado para backends)

**Folder Structure (Node.js/Express/NestJS)**:
```
src/
├── domain/            → Entities, Value Objects, Repository interfaces
├── application/       → Use Cases, DTOs, Services
├── infrastructure/    → Database, External APIs, Repositories impl
├── presentation/      → Controllers, Routes, Middleware
└── shared/            → Utils, Constants, Types
```

**Detection Markers**:
- Carpetas por capa con imports unidireccionales
- Interfaces en domain, implementaciones en infrastructure
- NestJS: `@Module`, `@Injectable`, `@Controller` decorators
- Express: router files + service classes + repository pattern

## 2. Component-Based (⭐ Recomendado para frontends)

**React Folder Structure**:
```
src/
├── components/        → Reusable UI components
├── pages/ or views/   → Route-level components
├── hooks/             → Custom hooks (useX naming)
├── services/          → API calls, business logic
├── store/ or context/ → State management
├── types/             → TypeScript interfaces/types
└── utils/             → Helper functions
```

**Angular Folder Structure**:
```
src/app/
├── core/              → Singleton services, guards, interceptors
├── shared/            → Shared components, pipes, directives
├── features/          → Feature modules (lazy loaded)
│   └── feature-name/
│       ├── components/
│       ├── services/
│       └── feature.module.ts
└── app.module.ts
```

**Detection Markers React**: `useState`, `useEffect`, custom hooks, JSX/TSX
**Detection Markers Angular**: `@NgModule`, `@Component`, `*.module.ts`, RxJS

## 3. Redux / State Management Pattern

**Detection Markers**:
- Carpetas: `store/`, `slices/`, `reducers/`, `actions/`
- Redux: `createSlice`, `configureStore`, `useSelector`, `useDispatch`
- Zustand: `create()` stores
- MobX: `makeObservable`, `@observable`

## 4. Hexagonal (Node.js backends)

**Detection Markers**:
- Carpetas: `ports/`, `adapters/`, `core/`
- TypeScript interfaces como ports
- Dependency injection (NestJS, tsyringe, inversify)

## 5. Micro-frontends

**Detection Markers**:
- Module Federation config (webpack)
- Múltiples `package.json` en monorepo
- Shared dependencies configuration
- Host/remote application setup

## Tools de Enforcement
- **eslint-plugin-boundaries**: Reglas de imports entre capas
- **dependency-cruiser**: Grafo de dependencias y reglas
- **nx**: Monorepo con boundaries enforcement
- **madge**: Detección de dependencias circulares

## Anti-patterns comunes
- Prop drilling excesivo (>3 niveles sin context/store)
- Business logic en componentes UI
- `any` type usage (pérdida de type safety)
- Barrel exports circulares (`index.ts` loops)
