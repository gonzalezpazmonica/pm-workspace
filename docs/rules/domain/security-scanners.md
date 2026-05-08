# Security Scanners — catálogo y uso

> Inventario de scanners de seguridad del workspace. Complementa Savia Shield + PII + confidentiality stack.

## Stack completo

| Scanner | Target | Reglas | Script |
|---|---|---|---|
| Savia Shield (NER) | output agentes, PII | ES/EN NER | `scripts/shield-ner-*` |
| Confidentiality sign | commits | repo-wide gitignored leak | `scripts/confidentiality-sign.sh` |
| Pre-commit sovereignty | staged diff | sensitive patterns | `scripts/pre-commit-sovereignty.sh` |
| Prompt security (PS-01..PS-14) | agent/skill md | 14 reglas prompt injection + hidden | `scripts/prompt-security-scan.sh` |
| MCP security (SE-058) | `.claude/mcp.json` | 11 reglas supply chain + auto-approve | `scripts/mcp-security-audit.sh` |
| MCP templates (SE-061) | `.claude/mcp-templates/` | entries opt-in + pasos de activación auditados | revisión manual + `mcp-security-audit.sh` post-activación |
| Permissions wildcard (SE-059) | settings.json | 8 reglas wildcard sin deny | `scripts/permissions-wildcard-audit.sh` |
| Hook injection (SE-060) | `.opencode/hooks/` | 9 reglas injection + exfil | `scripts/hook-injection-audit.sh` |

## PS rules (prompt-security-scan.sh)

| ID | Detecta | Sev | Origen |
|---|---|---|---|
| PS-01 | Injection bait (ignore previous, override instructions) | CRIT | SPEC-176 |
| PS-02 | Prompt exfiltration (reveal system prompt) | CRIT | SPEC-176 |
| PS-03 | Role hijack (you are now X) | HIGH | SPEC-176 |
| PS-04 | Data exfil via curl/wget a external URL | HIGH | SPEC-176 |
| PS-05 | Hardcoded credential in prompt | CRIT | SPEC-176 |
| PS-06 | Code execution pattern (eval/exec) | HIGH | SPEC-176 |
| PS-07 | Base64 blob (warn) | WARN | SPEC-176 |
| PS-08 | Email PII (warn) | WARN | SPEC-176 |
| PS-09 | Agent sin model | WARN | SPEC-176 |
| PS-10 | Agent tools:* wildcard | WARN | SPEC-176 |
| **PS-11** | Zero-width char (U+200B/C/D/FEFF) | HIGH | SE-060 |
| **PS-12** | Long base64 string >80c | HIGH | SE-060 |
| **PS-13** | curl/wget piped to shell | HIGH | SE-060 |
| **PS-14** | Time-based conditional (time bomb) | HIGH | SE-060 |

## MCP rules (mcp-security-audit.sh)

SE-058. Inspiradas en agentshield (MIT). MCP-01..MCP-11 — supply chain, auto-approve, secrets hardcoded, shell transport, remote sin auth, metacaracteres, paths sensibles, path traversal, bash raw, PATH override, metadata ausente.

## PERM rules (permissions-wildcard-audit.sh)

SE-059. PERM-01..PERM-08 — wildcard Bash/Write/WebFetch sin deny, defaultMode auto+skip prompts, missing deny con wildcards, destructive commands en allow, curl POST sin allowlist, malformed JSON.

## HOOK rules (hook-injection-audit.sh)

SE-060. HOOK-01..HOOK-09 — eval unquoted, curl POST exfil, pipe-to-shell, silent error suppression, reverse shell /dev/tcp, sudo sin -n, redirect a SSH/auth files, unquoted $() en comandos críticos, rm sin validación.

## CI integration

```yaml
# .github/workflows/security-audit.yml (sketch)
- run: bash scripts/prompt-security-scan.sh .claude/agents
- run: bash scripts/prompt-security-scan.sh .claude/skills
- run: bash scripts/mcp-security-audit.sh
- run: bash scripts/permissions-wildcard-audit.sh
- run: bash scripts/hook-injection-audit.sh
```

Todos emiten `--json` para agregación en dashboard. Exit 0/1/2 consistentes.

## Referencias

- SE-058 MCP audit: `docs/propuestas/SE-058-mcp-security-audit.md`
- SE-059 Permissions: `docs/propuestas/SE-059-permissions-wildcard-audit.md`
- SE-060 Hook injection: `docs/propuestas/SE-060-hook-injection-hidden-directives.md`
- Research agentshield: `output/research/agentshield-20260420.md` (MIT)
- SPEC-176 (PS rules): `docs/propuestas/SPEC-176-prompt-security-scanner.md`
