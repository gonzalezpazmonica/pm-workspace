# Command: cache-optimize

Analiza el orden actual de contexto y sugiere reordenamiento para optimizar cache hits.

## Usage

```
/cache-optimize {project-name}
```

## Prerequisites

- Project debe existir en `projects/{project}`
- Archivos: CLAUDE.md, reglas-negocio.md, equipo.md
- Permiso de lectura en project directory

## Analysis

1. **Context Load Audit**
   - Identifica archivos en orden de carga actual
   - Mide tamaño de cada archivo (tokens aproximados)
   - Identifica cuáles pueden cachéarse

2. **Cache Eligibility Check**
   - ✓ Stable: CLAUDE.md, reglas-negocio.md, equipo.md
   - ✓ Moderado: Skill CLAUDE.md, task templates
   - ✗ Dynamic: User requests, conversation

3. **Current Order Analysis**
   - Tokens antes de optimización
   - Cache hit probability actual
   - Detect "thrashing"

4. **Recommended Reordering**
   - Ordena por estabilidad (Level 1→4)
   - Propone cache_control placement
   - Calcula tokens después optimización

5. **Token Savings Estimate**
   - Tokens de input normal
   - Tokens cacheados (90% descuento)
   - Ahorro estimado en porcentaje

## Output Example

```
═════════════════════════════════════════════
CACHE OPTIMIZATION ANALYSIS: {project-name}
═════════════════════════════════════════════

📊 CURRENT STATE
├─ Level 1 (PM Foundation): 200 tokens
├─ Level 2 (Project): 500 tokens
├─ Level 3 (Skills): 300 tokens
└─ Level 4 (Dynamic): 150 tokens

💾 CACHE IMPACT
├─ Current hit probability: 45%
├─ Cacheable tokens: 1000
└─ Dynamic tokens: 150

✅ RECOMMENDATIONS
├─ Reorder cache_control placement
├─ Level 2+3 hits in sequential ops
└─ Expected improvement: 65%

💰 TOKEN SAVINGS
├─ Before: 1000 tokens/request
├─ After: 300 tokens/request
└─ Savings: 70%
```

## Examples

```
/cache-optimize sala-reservas
/cache-optimize ecommerce-platform
```
