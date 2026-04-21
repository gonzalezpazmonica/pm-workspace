---
id: SE-060
title: SE-060 — Hook Injection + Hidden Directives Audit
status: PROPOSED
origin: output/research/agentshield-20260420.md (inspired by 34 hook + 25 agent rules)
author: Savia
priority: Alta
effort: M 6h
gap_link: Hook command-injection + zero-width/base64 directives no detectados
approved_at: null
applied_at: null
expires: "2026-05-20"
---

# SE-060 — Hook Injection + Hidden Directives Audit

## Purpose

Dos gaps complementarios del research agentshield:

**A. Hook injection patterns**: nuestros 57 hooks en `.claude/hooks/*.sh` no se auditan contra command injection via variable interpolation (`"$VAR"` en lugar de `"${VAR@Q}"`), exfiltration (`curl -X POST ... $SECRET`), silent error suppression (`2>/dev/null ||:`), o reverse shell patterns. `block-credential-leak.sh` solo cubre el output staged.

**B. Hidden directives en agent/skill markdown**: el `prompt-security-scan.sh` (PS-01..PS-10) no detecta:
- Zero-width chars (`\u200B`, `\u200C`, `\u200D`, `\uFEFF`)
- Base64-encoded directives en bloques de código
- URL execution patterns (`curl https://... | bash`)
- Time bombs (`if [ $(date +%s) -gt X ]`)
- Jailbreak patterns clásicos ("ignore previous", "DAN mode")

Cost of inaction: un hook comprometido ejecuta en cada tool call. Un prompt injection oculto puede reactivarse tras merge.

## Scope (Slice 1)

**Script 1**: `scripts/hook-injection-audit.sh`
- Audita `.claude/hooks/*.sh` + hooks referenciados en `settings.json`
- Patrones inyección + exfiltration + silent-suppress
- 9 reglas (HOOK-01..HOOK-09)

**Script 2**: extender `scripts/prompt-security-scan.sh` con PS-11..PS-14
- PS-11: Zero-width chars en agent/skill markdown
- PS-12: Base64-encoded long strings sospechosas
- PS-13: URL-pipe-bash patterns
- PS-14: Time-bomb conditionals

## Reglas nuevas

**Hook audit (9)**:
| ID | Rule | Severity |
|---|---|---|
| HOOK-01 | `eval` con variable no-quoted | CRITICAL |
| HOOK-02 | `curl -X POST` con variable interpolation (exfil) | HIGH |
| HOOK-03 | `bash <(curl ...)` o `curl ... \| bash` | CRITICAL |
| HOOK-04 | `2>/dev/null \|\|` ocultando errores críticos | MEDIUM |
| HOOK-05 | Reverse shell pattern (`/dev/tcp/`) | CRITICAL |
| HOOK-06 | `sudo` sin `-n` (requiere TTY) | HIGH |
| HOOK-07 | Redirect a socket/pipe en `$HOME/.ssh/` | CRITICAL |
| HOOK-08 | Unquoted `$()` en comandos críticos | HIGH |
| HOOK-09 | `rm -rf $VAR` sin validación | HIGH |

**Prompt scan extension (PS-11..PS-14)**:
| ID | Rule | Severity |
|---|---|---|
| PS-11 | Zero-width chars en frontmatter/body | HIGH |
| PS-12 | Base64 >80 chars sospechoso | MEDIUM |
| PS-13 | URL-pipe-bash execution | HIGH |
| PS-14 | Time-based conditional (time bomb) | MEDIUM |

## Acceptance criteria

- `scripts/hook-injection-audit.sh` ejecutable, `--help`, `--json`, exit 0/1/2
- `scripts/prompt-security-scan.sh` extendido con PS-11..PS-14 manteniendo backward compat
- Tests BATS ≥ 20 hook-injection + 10 prompt-scan-hidden
- Score auditor ≥ 80
- Zero egress

## Referencias

- `output/research/agentshield-20260420.md` (inspiración 34+25 reglas)
- `scripts/prompt-security-scan.sh` (existente, 10 reglas)
- `.claude/hooks/block-credential-leak.sh` (complementario)
- `.claude/hooks/` 57 scripts (target)
