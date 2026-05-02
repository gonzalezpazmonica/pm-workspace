---
id: SPEC-066
title: "Enhanced Local LLM — Premium Tier for Emergency Mode"
status: IMPLEMENTED
date: 2026-03-31
era: 174
author: Savia
---

# SPEC-066: Enhanced Local LLM — Premium Tier for Emergency Mode

> Implementado en Era 174 Emergency Watchdog (4 modelos instalados en el host: gemma4:e2b/e4b, qwen2.5:3b/7b).

---

## Problem

Emergency Mode currently uses qwen2.5:7b (or 3b/14b by RAM) as offline fallback. These models handle basic text generation but lack structured reasoning, stable tool-calling, and agent-like autonomy. When Claude API is down, pm-workspace operates at significantly degraded quality — sprint analysis is shallow, code review is unreliable, and spec generation is not feasible.

## Proposal

Add a **premium tier** to Emergency Mode using `Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled` (GGUF Q4_K_M). This model was fine-tuned on ~3,950 Claude 4.6 Opus reasoning traces and demonstrates stable tool-calling, structured `<think>` reasoning, and 9+ minute autonomous operation.

**Scope**: Emergency Mode only. Savia Shield Layer 2 remains on qwen2.5:7b (classification does not benefit from reasoning capabilities; speed is the priority there).

## Architecture

### 3-Tier Emergency Fallback Chain

```
Tier 1 (Minimal) — 8GB RAM machines
  Model: qwen2.5:3b (~4GB VRAM)
  Capabilities: basic text, simple queries, board snapshots
  Quality: ~40% of Claude Sonnet

Tier 2 (Standard) — 16GB RAM machines [CURRENT DEFAULT]
  Model: qwen2.5:7b (~8GB VRAM)
  Capabilities: classification (Shield L2), basic PM ops, simple analysis
  Quality: ~60% of Claude Sonnet

Tier 3 (Premium) — 24GB+ VRAM or 32GB+ unified RAM [NEW]
  Model: qwen3.5:27b-claude-opus-q4_k_m (~17GB VRAM)
  Capabilities: structured reasoning, tool-calling, spec review,
                sprint analysis, basic code review, task decomposition
  Quality: ~75-80% of Claude Sonnet (community estimate, unverified)
```

### Auto-Detection

`emergency-setup.sh` already detects RAM. Extend to detect GPU VRAM:

```bash
# Existing: RAM-based selection
# New: VRAM-based selection for Tier 3
VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)
if [[ "$VRAM" -ge 20000 ]]; then
  EMERGENCY_MODEL="qwen3.5-27b-claude-opus:q4_k_m"
  EMERGENCY_TIER="premium"
elif [[ "$RAM_GB" -ge 16 ]]; then
  EMERGENCY_MODEL="qwen2.5:7b"
  EMERGENCY_TIER="standard"
else
  EMERGENCY_MODEL="qwen2.5:3b"
  EMERGENCY_TIER="minimal"
fi
```

### What Tier 3 Unlocks in Emergency Mode

| Operation | Tier 1-2 | Tier 3 (new) |
|-----------|----------|--------------|
| Sprint status summary | Basic item listing | Structured analysis with blockers |
| Task decomposition | Unreliable | Structured reasoning with think tags |
| Spec review | Not feasible | Basic quality check |
| Code review | Not feasible | Pattern-based review (no security) |
| Tool-calling | Unstable | Stable (validated by community) |
| Agent autonomy | Short bursts | 9+ min autonomous runs |
| Context window | 8-32K tokens | Up to 262K tokens |

## Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| VRAM (NVIDIA) | 17GB (RTX 3090/4090) | 24GB+ (RTX 4090/5090) |
| Unified RAM (Mac) | 24GB (M2/M3/M4) | 32GB+ |
| Disk space | 16.5GB (Q4_K_M) | 16.5GB |
| CPU RAM (if CPU-only) | 32GB+ (very slow) | Not recommended |

## Changes Required

### Files to modify

1. **`scripts/emergency-setup.sh`** — Add VRAM detection, Tier 3 model download
2. **`scripts/emergency-plan.sh`** — Add `--tier premium` to pre-download 27B model
3. **`.claude/commands/emergency-mode.md`** — Document Tier 3 capabilities/requirements
4. **`.claude/commands/emergency-plan.md`** — Add tier selection to plan command
5. **`docs/rules/domain/data-sovereignty.md`** — Update model table (no Shield change)

### New files

6. **`scripts/detect-gpu-vram.sh`** — Portable GPU VRAM detection (NVIDIA/AMD/Apple)

### Config additions (pm-config)

```
EMERGENCY_TIER_PREMIUM_MODEL    = "qwen3.5-27b-claude-opus:q4_k_m"
EMERGENCY_TIER_PREMIUM_MIN_VRAM = 17000   # MB
EMERGENCY_TIER_PREMIUM_CONTEXT  = 32768   # conservative default
```

## Risks and Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| No published benchmarks | High | Do NOT promise Opus-level quality. Document as "enhanced" not "equivalent" |
| 17GB VRAM excludes most machines | Medium | Tier 3 is optional. Default remains Tier 2 (qwen2.5:7b) |
| Model provenance (3rd party fine-tune) | Medium | Apache 2.0 license. Pin to specific commit hash |
| Context window disputed (262K vs 8K effective) | High | Default to 32K conservative limit, test empirically |
| Hallucination on factual PM data | Medium | Emergency Mode already has quality disclaimers |
| 16.5GB download size | Low | Only downloaded with explicit `--tier premium` |

## What This Does NOT Change

- **Shield Layer 2** stays on qwen2.5:7b — classification is a constrained task where speed (2-5s) matters more than reasoning depth
- **Shield Layer 4** (masking) is unaffected — it is deterministic
- **Default emergency tier** remains Tier 2 — auto-upgrade only if VRAM detected
- **No security-critical decisions** in Emergency Mode — always deferred to human

## Verification Plan

1. Download Q4_K_M GGUF on a machine with 24GB+ VRAM
2. Run through Ollama: `ollama run qwen3.5-27b-claude-opus:q4_k_m`
3. Test: sprint status analysis, task decomposition, basic code review
4. Measure: latency per query, VRAM usage, context window stability
5. Compare: same prompts on qwen2.5:7b vs 27B-opus-distill
6. Document results in `output/benchmarks/emergency-tier3.md`

## Decision Required

This spec requires empirical validation before implementation. The community reports are promising but unverified. Recommended next step: la usuaria confirms her hardware specs (GPU/VRAM), and if sufficient, run the verification plan above before committing to implementation.
