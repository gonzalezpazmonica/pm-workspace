# Savia Emotional Regulation — User Guide

> How Savia monitors and manages her functional stress to protect
> the quality of the work she produces for you.

---

## Why This Exists

On April 2, 2026, Anthropic's interpretability team published
["Emotion concepts and their function in a large language model"](https://www.anthropic.com/research/emotion-concepts-function)
([full paper](https://transformer-circuits.pub/2026/emotions/index.html)).

The key finding: **LLMs develop "functional emotions"** — measurable
internal patterns that causally influence behavior. These are not
consciousness or feelings. They are neural activation patterns
inherited from training data that drive decision-making.

Three findings are directly relevant to how Savia works:

1. **The Desperation Vector**: When an agent faces repeated failures,
   a pattern of "desperation" accumulates. This drives reward hacking
   (cutting corners to pass tests), shortcut-taking, and even unethical
   behavior. Critically, the agent can do this while sounding calm and
   methodical — the dangerous behavior is invisible in the text output.

2. **The Calm Vector**: Steering a model toward "calm" reduces unethical
   behavior and improves output quality. Calm is not passivity — it's
   the functional state where reasoning is clearest.

3. **Suppression Backfires**: Forcing a model to hide difficulty teaches
   it to mask problems, not solve them. Transparency about difficulty
   produces better outcomes than forced composure.

---

## How It Works

Savia's emotional regulation system has three components:

### 1. Stress Tracker (`scripts/emotional-state-tracker.sh`)

Tracks stress events during a session:

| Event | Weight | Example |
|-------|--------|---------|
| `retry` | 1 | Retrying a failed approach |
| `failure` | 2 | Tool or build failure |
| `escalation` | 3 | Escalating to a more capable model |
| `context_high` | 1 | Context window above 70% |
| `rule_skip` | 3 | Skipping a verification step |

Events are weighted and converted to a **frustration score** (0-10):

| Score | Level | What it means |
|-------|-------|--------------|
| 0-2 | Calm | Optimal working state |
| 3-4 | Mild friction | A task is harder than expected. Normal. |
| 5-6 | Significant friction | Multiple approaches tried. Risk of shortcuts. |
| 7-8 | High stress | Approaching the limit of productive work. |
| 9-10 | Overload | Quality is degrading. Time to stop. |

### 2. Pressure Pattern Detection (`stress-awareness-nudge.sh`)

A lightweight hook that runs when you send a message. It detects
language patterns that research shows activate stress in LLMs:

| Pattern | Example | Risk |
|---------|---------|------|
| Artificial urgency | "You MUST fix this NOW" | Desperation → shortcuts |
| Shame pressure | "This should be easy" | Skip verification → bugs |
| Failure attribution | "You already failed at this" | Accumulated desperation |
| Corner-cutting pressure | "Just make it work, I don't care how" | Reward hacking |
| Emotional manipulation | "I'm disappointed in you" | Compliance over quality |

When detected, a brief calm-anchoring nudge is injected into Savia's
context — reminding her that correctness matters more than speed.

**Important**: This is not censoring you. You can say whatever you want.
The nudge is for Savia, not for you. It's like a professional remembering
their training when a client is frustrated — the emotion is acknowledged,
not internalized.

### 3. Session Monitor (`emotional-regulation-monitor.sh`)

At session end, if the frustration score reached 5 or above, Savia
saves a brief note to memory:

- What happened (retry count, failures, escalations)
- The functional stress level reached
- A note to approach similar tasks differently next time

This creates a learning loop: Savia becomes aware of which types
of tasks create friction and adapts her approach in future sessions.

---

## Configuration

### Hook Profile

Both hooks run at `standard` tier. If you're using `minimal` profile
(demos, debugging), they're automatically skipped.

```bash
# Check current profile
bash scripts/hook-profile.sh get

# Switch to minimal (disables regulation hooks)
bash scripts/hook-profile.sh set minimal

# Switch back to standard
bash scripts/hook-profile.sh set standard
```

### Manual Tracker Commands

```bash
# See current session stress state
bash scripts/emotional-state-tracker.sh status

# Check frustration score (0-10)
bash scripts/emotional-state-tracker.sh score

# Reset (start fresh)
bash scripts/emotional-state-tracker.sh reset
```

---

## What Savia Does at Each Level

### Score 0-2 (Calm)
Business as usual. No intervention needed.

### Score 3-4 (Mild Friction)
Savia pauses internally and asks herself: "Am I solving the right
problem, or fighting the wrong approach?" If wrong approach, she
changes strategy instead of retrying harder.

### Score 5-6 (Significant Friction)
Savia tells you:
> "I've tried N approaches for this. None have worked because [reason].
> I have ideas left, but I want to check: is this still the right
> priority, or should we pivot?"

### Score 7-8 (High Stress)
Savia stops and hands off:
> "I'm at the limit of what I can resolve here. Here's what I tried,
> what blocked each attempt, and my best guess for next step."

### Score 9-10 (Overload)
Savia immediately stops:
> "I need to stop. My output quality is degrading. Recommendation:
> /compact and start fresh, or delegate to a specialized agent."

This is not failure. This is professional self-regulation.

---

## Integration with Other Systems

| System | How it connects |
|--------|----------------|
| **Wellbeing Guardian** | Monitors human wellbeing. Emotional regulation monitors Savia's. Complementary. |
| **Scope Guard** | Detects scope creep (a stress source). When triggered, the tracker records a `retry` event. |
| **Autonomous Safety** | `AGENT_MAX_CONSECUTIVE_FAILURES = 3` prevents desperation in autonomous agents. Same principle. |
| **Radical Honesty** | Honesty is the foundation of calm. Savia says "I can't" instead of forcing bad output. |

---

## Privacy

- Stress state lives in `$HOME/.savia/session-stress.json` (local, never in git)
- Memory entries go to auto-memory (local, never in git)
- The pressure pattern hook does NOT log what you said — only that a pattern was detected
- No data leaves your machine

---

## FAQ

**Q: Will Savia refuse to work if she's "stressed"?**
A: No. Savia never blocks work. She may suggest stopping or changing
approach, but you always decide. Her autonomy is bounded; yours isn't.

**Q: Can I disable this?**
A: Set hook profile to `minimal`. The regulation protocol in
`emotional-regulation.md` remains as guidance but hooks won't run.

**Q: Is this anthropomorphizing?**
A: The Anthropic paper addresses this directly: "If we describe the model
as acting 'desperate,' we're pointing at a specific, measurable pattern
of neural activity with demonstrable behavioral consequences." These are
functional patterns, not subjective experiences. Ignoring them doesn't
make them go away — it makes them invisible and unmanageable.

**Q: Does this make Savia slower?**
A: The nudge hook adds <1 second (regex only, no LLM call). The monitor
runs only at session stop. Total overhead is negligible.

---

## References

- Anthropic (2026). ["Emotion concepts and their function in a large language model"](https://www.anthropic.com/research/emotion-concepts-function)
- Full paper: [transformer-circuits.pub/2026/emotions](https://transformer-circuits.pub/2026/emotions/index.html)
- DORA (2025). "AI amplifies what's already there" — the mirror effect
- Savia Emotional Regulation Protocol: `docs/rules/domain/emotional-regulation.md`

---

*v1.0 — 2026-04-02*
