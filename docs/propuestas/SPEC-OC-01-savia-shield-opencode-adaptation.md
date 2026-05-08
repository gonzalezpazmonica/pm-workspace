# SPEC-OC-01 — Savia Shield OpenCode Adaptation

status: PROPOSED
> **Status:** DRAFT → IMPLEMENTING
> **Branch:** machine-local/monica-opencode (private, never pushed to origin/main)
> **Date:** 2026-05-04
> **Classification:** N4b (PM-Only) — contiene arquitectura de seguridad confidencial

---

## Objective

Adapt all Savia Shield and confidentiality/security protections from
Claude Code hooks to equivalent OpenCode v1.14 TS plugin guards, preserving
the 8-layer security model. The bash scripts remain functional and serve
as the canonical logic source; TS ports replicate the same semantics
under OpenCode's `tool.execute.before` and `tool.execute.after` events.

## Background

The `machine-local/monica-opencode` branch contains a complete Savia Shield
implementation (8 capas) designed for Claude Code's hook system
(`.claude/settings.json` → `.opencode/hooks/*.sh`). OpenCode v1.14 does not
execute `.opencode/hooks/*.sh` natively. Instead, it provides a TypeScript
plugin system that exposes `tool.execute.before` and `tool.execute.after`
events via `@opencode-ai/plugin`.

The `.opencode/` directory already contains:
- Foundation plugin (`savia-foundation.ts`) with 5 TIER-1 guards
- Shared libraries (`lib/`) for pattern detection
- Provider-agnostic env layer (`scripts/savia-env.sh`)

This spec defines the complete adaptation of ALL remaining security hooks.

## Architecture Decision

**Provider-agnostic by construction (PV-06)**. Guards branch on tool name
and content, never on a hardcoded vendor name. The `savia-env.sh` fallback
chain (`CLAUDE_PROJECT_DIR` → `OPENCODE_PROJECT_DIR` → `git root` → `pwd`)
is already implemented and works under OpenCode.

**Dual-stack (PV-01).** Bush hooks stay fully functional under Claude Code.
TS guards are additive under OpenCode. No regression risk.

## Adaptation Inventory

### A. Guards to Port (bash → TS)

| # | Bash Hook | OpenCode Guard | Capa | Criticality | Status |
|---|-----------|----------------|------|-------------|--------|
| 1 | `data-sovereignty-gate.sh` | `guards/data-sovereignty-gate.ts` | 1+8 | CRITICAL | IMPLEMENTING |
| 2 | `data-sovereignty-audit.sh` | `guards/data-sovereignty-audit.ts` | 5 | HIGH | IMPLEMENTING |
| 3 | `block-credential-leak.sh` | `guards/block-credential-leak.ts` | 6 | CRITICAL | EXISTS, ENHANCING |
| 4 | `block-force-push.sh` | `guards/block-force-push.ts` | 6 | HIGH | IMPLEMENTING |
| 5 | `block-gitignored-references.sh` | `guards/block-gitignored-references.ts` | — | HIGH | EXISTS |
| 6 | `prompt-injection-guard.sh` | `guards/prompt-injection-guard.ts` | — | HIGH | EXISTS |
| 7 | `validate-bash-global.sh` | `guards/validate-bash-global.ts` | — | HIGH | EXISTS |
| 8 | `tdd-gate.sh` | `guards/tdd-gate.ts` | — | MEDIUM | EXISTS |

### B. Shields that Work Without Porting

| Component | Type | OpenCode Compat? | Notes |
|-----------|------|------------------|-------|
| `savia-shield-proxy.py` (Capa 4) | HTTP proxy | YES (if provider URL set) | Works with any HTTP provider. Set `ANTHROPIC_BASE_URL` or equivalent env var |
| `savia-shield-daemon.py` (Capa 2) | Daemon | YES | HTTP endpoints on localhost:8444. Guard can call it |
| `sovereignty-mask.py` (Capa 7) | CLI tool | YES | Manual masking tool. Works anywhere |
| `ollama-classify.sh` (Capa 3) | CLI tool | YES | Local LLM. Can be called from TS guard |
| `savia-shield-status.sh` | Diagnostic | PARTIAL | Uses `CLAUDE_PROJECT_DIR`. Fix: use `SAVIA_WORKSPACE_DIR` |
| PM Radar scripts | CLI tools | YES | `savia_paths.py` already provider-agnostic |
| `project-update.py` | CLI tool | YES | Uses env vars, not Claude Code hooks |

### C. Guard Execution Order

The guards in `savia-foundation.ts` execute sequentially in this order
(based on cost and blocking semantics):

1. `validateBashGlobal` — cheap regex on bash commands (~0ms)
2. `blockCredentialLeak` — regex on bash command content (~0ms)
3. `blockForcePush` — regex on bash git commands (~0ms)
4. `dataSovereigntyGate` — regex + base64 + daemon/fallback on edit/write (~0ms-2s)
5. `blockGitignoredReferences` — regex on edit/write content (~0ms)
6. `promptInjectionGuard` — content scan on context-classified files (~0ms)
7. `tddGate` — filesystem probe (most expensive, ~10-50ms)

