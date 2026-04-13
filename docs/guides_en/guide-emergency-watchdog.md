# Emergency Watchdog

> Version: v4.5 | Era: 174 | Since: 2026-04-03

## What it is

A systemd service that monitors connectivity with api.anthropic.com every 5 minutes. After 3 consecutive failures, it automatically activates a local LLM via Ollama so that pm-workspace keeps working without internet. When the connection returns, it unloads the model to free RAM.

## Installation

```bash
# Install the service (requires sudo)
sudo bash scripts/install-watchdog.sh

# Check status
systemctl --user status savia-watchdog
```

Prerequisites:
- Ollama installed: `ollama --version`
- At least one model downloaded: `ollama pull qwen2.5:3b`
- systemd available (Linux)

## Supported models

| Hardware | Recommended model | RAM used |
|----------|-------------------|----------|
| 8GB RAM | qwen2.5:3b | ~4GB |
| 16GB RAM | gemma4:e2b | ~8GB |
| 32GB+ RAM | gemma4:e4b | ~16GB |

## Basic usage

The watchdog operates autonomously. No manual intervention required.

```bash
# View logs in real time
journalctl --user -u savia-watchdog -f

# Force an immediate check
systemctl --user restart savia-watchdog
```

During an internet outage, the log shows:
```
[WATCHDOG] 3 fallos consecutivos — activando LLM local
[OLLAMA] Modelo cargado: qwen2.5:3b
```

## Configuration

The script `scripts/savia-watchdog.sh` defines the constants:
- `CHECK_URL`: endpoint to monitor (api.anthropic.com)
- `CHECK_INTERVAL`: frequency in seconds (300 = 5 min)
- `MAX_FAILURES`: failures before activating fallback (3)
- `FALLBACK_MODEL`: Ollama model to load

The default model is selected based on available RAM via `scripts/emergency-plan.sh`.

## Integration

- **Savia Shield**: when the watchdog activates Ollama, `ollama-classify.sh` uses the local model for data classification (Layer 2)
- **emergency-plan.sh**: complementary script that evaluates the situation and selects the optimal model
- **session-init.sh**: reports watchdog status at session start

## Troubleshooting

**Ollama does not start**: verify that the Ollama service is active: `systemctl status ollama`

**Model does not download**: run `ollama pull qwen2.5:3b` manually before installing the watchdog

**Watchdog does not detect the outage**: check that `curl -s api.anthropic.com` fails (it could be a local DNS issue)

**Insufficient RAM**: use the lightest model (qwen2.5:3b, ~4GB) or close heavy applications
