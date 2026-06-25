#!/usr/bin/env bash
# savia-voice-speak.sh — SE-075 Slice 3.
set -uo pipefail
# High-level text → synthesize → play integration for Savia.
#
# Usage:
#   bash scripts/savia-voice-speak.sh "Texto a hablar"
#   bash scripts/savia-voice-speak.sh "Texto" --voice em_alex
#   bash scripts/savia-voice-speak.sh "Texto" --no-play
#   echo "Texto" | bash scripts/savia-voice-speak.sh
#
# Environment:
#   SAVIA_VOICE        on|off   — master switch (default: off)
#   SAVIA_VOICE_VOICE  voice id override (default: ef_dora)
#   SAVIA_VOICE_LANG   lang override (default: es)
#   SAVIA_VOICE_SPEED  speed override (default: 1.0)
#
# Outputs:
#   Generates /tmp/savia-voice-<hash>.wav
#   If aplay is available and SAVIA_VOICE=on and --no-play not set: plays audio.
#   If --no-play: only generates the file and prints the path.
#
# Reference: SE-075 Slice 3 (docs/propuestas/SE-075-voicebox-adoption.md)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KOKORO_PY="$SCRIPT_DIR/savia-kokoro.py"

# ── Defaults ────────────────────────────────────────────────────────────────
VOICE="${SAVIA_VOICE_VOICE:-ef_dora}"
LANG="${SAVIA_VOICE_LANG:-es}"
SPEED="${SAVIA_VOICE_SPEED:-1.0}"
MASTER_SWITCH="${SAVIA_VOICE:-off}"
NO_PLAY=0
TEXT=""

# ── Argument parsing ─────────────────────────────────────────────────────────
# First positional arg is the text (optional — stdin fallback)
if [[ $# -gt 0 && "${1:0:2}" != "--" ]]; then
    TEXT="$1"
    shift
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --voice) VOICE="$2"; shift 2 ;;
        --lang)  LANG="$2";  shift 2 ;;
        --speed) SPEED="$2"; shift 2 ;;
        --no-play) NO_PLAY=1; shift ;;
        --on)  MASTER_SWITCH="on";  shift ;;
        --off) MASTER_SWITCH="off"; shift ;;
        -h|--help)
            sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
            exit 0 ;;
        *) echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
    esac
done

# ── Read stdin if no text arg ────────────────────────────────────────────────
if [[ -z "$TEXT" && ! -t 0 ]]; then
    TEXT="$(cat)"
fi

if [[ -z "${TEXT// }" ]]; then
    echo "ERROR: no text provided — use positional arg or pipe stdin" >&2
    exit 1
fi

# ── Master switch guard ──────────────────────────────────────────────────────
if [[ "$MASTER_SWITCH" != "on" ]]; then
    echo "SAVIA_VOICE=off — voice synthesis disabled. Set SAVIA_VOICE=on to enable." >&2
    exit 0
fi

# ── Compute deterministic output path ────────────────────────────────────────
HASH="$(printf '%s' "$TEXT$VOICE$LANG" | sha256sum | cut -c1-12)"
OUT_WAV="/tmp/savia-voice-${HASH}.wav"

# ── Check kokoro available ───────────────────────────────────────────────────
if ! python3 -c "import kokoro" 2>/dev/null; then
    echo "WARNING: kokoro not installed — voice synthesis unavailable." >&2
    echo "Install: pip install kokoro soundfile" >&2
    exit 1
fi

# ── Synthesize ───────────────────────────────────────────────────────────────
if ! python3 "$KOKORO_PY" \
        --text "$TEXT" \
        --output "$OUT_WAV" \
        --voice "$VOICE" \
        --lang "$LANG" \
        --speed "$SPEED" 2>&1; then
    echo "ERROR: synthesis failed" >&2
    exit 1
fi

echo "$OUT_WAV"

# ── Play ──────────────────────────────────────────────────────────────────────
if [[ "$NO_PLAY" -eq 1 ]]; then
    exit 0
fi

if command -v aplay >/dev/null 2>&1; then
    aplay -q "$OUT_WAV" 2>/dev/null || true
elif command -v paplay >/dev/null 2>&1; then
    paplay "$OUT_WAV" 2>/dev/null || true
elif command -v afplay >/dev/null 2>&1; then
    afplay "$OUT_WAV" 2>/dev/null || true
else
    echo "WARNING: no audio player found (aplay/paplay/afplay). File at: $OUT_WAV" >&2
fi
