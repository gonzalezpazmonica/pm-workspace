# Security Guardian — Persistent Memory

> Security vulnerability patterns, false positives, and project-specific exclusions.

## Discovered Patterns

| Date | Pattern | Context | Source |
|---|---|---|---|
| 2026-03-03 | Connection strings in config must reference vault (Key Vault/SSM) — never embed secrets | Pre-commit security check | Security-check-patterns.md, SEC-1 |
| 2026-03-02 | Hardcoded IPs (192.168.*, 10.*) must be excluded — use DNS names or config | Infrastructure, network config | False positive: development docker-compose.yml |
| 2026-03-01 | Email patterns must exclude @example.com, @company-test.com — only flag real corporate domains | Regex pattern tuning | PII-sanitization.md |

