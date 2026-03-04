# /memory-stats

> View memory store health: counts, tokens, read/write ratio

```frontmatter
agent: task
model: haiku
context_cost: low
```

## Process

```bash
bash "$PROJECT_ROOT/scripts/memory-store.sh" stats
```

## Output Format

Shows:
- **Total entries** — cumulative count
- **By type** — breakdown of decision|bug|pattern|convention|discovery
- **By concept** — top tags extracted from entries
- **Estimated tokens** — sum of tokens_est field

Example output:

```
📊 Estadísticas — Total: 47 entradas
Por tipo:
  decision: 12
  pattern: 18
  bug: 8
  convention: 5
  discovery: 4
Por concepto:
  testing: 8
  ci: 6
  bash: 5
  schema: 4
  performance: 3
```

## Use Cases

- **Health check:** Are we capturing enough? (< 10 entries = sparse memory)
- **Concept bias:** Which themes dominate?
- **Token efficiency:** Estimate context overhead if loaded all

## Recommendations

- **Write ratio:** 2-3 new entries per sprint is healthy
- **Concept spread:** >5 different concepts = good diversity
- **Token efficiency:** If > 1000 tokens total, consider archiving old entries
