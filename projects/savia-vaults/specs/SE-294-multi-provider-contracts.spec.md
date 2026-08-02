# Spec: SE-294 — Multi-Provider Proxy + Shared Contracts

**Task ID:**        SE-294
**PBI padre:**      SE-294 — Multi-provider integration (ADR-012)
**Sprint:**         2026-08
**Fecha creacion:** 2026-08-02
**Creado por:**     Savia (arquitectura)

**Developer Type:** agent-single
**Asignado a:**     typescript-developer
**Estado:**         Pendiente

**Effort Estimation (Dual Model):**

| Dimension | Value |
|---|---|
| Agent effort | 45 min |
| Human effort | 2 h |
| Review effort | 15 min |
| Context risk | low |
| Agent-capable | yes |
| Fallback | Si agente falla: humano necesita 1h desde cero |

---

## 1. Contexto y Objetivo

Savia opera hoy con DeepSeek v4-pro como unico proveedor de inferencia.
ADR-012 establece la estrategia multi-proveedor (DeepSeek, Claude, Qwen)
con failover entre ellos. Ademas, el analisis de ai-form-creator revelo
dos patrones adicionales que Savia deberia adoptar:

1. **Shared contracts package**: Tipos TypeScript compartidos entre SaviaVaults
   y sus consumidores (MCP clients, A2A clients, frontends). Evita duplicacion
   de tipos y divergencia entre cliente y servidor.
2. **Multi-provider proxy**: Capa de abstraccion sobre providers LLM que
   enruta peticiones segun tier (heavy/mid/fast) con failover entre proveedores.

Objetivo: SaviaVaults expone un contrato tipado, y Savia puede usar cualquier
proveedor LLM sin cambiar codigo.

---

## 2. Contrato Tecnico

### 2.1 Contracts Package

```typescript
// packages/contracts/src/index.ts — Re-exporta todo

// Entidades del knowledge layer
export { Note, NoteFrontmatter, NoteWithContent } from './entities/note.js';
export { Entity, EntityType } from './entities/entity.js';
export { SearchResult, SearchQuery } from './entities/search.js';
export { VaultConfig, DomeConfig } from './entities/config.js';

// Contratos de API (MCP tools params/returns)
export { VaultReadParams, VaultReadResult } from './api/read.js';
export { VaultWriteParams, VaultWriteResult } from './api/write.js';
export { VaultSearchParams, VaultSearchResult } from './api/search.js';
export { VaultListParams, VaultListResult } from './api/list.js';

// Contratos de provider LLM
export { LlmProvider, LlmRequest, LlmResponse, ProviderTier } from './providers/types.js';
export { ProviderRouter, ProviderRouterConfig } from './providers/router.js';
```

### 2.2 Proveedor Multi-Modelo

```typescript
// src/providers/types.ts
export type ProviderTier = 'heavy' | 'mid' | 'fast';

export interface LlmRequest {
  tier: ProviderTier;
  messages: { role: 'system' | 'user' | 'assistant'; content: string }[];
  temperature?: number;
  maxTokens?: number;
}

export interface LlmResponse {
  content: string;
  provider: string;
  tier: ProviderTier;
  tokensUsed: number;
  latencyMs: number;
}

export interface LlmProvider {
  readonly name: string;
  readonly tiers: ProviderTier[];
  complete(request: LlmRequest): Promise<LlmResponse>;
  healthCheck(): Promise<boolean>;
}
```

### 2.3 Provider Router con Failover

```typescript
// src/providers/router.ts
export class ProviderRouter {
  constructor(config: ProviderRouterConfig);

  // Enruta a provider disponible segun tier, con fallback entre providers
  async complete(request: LlmRequest): Promise<LlmResponse>;

  // Chequea salud de todos los providers
  async healthCheck(): Promise<Record<string, boolean>>;

  // Proveedor actualmente activo por tier
  activeProvider(tier: ProviderTier): string;
}

export interface ProviderRouterConfig {
  providers: LlmProvider[];
  fallbackOrder: ProviderTier[]; // ['heavy', 'mid', 'fast']
  healthCheckIntervalMs: number;
}
```

### 2.4 Implementaciones concretas

