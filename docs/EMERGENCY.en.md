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

This pre-downloads the Ollama installer and LLM model to local cache (~5-10GB). Supports Linux (amd64/arm64), macOS (Intel/Apple Silicon) and Windows. If you lose connectivity, `emergency-setup` will use the cache automatically. It is automatically suggested the first time you start pm-workspace on a new machine.

## When to activate emergency mode?

Activate emergency mode if:
- Claude Code is not responding or showing connection errors
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
1. Installing Ollama (local LLM manager)
2. Downloading the recommended model for your RAM
3. Automatic environment variable configuration

If offline, it will automatically use the local cache from `emergency-plan`.

If your machine has **less than 16GB RAM**, use a smaller model:
```bash
./scripts/emergency-setup.sh --model qwen2.5:3b
```

### Step 2: Verify it works

```bash
./scripts/emergency-status.sh
```

You should see all green (✓). If there are issues, the script tells you what to do.

### Step 3: Activate emergency mode

```bash
source ~/.pm-workspace-emergency.env
```

Claude Code will now use the local LLM instead of the cloud.

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
- Specialized agents (require cloud Opus/Sonnet)
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

## Return to normal mode

When the cloud service is back online:

```bash
unset ANTHROPIC_BASE_URL
unset PM_EMERGENCY_MODE
unset PM_EMERGENCY_MODEL
```

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
