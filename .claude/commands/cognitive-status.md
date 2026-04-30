---
name: cognitive-status
description: Show cognitive-debt telemetry status (SPEC-107 Phase 1 — opt-in)
permission_level: L1
tools: [Bash]
---

# /cognitive-status

Display the user's cognitive-debt measurement state and recent telemetry summary.

## What it does

Wraps `bash scripts/cognitive-debt.sh status` followed by `summary` if telemetry exists. Output is purely local — no LLM calls, no network, no exposure to team or manager (Equality Shield, Rule #23).

## Privacy

- Telemetry lives in `~/.savia/cognitive-load/{user}.jsonl` — N3, gitignored.
- Never exported to reports or shared with team.
- One-command forget: `bash scripts/cognitive-debt.sh forget --confirm`.

## Run

```bash
bash scripts/cognitive-debt.sh status
echo
bash scripts/cognitive-debt.sh summary 2>/dev/null || true
```

## Reference

SPEC-107 — `docs/propuestas/SPEC-107-ai-cognitive-debt-mitigation.md` Phase 1.
