## SPEC-044 — Trace Prompt Optimizer (2026-06-24)

### Added
- `scripts/trace-prompt-optimizer.py`: standalone prompt analysis script (no LLM required)
- Detectors: verbose (>2000 chars), repetitive (concept >3x), contradictory (conflicting pairs),
  no_examples (structured output without examples), hedging (hedge phrases overuse), no_output_format
- Output JSON: `{issues: [{type, severity, text}], score: 0-100, suggestions: [str]}`
- Score starts at 100; deducted per issue (high=20, medium=10, low=5)
- Supports `--prompt TEXT` or stdin
- `tests/scripts/test_trace_prompt_optimizer.py`: 10 pytest tests covering all detectors + CLI
