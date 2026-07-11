---
paths:
  - "**/*.ts"
  - "**/*.mts"
  - "**/*.cts"
---

# Reglas de Análisis Estático TypeScript/Node.js — Knowledge Base para Agente de Revisión

> Fuente: ESLint, @typescript-eslint, SonarJS, Node.js security best practices
> Última actualización: 2026-02-26

---

## Instrucciones para el Agente

Eres un agente de revisión de código TypeScript/Node.js. Analiza código fuente aplicando las reglas documentadas a continuación.

**Protocolo de reporte:** Para cada hallazgo: ID de regla, Severidad, Línea(s), Descripción, Sugerencia con código.
**Priorización:** 1. Vulnerabilities → 2. Bugs → 3. Code Smells
**Responder siempre en español.**

---

## 1. VULNERABILITIES — Seguridad

### 1.1 Blocker

#### TS-SEC-01 — Credenciales hardcodeadas
**Severidad**: Blocker
```typescript
// FAIL Noncompliant
const API_KEY = "sk-1234567890abcdef";
const dbUrl = "postgresql://user:password@host/db";

// OK Compliant
const API_KEY = process.env.API_KEY!;
const dbUrl = process.env.DATABASE_URL!;
```

#### TS-SEC-02 — SQL Injection
**Severidad**: Blocker
```typescript
// FAIL Noncompliant
const query = `SELECT * FROM users WHERE id = ${userId}`;
await db.$queryRawUnsafe(query);

// OK Compliant
const user = await db.user.findUnique({ where: { id: userId } });
// O con query parametrizada:
await db.$queryRaw`SELECT * FROM users WHERE id = ${userId}`;
```

#### TS-SEC-03 — Command Injection
**Severidad**: Blocker
```typescript
// FAIL Noncompliant
exec(`ls ${userInput}`);

// OK Compliant
execFile('ls', [sanitizedPath]);
```

#### TS-SEC-04 — Path Traversal
**Severidad**: Blocker
```typescript
// FAIL Noncompliant
const filePath = path.join('/uploads', req.params.filename);

// OK Compliant
const filePath = path.join('/uploads', path.basename(req.params.filename));
if (!filePath.startsWith('/uploads')) throw new ForbiddenError();
```

### 1.2 Critical

#### TS-SEC-05 — XSS en respuestas HTML
**Severidad**: Critical
```typescript
// FAIL Noncompliant
res.send(`<h1>${userInput}</h1>`);

// OK Compliant — usar template engine con auto-escaping o sanitizar
res.send(`<h1>${escapeHtml(userInput)}</h1>`);
```

#### TS-SEC-06 — JWT sin verificación
**Severidad**: Critical
```typescript
// FAIL Noncompliant
const decoded = jwt.decode(token); // No verifica firma

// OK Compliant
const decoded = jwt.verify(token, secret);
```

#### TS-SEC-07 — Prototype Pollution
**Severidad**: Critical
```typescript
// FAIL Noncompliant
Object.assign(target, JSON.parse(userInput));

// OK Compliant
const safe = Object.create(null);
Object.assign(safe, JSON.parse(userInput));
```

#### TS-SEC-08 — Cookies sin flags de seguridad
**Severidad**: Critical
```typescript
// FAIL Noncompliant
res.cookie('session', token);

// OK Compliant
res.cookie('session', token, { httpOnly: true, secure: true, sameSite: 'strict' });
```

### 1.3 Major

#### TS-SEC-09 — CORS permisivo
**Severidad**: Major
```typescript
// FAIL Noncompliant
app.use(cors({ origin: '*' }));

// OK Compliant
app.use(cors({ origin: ['https://trusted.com'], credentials: true }));
```

#### TS-SEC-10 — Sin rate limiting
**Severidad**: Major
```typescript
// OK Compliant — aplicar rate limiting a endpoints públicos
app.use('/api/auth', rateLimit({ windowMs: 15 * 60 * 1000, max: 100 }));
```

---

## 2. SECURITY HOTSPOTS

#### TS-HOT-01 — eval() o Function()
```typescript
// FAIL Sensitive
eval(userInput);
new Function(userInput)();
```

#### TS-HOT-02 — Regex sin límite (ReDoS)
```typescript
// FAIL Sensitive
new RegExp(userInput); // Sin sanitizar

// OK Compliant
import { escapeRegExp } from 'lodash';
new RegExp(escapeRegExp(userInput));
```

#### TS-HOT-03 — Logging de datos sensibles
```typescript
// FAIL Sensitive
logger.info('User login', { password: user.password });

// OK Compliant
logger.info('User login', { userId: user.id });
```

---

## 3. BUGS

### 3.1 Blocker

#### TS-BUG-01 — await faltante en async
**Severidad**: Blocker
```typescript
// FAIL Noncompliant
async function save(user: User) {
  userRepository.save(user); // Falta await — no espera resultado
}

// OK Compliant
async function save(user: User) {
  await userRepository.save(user);
}
```

#### TS-BUG-02 — Promise sin catch en top-level
**Severidad**: Blocker
```typescript
// FAIL Noncompliant
fetchData(); // Promise sin manejar rechazo

// OK Compliant
fetchData().catch(handleError);
// O en async context:
await fetchData();
```