```typescript
// src/providers/deepseek.ts
export class DeepSeekProvider implements LlmProvider {
  readonly name = 'deepseek';
  readonly tiers: ProviderTier[] = ['heavy', 'mid', 'fast'];
  // Usa OPENROUTER_API_KEY o DEEPSEEK_API_KEY
}

// src/providers/anthropic.ts
export class AnthropicProvider implements LlmProvider {
  readonly name = 'claude';
  readonly tiers: ProviderTier[] = ['heavy', 'mid'];
  // Usa ANTHROPIC_API_KEY
}
```

---

## 3. Reglas de Negocio

### RB-001: Failover
Si un provider falla (timeout >30s, HTTP 5xx, rate-limit 429), el router
intenta el siguiente provider en `fallbackOrder`. Si todos fallan, devuelve
error `ALL_PROVIDERS_DOWN`.

### RB-002: Health Check
El router ejecuta health check cada `healthCheckIntervalMs` (default 30s).
Un provider unhealthy se excluye del routing hasta que recupere.

### RB-003: Tier Mapping
- `heavy` → deepseek-v4-pro, claude-opus-4
- `mid` → deepseek-v4-pro, claude-sonnet-4, qwen-max
- `fast` → deepseek-v4-pro, claude-haiku, qwen-turbo

### RB-004: Contracts as Source of Truth
Los tipos del contracts package son la fuente de verdad. SaviaVaults y sus
consumidores importan de `@savia/contracts`. Cualquier cambio en contratos
rompe build de consumidores → integridad garantizada.

### RB-005: Zero Vendor Lock-in
El codigo de Savia NUNCA referencia un provider concreto. Solo usa
`ProviderRouter.complete(request)` con `request.tier`.

---

## 4. Constraints and Limits

- Contracts package: zero runtime dependencies. Solo tipos TypeScript.
- Provider implementations: cada provider en su propio fichero.
- Secrets via variables de entorno, nunca hardcodeados.
- ProviderRouter: max 3 retries por request, timeout global 120s.
- Health check: no puede exceder 5s por provider.

---

## 5. Test Scenarios

### TC-001: Router enruta a provider disponible
```
GIVEN providers deepseek (healthy) y claude (healthy)
WHEN router.complete({ tier: 'heavy', messages: [...] })
THEN response.provider es 'deepseek' o 'claude'
AND response.tier es 'heavy'
AND response.content no esta vacio
```

### TC-002: Failover cuando primer provider falla
```
GIVEN deepseek unhealthy, claude healthy
WHEN router.complete({ tier: 'heavy', messages: [...] })
THEN no usa deepseek
AND response.provider es 'claude'
```

### TC-003: ALL_PROVIDERS_DOWN cuando todos fallan
```
GIVEN todos los providers unhealthy
WHEN router.complete({ tier: 'heavy', messages: [...] })
THEN lanza error con codigo ALL_PROVIDERS_DOWN
```

### TC-004: Contracts exportan todos los tipos necesarios
```
GIVEN packages/contracts compilado
WHEN typescript-developer importa Note, SearchResult, VaultReadParams
THEN todos los tipos estan disponibles y son correctos
```

### TC-005: Health check recupera provider caido
```
GIVEN deepseek unhealthy
WHEN deepseek recupera (health check OK)
THEN router incluye deepseek en siguiente routing
```

### TC-006: Contracts import no introduce runtime deps
```
GIVEN packages/contracts instalado en proyecto consumidor
WHEN se hace build del consumidor
THEN el bundle no incluye codigo runtime de contracts
AND solo incluye los tipos usados
```

---

## 6. Ficheros a Crear/Modificar

### Crear

