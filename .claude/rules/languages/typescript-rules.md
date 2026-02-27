---
paths:
  - "**/*.ts"
  - "**/*.mts"
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
// ❌ Noncompliant
const API_KEY = "sk-1234567890abcdef";
const dbUrl = "postgresql://user:password@host/db";

// ✅ Compliant
const API_KEY = process.env.API_KEY!;
const dbUrl = process.env.DATABASE_URL!;
```

#### TS-SEC-02 — SQL Injection
**Severidad**: Blocker
```typescript
// ❌ Noncompliant
const query = `SELECT * FROM users WHERE id = ${userId}`;
await db.$queryRawUnsafe(query);

// ✅ Compliant
const user = await db.user.findUnique({ where: { id: userId } });
// O con query parametrizada:
await db.$queryRaw`SELECT * FROM users WHERE id = ${userId}`;
```

#### TS-SEC-03 — Command Injection
**Severidad**: Blocker
```typescript
// ❌ Noncompliant
exec(`ls ${userInput}`);

// ✅ Compliant
execFile('ls', [sanitizedPath]);
```

#### TS-SEC-04 — Path Traversal
**Severidad**: Blocker
```typescript
// ❌ Noncompliant
const filePath = path.join('/uploads', req.params.filename);

// ✅ Compliant
const filePath = path.join('/uploads', path.basename(req.params.filename));
if (!filePath.startsWith('/uploads')) throw new ForbiddenError();
```

### 1.2 Critical

#### TS-SEC-05 — XSS en respuestas HTML
**Severidad**: Critical
```typescript
// ❌ Noncompliant
res.send(`<h1>${userInput}</h1>`);

// ✅ Compliant — usar template engine con auto-escaping o sanitizar
res.send(`<h1>${escapeHtml(userInput)}</h1>`);
```

#### TS-SEC-06 — JWT sin verificación
**Severidad**: Critical
```typescript
// ❌ Noncompliant
const decoded = jwt.decode(token); // No verifica firma

// ✅ Compliant
const decoded = jwt.verify(token, secret);
```

#### TS-SEC-07 — Prototype Pollution
**Severidad**: Critical
```typescript
// ❌ Noncompliant
Object.assign(target, JSON.parse(userInput));

// ✅ Compliant
const safe = Object.create(null);
Object.assign(safe, JSON.parse(userInput));
```

#### TS-SEC-08 — Cookies sin flags de seguridad
**Severidad**: Critical
```typescript
// ❌ Noncompliant
res.cookie('session', token);

// ✅ Compliant
res.cookie('session', token, { httpOnly: true, secure: true, sameSite: 'strict' });
```

### 1.3 Major

#### TS-SEC-09 — CORS permisivo
**Severidad**: Major
```typescript
// ❌ Noncompliant
app.use(cors({ origin: '*' }));

// ✅ Compliant
app.use(cors({ origin: ['https://trusted.com'], credentials: true }));
```

#### TS-SEC-10 — Sin rate limiting
**Severidad**: Major
```typescript
// ✅ Compliant — aplicar rate limiting a endpoints públicos
app.use('/api/auth', rateLimit({ windowMs: 15 * 60 * 1000, max: 100 }));
```

---

## 2. SECURITY HOTSPOTS

#### TS-HOT-01 — eval() o Function()
```typescript
// ❌ Sensitive
eval(userInput);
new Function(userInput)();
```

#### TS-HOT-02 — Regex sin límite (ReDoS)
```typescript
// ❌ Sensitive
new RegExp(userInput); // Sin sanitizar

// ✅ Compliant
import { escapeRegExp } from 'lodash';
new RegExp(escapeRegExp(userInput));
```

#### TS-HOT-03 — Logging de datos sensibles
```typescript
// ❌ Sensitive
logger.info('User login', { password: user.password });

// ✅ Compliant
logger.info('User login', { userId: user.id });
```

---

## 3. BUGS

### 3.1 Blocker

#### TS-BUG-01 — await faltante en async
**Severidad**: Blocker
```typescript
// ❌ Noncompliant
async function save(user: User) {
  userRepository.save(user); // Falta await — no espera resultado
}

// ✅ Compliant
async function save(user: User) {
  await userRepository.save(user);
}
```

#### TS-BUG-02 — Promise sin catch en top-level
**Severidad**: Blocker
```typescript
// ❌ Noncompliant
fetchData(); // Promise sin manejar rechazo

// ✅ Compliant
fetchData().catch(handleError);
// O en async context:
await fetchData();
```

### 3.2 Critical

#### TS-BUG-03 — Comparación con == en vez de ===
**Severidad**: Critical (eqeqeq)
```typescript
// ❌ Noncompliant
if (value == null) { }  // Permite undefined también
if (status == 200) { }  // Type coercion

// ✅ Compliant
if (value === null || value === undefined) { }
if (status === 200) { }
```

#### TS-BUG-04 — Uso de any
**Severidad**: Critical (@typescript-eslint/no-explicit-any)
```typescript
// ❌ Noncompliant
function process(data: any): any { }

// ✅ Compliant
function process(data: unknown): Result<ProcessedData, ProcessError> { }
```

### 3.3 Major

#### TS-BUG-05 — Array.forEach con async
**Severidad**: Major
```typescript
// ❌ Noncompliant — forEach no espera async
items.forEach(async (item) => { await process(item); });

// ✅ Compliant
await Promise.all(items.map(item => process(item)));
// O secuencial:
for (const item of items) { await process(item); }
```

#### TS-BUG-06 — Optional chaining sin nullish coalescing
**Severidad**: Major
```typescript
// ❌ Noncompliant
const name = user?.name || 'default'; // Falla con string vacío

// ✅ Compliant
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
// ❌ Noncompliant
function createUser(name: string, email: string, age: number, role: string, dept: string) { }

// ✅ Compliant
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
// ❌ Noncompliant
const user = getUser() as User; // Si getUser ya retorna User

// ✅ Compliant — dejar que TypeScript infiera
const user = getUser();
```

#### TS-SMELL-06 — Imports no usados
**Severidad**: Major (@typescript-eslint/no-unused-imports)

---

## 5. REGLAS DE ARQUITECTURA

#### TS-ARCH-01 — Domain no depende de Infrastructure
**Severidad**: Blocker
```typescript
// ❌ Noncompliant — domain/ importa de infrastructure/
import { PrismaClient } from '@prisma/client'; // En domain/

// ✅ Compliant — domain/ solo define interfaces
export interface UserRepository {
  findById(id: string): Promise<User | null>;
}
```

#### TS-ARCH-02 — Application solo depende de Domain
**Severidad**: Critical

#### TS-ARCH-03 — Controllers sin lógica de negocio
**Severidad**: Major
```typescript
// ❌ Noncompliant
router.post('/users', async (req, res) => {
  if (await userRepo.findByEmail(req.body.email)) throw new ConflictError();
  const user = new User(req.body);
  await userRepo.save(user);
  await emailService.sendWelcome(user);
  res.json(user);
});

// ✅ Compliant
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

## Referencia rápida de severidades

| Severidad | Acción | Bloquea merge |
|---|---|---|
| **Blocker** | Corregir inmediatamente | ✅ Sí |
| **Critical** | Corregir antes de merge | ✅ Sí |
| **Major** | Corregir en el sprint actual | 🟡 Depende |
| **Minor** | Backlog técnico | ❌ No |
