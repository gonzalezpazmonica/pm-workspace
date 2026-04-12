# Sovereign Deployment (SE-005)

> Enterprise module. Requires `sovereign-deployment: { enabled: true }` in manifest.

## Deployment modes

| Mode | LLM | Outbound network | Data exits machine |
|------|-----|------------------|--------------------|
| cloud | Anthropic API | Yes | Yes (API calls) |
| hybrid | Anthropic API | Yes (masked data) | Enmascarado via Savia Shield |
| sovereign | Ollama local | No | No |
| air-gap | Ollama local | Blocked by hook | No |

## Configuration

Per-tenant: `tenants/{slug}/deployment.yaml`

```yaml
mode: sovereign
llm:
  provider: ollama
  host: http://localhost:11434
  models:
    agent: qwen2.5:32b
    mid: qwen2.5:7b
    fast: qwen2.5:3b
network:
  egress_allowed: false
  allowed_hosts: []
```

## Network guard

`network-egress-guard.sh` blocks outbound calls (curl, wget, git push,
npm install, etc.) in sovereign/air-gap modes unless the target host is
in `network.allowed_hosts`. Runs as PreToolUse hook on Bash commands.

## Agent sovereign compatibility

Agents declare `sovereign_compatible` in frontmatter:
- `true`: works well with local models (7B+)
- `partial`: degraded quality, usable for non-critical tasks
- `false`: requires cloud model (Opus-class reasoning)

In sovereign mode, invoking a `false` agent triggers a warning and
escalation to human instead of silent degradation.

## Graceful degradation

If the local model is unavailable (Ollama down, model not pulled):
1. Log the failure with model name and error
2. Inform the user: "Local model unavailable. Pull with: ollama pull X"
3. NEVER silently fall back to cloud in sovereign mode

## LLM provider abstraction

Supported local runtimes (via Savia Dual proxy or direct):
- **Ollama** (default) — `/v1/messages` native endpoint
- **vLLM** — OpenAI-compatible API
- **llama.cpp** — lightweight edge deployment
- **LocalAI** — drop-in OpenAI replacement

## Extension point used

EP-5: Tenant Resolver (deployment config is per-tenant).
