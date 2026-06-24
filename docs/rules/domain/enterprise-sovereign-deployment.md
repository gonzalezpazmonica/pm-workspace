---
context_tier: L3
spec: SE-005
status: IMPLEMENTED
---

# Enterprise Sovereign Deployment

Guide for activating and operating Savia Enterprise in sovereign, air-gap, or hybrid modes.

## Deployment Modes

| Mode | LLM provider | Outbound network | Data leaves org |
|---|---|---|---|
| `cloud` | Anthropic API | Yes | Yes (API calls) |
| `hybrid` | Anthropic API | Yes (masked) | Masked/anonymised |
| `sovereign` | Local runtime | No | No |
| `air-gap` | Local runtime | No (blocked at hook) | No |

Local runtimes supported: Ollama, vLLM, llama.cpp, LocalAI (OpenAI-compatible).

## Activation

### Step 1 — Create or identify the tenant

```bash
bash scripts/enterprise/tenant-create.sh \
  --slug myorg \
  --display "My Organisation" \
  --admin-user admin
```

### Step 2 — Activate sovereign mode

```bash
bash scripts/enterprise/sovereign-activate.sh \
  --tenant myorg \
  --mode sovereign \
  --llm-host http://localhost:11434
```

For full air-gap (hook-enforced egress block):

```bash
bash scripts/enterprise/sovereign-activate.sh \
  --tenant myorg \
  --mode air-gap \
  --llm-host http://internal-llm-host:11434
```

This creates `tenants/myorg/deployment.yaml` and registers the
`network-egress-guard.sh` hook for air-gap mode.

### Step 3 — Verify

```bash
bash scripts/enterprise/deployment-status.sh --tenant myorg
```

Expected output (air-gap example):

```json
{
  "mode": "air-gap",
  "llm_provider": "ollama",
  "llm_host": "http://internal-llm-host:11434",
  "egress_allowed": false,
  "sovereign_ready": true
}
```

## deployment.yaml Reference

```yaml
tenant: myorg
mode: sovereign          # cloud | hybrid | sovereign | air-gap
configured_at: 2026-06-24T00:00:00Z

llm:
  provider: ollama       # ollama | vllm | llama.cpp | localai | anthropic
  host: http://localhost:11434
  models:
    agent: qwen2.5:32b   # heavy-tier agents
    mid: qwen2.5:7b      # mid-tier agents
    fast: qwen2.5:3b     # fast-tier agents

network:
  egress_allowed: false
  allowed_hosts: []      # add FQDNs to whitelist if needed
```

## Network Guard

`network-egress-guard.sh` intercepts `Bash` PreToolUse hook calls.
Blocked patterns: `curl`, `wget`, `gh api`, `npm install`, `pip install`,
`apt-get install`, `docker pull`, `git clone/fetch/push/pull`.

To allow a specific host, add it to `allowed_hosts` in `deployment.yaml`:

```yaml
network:
  egress_allowed: false
  allowed_hosts:
    - registry.internal.corp
    - pypi.internal.corp
```

The guard degrades gracefully: if `python3` or `PyYAML` is unavailable,
it exits 0 (fail-open) to avoid blocking Core workflows.

## Supported LLM Runtimes

| Runtime | Notes |
|---|---|
| **Ollama** | Default for sovereign. Serve on port 11434. |
| **vLLM** | High-concurrency. OpenAI-compatible endpoint. |
| **llama.cpp** | Edge hardware. HTTP server mode required. |
| **LocalAI** | Drop-in OpenAI-compatible. Set `OPENAI_API_BASE`. |

## Hardware Reference Configurations

| Hardware | RAM | Recommended model tier |
|---|---|---|
| Framework Desktop (Ryzen AI MAX+ 395) | 128 GB unified | 32B comfortable |
| Mac Studio M2 Ultra | 192 GB unified | 72B comfortable |
| Workstation 2x RTX 4090 | 48 GB VRAM | 70B via vLLM |

## Agent Compatibility

Agents are tagged `sovereign_compatible: true|partial|false` in their frontmatter.
When `mode: sovereign` and an agent is `false`, Savia degrades to the nearest
compatible model tier or escalates to human review.

For production sovereign deployments, a 32B+ model is recommended for agent-tier tasks.

## Troubleshooting

**Egress guard not blocking**: verify that `sovereign-deployment` module is
enabled in `manifest.json` and `SAVIA_TENANT` is set correctly.

**PyYAML not available**: `pip3 install pyyaml`. Without it, deployment-status
falls back to grep-based parsing.

**Model not found**: pull the model before entering air-gap mode.
The guard blocks outbound calls once air-gap is active — pulling must happen first.

**Hook not firing**: verify the hook is registered in `.claude/settings.json`
under `hooks.PreToolUse`. Re-run `sovereign-activate.sh` with `--mode air-gap`
to re-register.

## Rollback

```bash
bash scripts/enterprise/enterprise-migrate.sh disable sovereign-deployment
```

Or manually: delete `tenants/{slug}/deployment.yaml` and set
`manifest.json` → `modules.sovereign-deployment.enabled = false`.
