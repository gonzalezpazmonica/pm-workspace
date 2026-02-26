# Regla: Convenciones y Prácticas TypeScript/Node.js
# ── Aplica a todos los proyectos TypeScript (backend y full-stack) en este workspace ──

## Verificación obligatoria en cada tarea

Antes de dar una tarea por terminada, ejecutar siempre en este orden:

```bash
npx tsc --noEmit                              # 1. ¿Type-check sin errores?
npm run lint                                   # 2. ¿ESLint + Prettier sin warnings?
npm run test                                   # 3. ¿Pasan los tests unitarios?
```

Si hay tests de integración relevantes al cambio:
```bash
npm run test:integration
```

## Convenciones de código TypeScript

- **Naming:** `camelCase` para variables/funciones, `PascalCase` para clases/interfaces/types/enums, `UPPER_SNAKE_CASE` para constantes, `I` prefix NO usado en interfaces
- **async/await** en toda la cadena — NUNCA callbacks anidados ni `.then()` chains cuando se puede `await`
- **Strict mode** habilitado siempre: `"strict": true` en `tsconfig.json`
- **Records e inmutabilidad:** Preferir `readonly` en propiedades, `as const` para literals, `Readonly<T>` para parámetros que no deben mutarse
- **Inyección de dependencias** por constructor o factory functions; nunca instanciar servicios con `new` en producción
- **Null handling:** Preferir `??` (nullish coalescing) sobre `||`; usar optional chaining `?.`; nunca `any` — usar `unknown` si el tipo es desconocido
- **Error handling:** Tipos `Result<T, E>` pattern, o excepciones tipadas; nunca `catch` vacío; nunca `catch (e: any)`
- **Imports:** Usar ES modules (`import/export`); nunca `require()` en TypeScript; barrel exports (`index.ts`) para módulos públicos
- **Enums:** Preferir `const enum` o union types (`type Status = 'active' | 'inactive'`) sobre `enum`

## Frameworks y Herramientas

### NestJS (backend preferido para enterprise)
- Módulos, Controllers, Services, Guards, Interceptors, Pipes
- DTOs con `class-validator` + `class-transformer`
- CQRS con `@nestjs/cqrs` para proyectos complejos

### Express/Fastify (backend ligero)
- Router modular por feature
- Middleware con tipado fuerte
- Validación con Zod o Joi

### Prisma (ORM preferido)
- Schema declarativo (`schema.prisma`)
- Migraciones: `npx prisma migrate dev --name {nombre}`
- Nunca modificar migraciones ya aplicadas
- Regenerar client tras cambios: `npx prisma generate`
- Índices explícitos en campos con queries frecuentes

### Alternativas ORM
- TypeORM (si el proyecto ya lo usa)
- Drizzle ORM (type-safe, SQL-first)

## Tests

- Tests unitarios en: `tests/unit/` o `src/**/__tests__/`
- Tests de integración en: `tests/integration/`
- Framework: **Vitest** (preferido) o Jest
- Mocking: `vi.mock()` (Vitest) o `jest.mock()`
- Naming: `describe('ServiceName')` → `it('should {behavior} when {condition}')`
- Categorización: archivos `*.unit.test.ts` / `*.integration.test.ts` o directorios separados
- No mockear infraestructura real — usar **Testcontainers** para DB, Redis, etc. en integration tests
- Un assertion lógico por test cuando sea posible

```bash
npx vitest run                                 # todos los tests
npx vitest run --reporter verbose              # con detalle
npx vitest run tests/unit                      # solo unitarios
npx vitest run tests/integration               # solo integración
npx vitest run --coverage                      # con cobertura
```

## Gestión de dependencias

```bash
npm ls --depth=0                               # ver dependencias instaladas
npm outdated                                   # ver paquetes obsoletos
npm audit                                      # detectar vulnerabilidades
npm audit fix                                  # corregir automáticamente
npm install {paquete}@{version}                # añadir con versión explícita
```

- **Nunca** añadir paquetes sin verificar: licencia, última actualización, CVEs activos
- Mantener `package-lock.json` siempre commiteado
- Separar `dependencies` (producción) de `devDependencies` (desarrollo)
- Preferir paquetes con tipos TypeScript incluidos (`@types/` solo si no hay nativos)

## Estructura de solución

```
{proyecto}/
├── src/
│   ├── domain/              ← entidades, value objects, interfaces de repositorio
│   ├── application/         ← use cases, DTOs, validators (Zod), services
│   ├── infrastructure/      ← Prisma repos, HTTP clients, messaging, caching
│   └── api/                 ← controllers/routes, middleware, DTOs de request/response
├── tests/
│   ├── unit/                ← vitest, mocking con vi.mock()
│   └── integration/         ← testcontainers, supertest
├── prisma/
│   ├── schema.prisma        ← schema declarativo
│   └── migrations/          ← migraciones auto-generadas
├── tsconfig.json
├── package.json
├── vitest.config.ts
├── .eslintrc.cjs
└── .prettierrc
```

## Deploy

```bash
npm run build                                  # compilar TypeScript
npm run start:prod                             # iniciar en producción
# Docker
docker build -t {app} .
docker run -p 3000:3000 {app}
```

## Hooks recomendados para proyectos TypeScript

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "run": "cd $(git rev-parse --show-toplevel) && npx tsc --noEmit 2>&1 | head -10"
    }],
    "PreToolUse": [{
      "matcher": "Bash(git commit*)",
      "run": "npm test -- --reporter verbose 2>&1 | tail -20"
    }]
  }
}
```
