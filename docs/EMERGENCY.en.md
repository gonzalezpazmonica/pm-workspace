# Emergency Guide — PM-Workspace

> What to do when Claude Code / the cloud LLM provider is unavailable.

---

## Step 0: Preventive preparation (RECOMMENDED)

Run this **now**, while you have internet, so everything works offline:

```bash
# Linux / macOS
cd ~/claude
./scripts/emergency-plan.sh

# Windows (PowerShell)
cd ~\claude
.\scripts\emergency-plan.ps1
```

This pre-downloads the Ollama installer and LLM model to local cache (~5-10GB). Supports Linux (amd64/arm64), macOS (Intel/Apple Silicon) and Windows. The script runs 5 steps: verify connectivity, detect hardware, download Ollama, download LLM model(s), and verify offline cache. It is idempotent — re-running skips already cached resources. If you lose connectivity, `emergency-setup` will use the cache automatically. It is automatically suggested the first time you start pm-workspace on a new machine.

## When to activate emergency mode?

Activate emergency mode if:
- Claude Code / OpenCode is not responding or showing connection errors
- The LLM provider (Anthropic) has a service outage
- There's no internet connection but you need to keep working
- You want to test pm-workspace without cloud dependency

## Quick Setup (5 minutes)

### Step 1: Run the installer

```bash
# Linux / macOS
cd ~/claude
./scripts/emergency-setup.sh

# Windows (PowerShell)
cd ~\claude
.\scripts\emergency-setup.ps1
```

The script auto-detects your OS and hardware, then guides you through:
1. Installing Ollama (local LLM manager). Requires **Ollama >= 0.20.0**, the first release that serves `/v1/messages` (Anthropic API), the path Claude Code requests. With an older version the script exits 1.
2. Downloading every model the opus/sonnet/haiku aliases point to (not only the main one)
3. Writing the variables to `~/.pm-workspace-emergency.env` (it never touches `~/.bashrc` or any shell file: emergency is transient)

The base is `ANTHROPIC_BASE_URL=http://localhost:11434`, **without a trailing `/v1`**: Claude Code appends `/v1/messages`, so `/v1` would request `/v1/v1/messages`. The file also sets `ANTHROPIC_AUTH_TOKEN="ollama"` and `ANTHROPIC_API_KEY=""`: Ollama does not check credentials, and without that placeholder Claude Code would send your real key or OAuth token to localhost, or ask for `/login`.

If offline and the cache holds no model, the script exits 1 and writes no variables file.

If offline, it will automatically use the local cache from `emergency-plan`.

If your machine has **less than 16GB RAM**, use a smaller model:
```bash
./scripts/emergency-setup.sh --model qwen2.5:3b
```

`--model` sets that single model for every alias. An unknown argument or `--model` without a value exits 2.

### Step 2: Verify it works

```bash
./scripts/emergency-status.sh
```

Exits 0 with "ready" only if: Ollama >= 0.20.0 installed, server on `:11434`, `~/.pm-workspace-emergency.env` exists and every model it configures is downloaded. With the mode active it also checks that `ANTHROPIC_BASE_URL` does not end in `/v1` and that `ANTHROPIC_AUTH_TOKEN` is set. Any failure: exit 1 plus the fix.

You should see all green (). If there are issues, the script tells you what to do.

### Step 3: Activate emergency mode

```bash
source ~/.pm-workspace-emergency.env
```

Claude Code / OpenCode will now use the local LLM instead of the cloud.

## What you can do in emergency mode

### With local LLM (~70% capacity)
- Review and generate code
- Create documentation
- Analyze bugs and propose fixes
- Basic sprint planning
- Assisted code review

### Without LLM (offline scripts)
```bash
./scripts/emergency-fallback.sh git-summary      # Recent git activity
./scripts/emergency-fallback.sh board-snapshot    # Export board status
./scripts/emergency-fallback.sh team-checklist    # Daily/review/retro checklists
./scripts/emergency-fallback.sh pr-list           # Pending PRs
./scripts/emergency-fallback.sh branch-status     # Active branches
```

### What does NOT work well in emergency
- Specialized agents (reduced quality with local models)
- Complex report generation (Excel/PowerPoint)
- Azure DevOps API operations (if no internet)
- Context >32K tokens (local models have limited window)

## Minimum Recommended Hardware

| RAM | Recommended model | Capability |
|-----|------------------|------------|
| 8GB | qwen2.5:3b | Basic — simple coding, Q&A |
| 16GB | qwen2.5:7b | Good — coding, review, docs |
| 32GB | qwen2.5:14b | Very good — near cloud quality |
| NVIDIA GPU | deepseek-coder-v2 | Excellent — GPU accelerated |

## Model Mapping

The `opus`/`sonnet`/`haiku` aliases used by the 27 agents resolve to local models based on RAM: 8GB→`3b` for all · 16GB→`7b`/`7b`/`3b` · 32GB+→`14b`/`7b`/`3b`. Official Claude Code variables: `ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU}_MODEL` and `CLAUDE_CODE_SUBAGENT_MODEL`. Customize them in `~/.pm-workspace-emergency.env`. [Claude Code Router](https://github.com/musistudio/claude-code-router) users (community project): `CCR-SUBAGENT-MODEL` tag enables per-agent override.

## Return to normal mode

When the cloud service is back online:

```bash
unset ANTHROPIC_BASE_URL PM_EMERGENCY_MODE PM_EMERGENCY_MODEL
unset ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL
unset ANTHROPIC_DEFAULT_HAIKU_MODEL CLAUDE_CODE_SUBAGENT_MODEL
unset ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY
```

**Windows**: `emergency-setup.ps1` persists the variables at user level (`[Environment]::SetEnvironmentVariable(..., "User")`), so closing the terminal is **not** enough: every new terminal keeps pointing to localhost. Remove each one with `[Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", $null, "User")` (same for the other six variables).

Or simply close and open a new terminal.

## Troubleshooting

**"Ollama not installed"** → Linux: `curl -fsSL https://ollama.ai/install.sh | sh` · macOS: re-run `emergency-setup.sh` · Windows: run `OllamaSetup.exe` from cache.

**"Server not responding"** → `ollama serve &`

**"Model not downloaded"** → `ollama pull qwen2.5:7b`

**"Slow responses"** → Use smaller model (`qwen2.5:3b`), close RAM-heavy apps, NVIDIA GPU is used automatically.

**"Out of memory"** → Downgrade to `qwen2.5:1.5b`, close browser, consider temporary swap.

## Quick Reference

```
# Linux / macOS                         # Windows (PowerShell)
./scripts/emergency-plan.sh             .\scripts\emergency-plan.ps1
./scripts/emergency-setup.sh            .\scripts\emergency-setup.ps1
./scripts/emergency-status.sh           (check Ollama manually)
./scripts/emergency-fallback.sh help    (use Git Bash)
source ~/.pm-workspace-emergency.env    (env vars set automatically)
```

---

*Part of PM-Workspace · [Main README](../README.en.md)*
