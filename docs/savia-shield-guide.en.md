# Savia Shield Guide — Data protection for daily work

> Practical usage. For technical architecture: [docs/savia-shield.en.md](savia-shield.en.md)

## What is Savia Shield

Savia Shield prevents confidential client project data (level N4/N4b) from leaking into public repository files (level N1). It operates through 5 independent layers, each auditable. It is disabled by default and activated when you start working with client data.

## The 4 hook profiles

Profiles control which hooks run. Each profile includes the previous one:

| Profile | Active hooks | Use case |
|---------|-------------|----------|
| `minimal` | Security blockers only (credentials, force-push, destructive infra, sovereignty) | Demos, onboarding, debugging |
| `standard` | Security + quality (bash validation, plan gate, TDD, scope guard, compliance) | Daily work (recommended) |
| `strict` | Standard + dispatch validation, stop quality gate, competence tracker | Pre-release, critical code |
| `ci` | Same as standard but non-interactive | Automated pipelines, scripts |

```bash
bash scripts/hook-profile.sh get           # View active profile
bash scripts/hook-profile.sh set standard  # Change (persists across sessions)
export SAVIA_HOOK_PROFILE=ci               # Or with environment variable
```

Security hooks that run in ALL profiles: `block-credential-leak.sh`, `block-force-push.sh`, `block-infra-destructive.sh`, `data-sovereignty-gate.sh`.

---

## The 5 protection layers

**Layer 0 — API Proxy**: Intercepts outbound prompts to Anthropic. Masks entities automatically. Activate with `export ANTHROPIC_BASE_URL=http://127.0.0.1:8443`.

**Layer 1 — Deterministic gate** (< 2s): PreToolUse hook that scans content before writing public files. Regex for credentials, IPs, tokens. Includes NFKC and base64.

**Layer 2 — Local LLM classification**: Ollama qwen2.5:7b classifies semantic text as CONFIDENTIAL or PUBLIC. Data never leaves localhost. Without Ollama, only Layer 1 operates.

**Layer 3 — Post-write audit**: Async hook that re-scans the complete file. Does not block. Immediate alert if a leak is detected.

**Layer 4 — [DEPRECATED] Manual masking removed**

Manual masking (`sovereignty-mask.sh`) was removed on 2026-05-05.  
Layer 4 (Proxy) maintains its own internal masking in `savia-shield-proxy.py`.  
This slot is reserved for a future alternative.

---

## Enable and disable

```bash
/savia-shield enable    # Enable
/savia-shield disable   # Disable
/savia-shield status    # Check status and installation
```

Or by editing `.claude/settings.local.json`:

```json
{ "env": { "SAVIA_SHIELD_ENABLED": "true" } }
```

## Per-project configuration

Each project can define sensitive entities in:

- `projects/{name}/GLOSSARY.md` — domain terms
- `projects/{name}/GLOSSARY-MASK.md` — entities for masking
- `projects/{name}/team/TEAM.md` — stakeholder names

Shield loads these files automatically when operating on the project.

## Full installation (optional)

For all 5 layers including proxy and NER:

```bash
bash scripts/savia-shield-setup.sh
export ANTHROPIC_BASE_URL=http://127.0.0.1:8443
```

Requirements: Python 3.12+, Ollama, jq, 8GB RAM minimum. Without full installation: layers 1 and 3 (regex + audit) always operate.

## The 5 confidentiality levels

| Level | Who sees it | Example |
|-------|------------|---------|
| N1 Public | Internet | Workspace code |
| N2 Company | The organization | Org config |
| N3 User | Only you | Your profile |
| N4 Project | Project team | Client data |
| N4b PM-Only | Only the PM | One-to-ones |

Shield protects the boundaries **N4/N4b towards N1**. Writing to private locations is always permitted.

> Full architecture: [docs/savia-shield.en.md](savia-shield.en.md) | Tests: `bats tests/test-data-sovereignty.bats`


## Era 171 (SPEC-071) Improvements

- **Event coverage**: 17 of 28 Claude Code events covered (61%, previously 25%)
- **`if` conditions**: 7 hooks automatically skip if the file is not code (saves ~40% of spawns)
- **New events**: SubagentStart/Stop, TaskCreated/Completed, FileChanged, InstructionsLoaded, ConfigChange
- **Portability**: removed all hardcoded `/tmp/` paths and incompatible `sed -i` commands
- **Auditable timeouts**: if the daemon takes >5s, it is recorded as TIMEOUT_ALLOW in the audit log
