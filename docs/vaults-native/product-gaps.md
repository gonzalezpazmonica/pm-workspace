# Product Gaps — SaviaVaults v0.2.0 (SE-290 S7)

Date: 2026-08-01
Source: Self-hosting Savia on SaviaVaults

## Gaps found

### GAP-01: No multi-vault server
A single `serve` process serves one vault. Savia has 5 vaults.
Fix in product: multi-vault MCP server (SE-281 GAP-01)
Classification: fix in product

### GAP-02: SchemaDir not resolved from config
`schema_dir` is declared in config/vaults.yaml but CLI `--schema` flag
must be passed manually. Config file not read by servers.
Fix in product: load schema_dir from savia-vaults.config.json
Classification: fix in product

### GAP-03: Introspect needs build first
`vault_introspect` requires TypeScript build. Should work from npm
global install without build step.
Fix in product: ship pre-built dist/ in npm package
Classification: fix in product

### GAP-04: No vault create from config
`vaults.yaml` declares vaults but `init` must be called manually.
Fix in product: `savia-vaults init --from-config config/vaults.yaml`
Classification: fix in product

### GAP-05: Freshness check needs manual git
`vaults-freshness.sh` uses `git log` directly. Should use
`vault_stats` which already returns commit count.
Fix in Savia: bridge script already wraps correctly
Classification: resolve in Savia

### GAP-06: Graph requires vault with typed entities
KnowledgeGraph only builds from entities with `entity: {type, id}`.
Untyped documents are invisible to the graph.
Fix in product: optional entity inference from content patterns
Classification: fix in product (future)

## Metrics from self-hosting

- Vaults declared: 5
- Documents indexed: 11 in SaviaLabs, ~1000 in savia-docs
- Build time: <2s for full project
- Introspect latency: <50ms for SaviaLabs (3 docs)
- Search latency: <10ms for SaviaLabs

## Learnings

1. The schema system works but adoption requires discipline
2. Config file should be the single source of truth for vault setup
3. npm global install should Just Work without build steps
4. Multi-vault support is needed for any real deployment