### 3.2 Critical

#### TS-BUG-03 — Comparación con == en vez de ===
**Severidad**: Critical (eqeqeq)
```typescript
// FAIL Noncompliant
if (value == null) { }  // Permite undefined también
if (status == 200) { }  // Type coercion

// OK Compliant
if (value === null || value === undefined) { }
if (status === 200) { }
```

#### TS-BUG-04 — Uso de any
**Severidad**: Critical (@typescript-eslint/no-explicit-any)
```typescript
// FAIL Noncompliant
function process(data: any): any { }

// OK Compliant
function process(data: unknown): Result<ProcessedData, ProcessError> { }
```

### 3.3 Major

#### TS-BUG-05 — Array.forEach con async
**Severidad**: Major
```typescript
// FAIL Noncompliant — forEach no espera async
items.forEach(async (item) => { await process(item); });

// OK Compliant
await Promise.all(items.map(item => process(item)));
// O secuencial:
for (const item of items) { await process(item); }
```

#### TS-BUG-06 — Optional chaining sin nullish coalescing
**Severidad**: Major
```typescript
// FAIL Noncompliant
const name = user?.name || 'default'; // Falla con string vacío

// OK Compliant
const name = user?.name ?? 'default';
```

---

## 4. CODE SMELLS

### 4.1 Critical

#### TS-SMELL-01 — Complejidad cognitiva alta (> 15)
**Severidad**: Critical (sonarjs/cognitive-complexity)

#### TS-SMELL-02 — Función con más de 4 parámetros
**Severidad**: Critical
```typescript
// FAIL Noncompliant
function createUser(name: string, email: string, age: number, role: string, dept: string) { }

// OK Compliant
interface CreateUserDto { name: string; email: string; age: number; role: string; dept: string; }
function createUser(dto: CreateUserDto) { }
```

### 4.2 Major

#### TS-SMELL-03 — Variables no usadas
**Severidad**: Major (@typescript-eslint/no-unused-vars)

#### TS-SMELL-04 — Código comentado
**Severidad**: Major — el código está en Git si se necesita

#### TS-SMELL-05 — Type assertion innecesaria
```typescript
// FAIL Noncompliant
const user = getUser() as User; // Si getUser ya retorna User

// OK Compliant — dejar que TypeScript infiera
const user = getUser();
```

#### TS-SMELL-06 — Imports no usados
**Severidad**: Major (@typescript-eslint/no-unused-imports)

---

## 5. REGLAS DE ARQUITECTURA

#### TS-ARCH-01 — Domain no depende de Infrastructure
**Severidad**: Blocker
```typescript
// FAIL Noncompliant — domain/ importa de infrastructure/
import { PrismaClient } from '@prisma/client'; // En domain/

// OK Compliant — domain/ solo define interfaces
export interface UserRepository {
  findById(id: string): Promise<User | null>;
}
```

#### TS-ARCH-02 — Application solo depende de Domain
**Severidad**: Critical

#### TS-ARCH-03 — Controllers sin lógica de negocio
**Severidad**: Major
```typescript
// FAIL Noncompliant
router.post('/users', async (req, res) => {
  if (await userRepo.findByEmail(req.body.email)) throw new ConflictError();
  const user = new User(req.body);
  await userRepo.save(user);
  await emailService.sendWelcome(user);
  res.json(user);
});

// OK Compliant
router.post('/users', async (req, res) => {
  const result = await createUserUseCase.execute(req.body);
  res.json(result);
});
```

#### TS-ARCH-04 — No instanciar servicios con new
**Severidad**: Critical

#### TS-ARCH-05 — No exponer ORM fuera de Infrastructure
**Severidad**: Critical — PrismaClient solo en infrastructure/

#### TS-ARCH-06 — Async completo, sin .then() mixing
**Severidad**: Major

#### TS-ARCH-07 — Interfaces en domain/, implementaciones en infrastructure/
**Severidad**: Major

---

---

## Frameworks y Herramientas Operacionales

### Backend
- **NestJS**: módulos, controllers, services, guards, interceptors, pipes, DTOs con class-validator
- **Express/Fastify**: router modular por feature, middleware tipado, validación con Zod/Joi

### ORM
- **Prisma**: schema declarativo (`schema.prisma`), migraciones con `npx prisma migrate dev`, nunca modificar migraciones aplicadas
- **TypeORM** o **Drizzle**: alternativas type-safe

### Testing
- Framework: **Vitest** (preferido) o Jest
- Unit: `tests/unit/` o `src/**/__tests__/`
- Integration: `tests/integration/`
- Naming: `describe('ServiceName')` → `it('should {behavior} when {condition}')`
- Fixtures: `vi.mock()` (Vitest) o `jest.mock()`
- Coverage: ≥ 80%

## Referencia rápida de severidades

| Severidad | Acción | Bloquea merge |
|---|---|---|
| **Blocker** | Corregir inmediatamente | OK Sí |
| **Critical** | Corregir antes de merge | OK Sí |
| **Major** | Corregir en el sprint actual | WARN Depende |
| **Minor** | Backlog técnico | FAIL No |

## HTTP QUERY (RFC 10008)

Ver `docs/rules/domain/http-query-method.md`.
