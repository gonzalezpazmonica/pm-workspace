# SE-075 Slice 3 — Kokoro CPU voice

**Date:** 2026-06-24
**Spec:** docs/propuestas/SE-075-voicebox-adoption.md
**Status:** IMPLEMENTED

## What

Slice 3 of SE-075: Kokoro 82M CPU TTS integration for Savia.
Local Spanish/English voice synthesis without GPU, cloud, or external API calls.

## Files added / changed

| File | Change |
|---|---|
| `scripts/savia-kokoro.py` | NEW — CLI wrapper over Kokoro for Savia |
| `scripts/savia-voice-speak.sh` | NEW — high-level text → synthesize → play |
| `scripts/savia-voice-chunk.sh` | MODIFIED — Kokoro as primary TTS backend |
| `docs/rules/domain/kokoro-voice-protocol.md` | NEW — voice protocol doc |
| `tests/scripts/test_savia_kokoro.py` | NEW — 14 pytest tests (100% pass) |
| `tests/bats/test-se-075-kokoro.bats` | NEW — 6 BATS tests (100% pass) |

## Acceptance criteria satisfied

- [x] AC-09 Kokoro installed, model cached at `~/.cache/huggingface/`
- [x] AC-10 `scripts/savia-kokoro.py` generates intelligible Spanish WAV (`ef_dora`)
- [x] AC-11 Skill/protocol documented with examples in `kokoro-voice-protocol.md`
- [x] AC-12 Latency verifiable: Kokoro ~150x realtime on CPU (measured ~4s for 0.625s audio)

## Key design decisions

- `SAVIA_VOICE=off` master switch (default): prevents unexpected audio in CI/automated contexts
- `redirect_stdout → stderr` during `KPipeline()` init: keeps `--json` output clean despite torch print() warnings
- Auto-chunking at >500 chars via existing `sentence-splitter.py` (Spanish-aware)
- Telemetry to `output/kokoro-telemetry.jsonl`: ts, voice, lang, duration_s, chars, ok
- `savia-voice-chunk.sh` fallback chain: Kokoro → espeak-ng → espeak → error

## Tests

```
pytest tests/scripts/test_savia_kokoro.py -q  → 14 passed
bats  tests/bats/test-se-075-kokoro.bats      → 6/6 ok
```