| Fichero | Proposito |
|---|---|
| `projects/savia-vaults/packages/contracts/package.json` | Package config |
| `projects/savia-vaults/packages/contracts/tsconfig.json` | TS config |
| `projects/savia-vaults/packages/contracts/src/index.ts` | Re-exports |
| `projects/savia-vaults/packages/contracts/src/entities/note.ts` | Note types |
| `projects/savia-vaults/packages/contracts/src/entities/entity.ts` | Entity types |
| `projects/savia-vaults/packages/contracts/src/entities/search.ts` | Search types |
| `projects/savia-vaults/packages/contracts/src/entities/config.ts` | Config types |
| `projects/savia-vaults/packages/contracts/src/api/read.ts` | Read API |
| `projects/savia-vaults/packages/contracts/src/api/write.ts` | Write API |
| `projects/savia-vaults/packages/contracts/src/api/search.ts` | Search API |
| `projects/savia-vaults/packages/contracts/src/api/list.ts` | List API |
| `projects/savia-vaults/packages/contracts/src/providers/types.ts` | Provider types |
| `projects/savia-vaults/packages/contracts/src/providers/router.ts` | Router interface |
| `projects/savia-vaults/src/providers/types.ts` | Provider impl types |
| `projects/savia-vaults/src/providers/router.ts` | Router implementation |
| `projects/savia-vaults/src/providers/deepseek.ts` | DeepSeek provider |
| `projects/savia-vaults/src/providers/anthropic.ts` | Anthropic provider |
| `projects/savia-vaults/src/providers/index.ts` | Barrel export |
| `projects/savia-vaults/tests/unit/providers/router.test.ts` | Router tests |
| `projects/savia-vaults/tests/unit/providers/deepseek.test.ts` | Provider tests |

### Modificar

| Fichero | Cambio |
|---|---|
| `projects/savia-vaults/package.json` | Referencia a contracts workspace |
| `projects/savia-vaults/tsconfig.json` | Path alias a contracts |

---

## 7. Codigo de Referencia

### Patron: Router Pattern (inspirado en LiteLLM)
```typescript
// Patron de routing con failover y health check
// Referencia: https://github.com/BerriAI/litellm
// Principio: abstraer N providers tras una interfaz unica
```

### Patron: Contracts Package (inspirado en ai-form-creator)
```typescript
// Monorepo con /packages/contracts como fuente unica de tipos
// Referencia: https://github.com/FernandoDSanchez/ai-form-creator
// packages/contracts/src/ tiene tipos puros, sin implementacion
```

---

## 8. OpenCode Implementation Plan

> **Spec classification**: `infrastructure` — new project infrastructure, no existing code to break.
> **Required agents**: typescript-developer
> **Prerequisites**: Node.js 22+, SaviaVaults v0.3.0 workspace

### Implementation sequence

1. Create `packages/contracts/` with package.json, tsconfig.json, and all type files
2. Build contracts package, verify types export correctly
3. Create `src/providers/` module in SaviaVaults
4. Implement ProviderRouter with health check and failover
5. Implement DeepSeekProvider and AnthropicProvider
6. Write unit tests for router and providers
7. Run `npm test` in SaviaVaults, verify all pass

### Context budget
- Contracts: 8 type-only files (~200 lines total) → 3K tokens
- Providers: 4 implementation files (~300 lines total) → 5K tokens
- Tests: 2 test files (~150 lines total) → 2K tokens
- Total: ~10K tokens (within mid-tier budget)

---

## 9. Estado de Implementacion

| Slice | Estado | Fecha | Commits |
|---|---|---|---|
| S1: Contracts package | Pendiente | — | — |
| S2: Provider router | Pendiente | — | — |
| S3: Provider implementations | Pendiente | — | — |
| S4: Tests | Pendiente | — | — |

---

## 10. Checklist Pre-Entrega

- [ ] Contracts package compila sin errores (tsc --noEmit)
- [ ] Todos los tipos exportados desde index.ts
- [ ] ProviderRouter pasa tests de failover
- [ ] DeepSeekProvider y AnthropicProvider pasan health check test
- [ ] 0 errores de lint
- [ ] npm test en SaviaVaults: todos los tests existentes siguen pasando
- [ ] Secrets nunca hardcodeados (solo env vars)

---

## 11. Criterios de Aceptacion

- [ ] AC1: Existe `packages/contracts/` con tipos TypeScript exportables
- [ ] AC2: `import { Note, SearchResult } from '@savia/contracts'` funciona
- [ ] AC3: ProviderRouter enruta peticiones a provider healthy
- [ ] AC4: Failover funciona: si provider A falla, usa provider B
- [ ] AC5: ALL_PROVIDERS_DOWN cuando ningun provider responde
- [ ] AC6: Health check recupera providers caidos automaticamente
- [ ] AC7: Contracts package no introduce runtime dependencies

---

## 12. Iteration & Convergence Criteria

- S1: Contracts compila, `npm pack` produce .tgz instalable
- S2: Router pasa TC-001, TC-002, TC-003
- S3: Al menos 2 providers implementados (DeepSeek, Anthropic)
- S4: 80%+ cobertura en providers module
