### Added — Batch 10 (Security stack hardening)

**3 scripts + 3 BATS suites (78 tests, certified)**:
- `scripts/mcp-security-audit.sh` (SE-058) — 11 reglas MCP supply chain.
- `scripts/permissions-wildcard-audit.sh` (SE-059) — 8 reglas wildcard permissions.
- `scripts/hook-injection-audit.sh` (SE-060) — 9 reglas hook injection.

**Extension**:
- `scripts/prompt-security-scan.sh`: PS-11..PS-14 (zero-width chars, base64, URL-pipe-shell, time bombs).

**Docs**:
- `docs/rules/domain/security-scanners.md` catálogo unificado.
- 3 specs en `docs/propuestas/`.

Ref: `output/research/agentshield-20260420.md` (inspiración MIT).
