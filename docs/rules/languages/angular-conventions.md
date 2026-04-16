---
paths:
  - "**/*.component.ts"
  - "**/*.module.ts"
  - "**/*.service.ts"
  - "**/*.directive.ts"
---

# Regla: Convenciones y Prácticas Angular
# ── Aplica a todos los proyectos Angular en este workspace ──

## Verificación obligatoria en cada tarea

```bash
ng build --configuration production            # 1. ¿Compila sin warnings?
ng lint                                        # 2. ¿Pasa ESLint (@angular-eslint)?
npx prettier --check "src/**/*.{ts,html,scss}" # 3. ¿Formato correcto?
ng test --watch=false --browsers=ChromeHeadless # 4. ¿Tests unitarios pasan?
```

Si hay tests E2E relevantes:
```bash
npx cypress run                                # o ng e2e
```

## Convenciones de código Angular

- **Naming ficheros:** `kebab-case` → `user-profile.component.ts`, `auth.guard.ts`, `user.service.ts`
- **Naming código:** `PascalCase` (clases/interfaces), `camelCase` (propiedades/métodos), `UPPER_SNAKE` (constantes)
- **Sufijos obligatorios:** `.component.ts`, `.service.ts`, `.guard.ts`, `.interceptor.ts`, `.pipe.ts`, `.directive.ts`, `.module.ts`
- **Standalone components** (Angular 17+): preferidos sobre NgModules; declarar `standalone: true`
- **Change detection:** `OnPush` por defecto en todos los componentes
- **Signals** (Angular 17+): preferir `signal()`, `computed()`, `effect()` sobre Subject/BehaviorSubject para estado local
- **inject()** function: preferida sobre constructor injection en Angular 17+
- **Templates:** Usar `@if`, `@for`, `@switch` (Angular 17+ control flow) sobre `*ngIf`, `*ngFor`
- **Reactive Forms** preferidos sobre Template-driven forms
- **RxJS:** Evitar subscribe manual; usar `async` pipe o `toSignal()`. Si subscribe es necesario, usar `takeUntilDestroyed()`
- **No any:** Tipar todo; `unknown` si el tipo es desconocido

## Gestión de Estado

### Estado local (componente)
- Angular Signals: `signal()`, `computed()`, `effect()`
- Reactive Forms para formularios

### Estado global (feature/app)
- **NgRx** (proyectos enterprise): Store, Actions, Reducers, Effects, Selectors
- **NgRx Signal Store** (Angular 17+): alternativa simplificada
- Nunca estado global mutable fuera del store

## Routing

- **Lazy loading obligatorio** para features: `loadComponent` o `loadChildren`
- Guards funcionales (Angular 15+): `CanActivateFn`, `CanDeactivateFn`
- Resolvers para pre-carga de datos
- Route params tipados con Angular Router typed params

## Tests

- **Unit tests:** Jasmine + Karma (por defecto) o Jest (si configurado)
- **Component tests:** `TestBed.configureTestingModule()` con standalone components
- **Service tests:** Mocking con `jasmine.createSpyObj()` o `jest.fn()`
- Naming: `describe('ComponentName')` → `it('should {behavior} when {condition}')`
- **E2E:** Cypress (preferido) o Playwright
- Cobertura mínima: 80% (`ng test --code-coverage`)

```bash
ng test --watch=false --browsers=ChromeHeadless                # unit tests
ng test --code-coverage --watch=false --browsers=ChromeHeadless # con cobertura
npx cypress run                                                 # E2E
```

## Gestión de dependencias

```bash
ng update                                      # ver actualizaciones Angular
npm outdated                                   # paquetes obsoletos
npm audit                                      # vulnerabilidades
ng add {paquete}                               # añadir con schematics
```

## Estructura de proyecto

```
src/app/
├── core/                    ← servicios singleton, guards, interceptors, auth
│   ├── guards/
│   ├── interceptors/
│   ├── services/
│   └── core.provider.ts     ← provideCore() para standalone bootstrap
├── shared/                  ← componentes reutilizables, pipes, directives
│   ├── components/
│   ├── directives/
│   ├── pipes/
│   └── models/              ← interfaces compartidas
├── features/                ← módulos funcionales (lazy loaded)
│   └── {feature}/
│       ├── components/      ← smart + dumb components
│       ├── services/        ← feature-specific services
│       ├── models/          ← interfaces y types del feature
│       ├── state/           ← NgRx store / signals del feature
│       └── {feature}.routes.ts
├── app.component.ts
├── app.config.ts            ← provideRouter, provideHttpClient, etc.
└── app.routes.ts            ← rutas principales con lazy loading
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
      "run": "ng test --watch=false --browsers=ChromeHeadless 2>&1 | tail -20"
    }]
  }
}
```