Throwing in any guard aborts the chain and blocks the tool execution.

## Implementation Details

### A1. `data-sovereignty-gate.ts` (Capa 1+8)

**Must replicate all logic from the bash hook:**

1. **Private destination skip**: projects/, tenants/, output/, config.local/,
   .savia/, .opencode/hooks/, tests/hooks/ NO se escanean
2. **Daemon-first gate**: si `http://127.0.0.1:8444/health` responde,
   envía POST `/gate` con el input
3. **SH01 allowlist**: si BLOCK es solo por code-like tokens en script files
   (.py, .sh, .ts, etc.), downgrade a WARN
4. **Fallback inline regex**: si daemon caído, aplicar regex local:
   - connection strings (jdbc:, mongodb+srv://)
   - AWS keys (AKIA)
   - GitHub tokens (ghp_, github_pat_)
   - OpenAI keys (sk-)
   - Azure SAS (sv=20XX-)
   - Private keys (PEM)
   - Internal IPs (RFC 1918)
5. **Cross-write detection**: combinar contenido existente + nuevo
6. **Base64 decode**: decodificar blobs >=40 chars y re-escanear
7. **NFKC normalization**: normalizar Unicode antes de aplicar regex
8. **SHA256 masking**: contenido sensible → reemplazar con hash

### A2. `data-sovereignty-audit.ts` (Capa 5)

Runs AFTER tool execution (async, non-blocking in Claude Code).
Under OpenCode, uses `tool.execute.after` event.
- Re-escanea el fichero completo en disco tras escritura
- Append-only audit log en `output/data-sovereignty-audit.jsonl`
- No bloquea el flujo (console.warn en lugar de throw)

### A3. Block Credential Leak Enhancement

Add missing patterns from the bash hook:
- `eyJhbGciOiJIUz...` pattern (general JWT added)
- `eyJhbGciOiJSUzI1NiI` — K8s service account tokens (already present)
- `sk-ant-` — Anthropic API keys (already present, must be checked first)
- `echo.*secret.*>>` — writing secrets to files
- General PAT hardcoding (already present)

### B. Shield Proxy (Capa 4)

Adaptation note: when using OpenCode with DeepSeek, the user MUST set
`DEEPSEEK_BASE_URL=http://127.0.0.1:8443` for the proxy to intercept
prompts OR the proxy must be extended to handle the provider's API format.

For this spec, we document that:
1. The proxy works unchanged for Anthropic providers
2. For DeepSeek, the proxy's request forwarding logic needs to be
   enhanced to understand the DeepSeek API format (Slice 2 of this spec)
3. Manual masking via `sovereignty-mask.py` always works regardless

### C. Script Path Fixes

All scripts that reference `CLAUDE_PROJECT_DIR` should be updated to
source `savia-env.sh` and use `SAVIA_WORKSPACE_DIR`. Priority:

1. `scripts/savia-shield-status.sh` — already sources savia-env.sh but
   uses `$PROJECT_DIR` which may be empty under OpenCode
2. `scripts/savia-shield-daemon.py` — works independently of CC/OC
3. `scripts/check-daemon-auth.sh` — works independently

## Acceptance Criteria

- [ ] AC-01: `data-sovereignty-gate.ts` blocks credential leaks in edit/write content
- [ ] AC-02: `data-sovereignty-gate.ts` skips private destinations (projects/, .savia/, etc.)
- [ ] AC-03: Base64-encoded credentials are decoded and re-scanned before block
- [ ] AC-04: `block-credential-leak.ts` detects JWT tokens, PEM keys, K8s tokens
- [ ] AC-05: `block-force-push.ts` blocks `git push --force`, direct push to main
- [ ] AC-06: `data-sovereignty-audit.ts` runs post-edit and logs to audit file
- [ ] AC-07: All guards wired into `savia-foundation.ts` in correct order
- [ ] AC-08: `savia-shield-status.sh` reports correct status under OpenCode
- [ ] AC-09: Existing 5 guards + tests continue to pass unchanged
- [ ] AC-10: TypeScript compiles without errors (`tsc --noEmit`)

## Out of Scope

- DeepSeek API proxy adaptation (Capa 4 for non-Anthropic providers) → SPEC-OC-02
- Porting all 60+ hooks → incremental, per `hook-portability-classifier.sh`
- PM Radar / Project Update adaptation → scripts work as-is
- Teams extraction pipeline → CDP-based, works regardless of frontend
- Savia Monitor dashboard → requires separate frontend project

## References

- `docs/savia-shield.md` — Savia Shield architecture (8 capas)
- `docs/rules/domain/data-sovereignty.md` — sovereignty policy
- `audit/shield/inventory.md` — shield component inventory
- `.opencode/HOOKS-STRATEGY.md` — OpenCode hook strategy
- `scripts/savia-env.sh` — provider-agnostic env layer
- SPEC-127 — OpenCode provider-agnostic migration

---

*Generado por Savia. Rama privada — no se sube a origin/main.*
