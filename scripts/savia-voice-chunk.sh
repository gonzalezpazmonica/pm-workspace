#!/usr/bin/env bash
# savia-voice-chunk.sh — SE-075 Slice 2.
# Long-form Spanish TTS chunker with bounded concurrency and ffmpeg crossfade.
# Re-implementation of the chunking pattern in voicebox `services/tts.py`
# (MIT license); clean-room — no source code copied.
#
# Pipeline:
#   1. read text from --text/--file/stdin
#   2. split into sentence-bounded chunks (Spanish-aware, scripts/lib/sentence-splitter.py)
#   3. synthesize each chunk via $SAVIA_TTS_CMD into chunk_NN.wav (bounded concurrency 2)
#   4. concat with ffmpeg + acrossfade (or simple concat if --no-fade)
#
# Usage:
#   savia-voice-chunk.sh --text "long text" --out out.wav
#   savia-voice-chunk.sh --file note.txt --out out.wav --crossfade-ms 100
#   savia-voice-chunk.sh --file note.txt --dry-run            # print chunks only
#   echo "long text" | savia-voice-chunk.sh --out out.wav
#
# Configuration via env:
#   SAVIA_TTS_CMD       # template, {text}/{out} placeholders. Default: 'espeak-ng -v es -w {out} {text}'
#   SAVIA_TTS_CONCURRENCY  # default 2
#   SAVIA_TTS_CROSSFADE_MS # default 80
#   SAVIA_TTS_MAX_CHARS    # default 600
#
# Reference: SE-075 Slice 2 (docs/propuestas/SE-075-voicebox-adoption.md)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPLITTER="$SCRIPT_DIR/lib/sentence-splitter.py"

usage() {
  sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
  exit 2
}

MODE_DRY=0
MODE_NOFADE=0
TEXT=""
FILE=""
OUT=""
MAX_CHARS="${SAVIA_TTS_MAX_CHARS:-600}"
CROSSFADE_MS="${SAVIA_TTS_CROSSFADE_MS:-80}"
CONCURRENCY="${SAVIA_TTS_CONCURRENCY:-2}"
TTS_CMD="${SAVIA_TTS_CMD:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --text) TEXT="$2"; shift 2 ;;
    --file) FILE="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --max-chars) MAX_CHARS="$2"; shift 2 ;;
    --crossfade-ms) CROSSFADE_MS="$2"; shift 2 ;;
    --concurrency) CONCURRENCY="$2"; shift 2 ;;
    --dry-run) MODE_DRY=1; shift ;;
    --no-fade) MODE_NOFADE=1; shift ;;
    -h|--help) usage ;;
    *) echo "ERROR: unknown arg: $1" >&2; usage ;;
  esac
done

# 1. Resolve input text
if [[ -n "$TEXT" ]]; then
  INPUT="$TEXT"
elif [[ -n "$FILE" ]]; then
  if [[ ! -f "$FILE" ]]; then
    echo "ERROR: file not found: $FILE" >&2
    exit 1
  fi
  INPUT=$(cat "$FILE")
elif [[ ! -t 0 ]]; then
  INPUT=$(cat)
else
  echo "ERROR: no input — use --text, --file, or pipe stdin" >&2
  exit 2
fi

if [[ -z "${INPUT// }" ]]; then
  echo "ERROR: empty input" >&2
  exit 2
fi

# 2. Split into chunks
CHUNKS_TMP=$(mktemp)
trap 'rm -f "$CHUNKS_TMP"' EXIT

printf '%s' "$INPUT" | python3 "$SPLITTER" --max-chars "$MAX_CHARS" >"$CHUNKS_TMP"
CHUNK_COUNT=$(wc -l <"$CHUNKS_TMP" | tr -d ' ')

if [[ "$CHUNK_COUNT" -eq 0 ]]; then
  echo "ERROR: splitter produced 0 chunks" >&2
  exit 1
fi

# 2b. Dry-run: print chunks and exit
if [[ "$MODE_DRY" -eq 1 ]]; then
  echo "chunks=$CHUNK_COUNT"
  cat -n "$CHUNKS_TMP"
  exit 0
fi

# Audio output requires --out
if [[ -z "$OUT" ]]; then
  echo "ERROR: --out is required (unless --dry-run)" >&2
  exit 2
fi

# 3. Choose TTS command
if [[ -z "$TTS_CMD" ]]; then
  if command -v espeak-ng >/dev/null 2>&1; then
    TTS_CMD='espeak-ng -v es -w {out} {text}'
  elif command -v espeak >/dev/null 2>&1; then
    TTS_CMD='espeak -v es -w {out} {text}'
  else
    echo "ERROR: no TTS available — set SAVIA_TTS_CMD or install espeak-ng" >&2
    exit 1
  fi
fi

# 4. Synthesize chunks with bounded concurrency
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR" "$CHUNKS_TMP"' EXIT

synthesize_chunk() {
  local idx="$1" chunk_text="$2"
  local out_wav
  out_wav=$(printf '%s/chunk_%04d.wav' "$WORKDIR" "$idx")
  local cmd="${TTS_CMD//\{out\}/$out_wav}"
  cmd="${cmd//\{text\}/$chunk_text}"
  if ! eval "$cmd" >/dev/null 2>"$WORKDIR/chunk_${idx}.err"; then
    echo "ERROR: TTS failed for chunk $idx" >&2
    cat "$WORKDIR/chunk_${idx}.err" >&2
    return 1
  fi
}

idx=0
pids=()
fail=0
while IFS= read -r line; do
  idx=$((idx + 1))
  while [[ "${#pids[@]}" -ge "$CONCURRENCY" ]]; do
    new_pids=()
    for pid in "${pids[@]}"; do
      if kill -0 "$pid" 2>/dev/null; then
        new_pids+=("$pid")
      else
        wait "$pid" || fail=1
      fi
    done
    pids=("${new_pids[@]}")
    [[ "${#pids[@]}" -ge "$CONCURRENCY" ]] && sleep 0.05
  done
  synthesize_chunk "$idx" "$line" &
  pids+=("$!")
done <"$CHUNKS_TMP"

for pid in "${pids[@]}"; do
  wait "$pid" || fail=1
done

if [[ "$fail" -ne 0 ]]; then
  echo "ERROR: one or more chunks failed to synthesize" >&2
  exit 1
fi

# 5. Concatenate
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ERROR: ffmpeg required for concat — install or use a single-chunk input" >&2
  exit 1
fi

LIST_FILE="$WORKDIR/concat.txt"
: > "$LIST_FILE"
for f in "$WORKDIR"/chunk_*.wav; do
  printf "file '%s'\n" "$f" >>"$LIST_FILE"
done

if [[ "$MODE_NOFADE" -eq 1 || "$CHUNK_COUNT" -le 1 ]]; then
  ffmpeg -y -f concat -safe 0 -i "$LIST_FILE" -c copy "$OUT" >/dev/null 2>"$WORKDIR/ffmpeg.err" || {
    echo "ERROR: ffmpeg concat failed" >&2; cat "$WORKDIR/ffmpeg.err" >&2; exit 1; }
else
  # Build acrossfade chain progressively
  inputs=()
  filter=""
  i=0
  for f in "$WORKDIR"/chunk_*.wav; do
    inputs+=(-i "$f")
    i=$((i + 1))
  done
  if [[ "$i" -eq 1 ]]; then
    cp "$WORKDIR"/chunk_*.wav "$OUT"
  else
    # left-fold acrossfade: ((((0,1),2),3),...)
    chain="[0][1]acrossfade=d=$(awk "BEGIN{print $CROSSFADE_MS/1000}"):c1=tri:c2=tri[a1]"
    for ((k=2; k<i; k++)); do
      prev="a$((k-1))"
      cur="a${k}"
      chain="$chain;[$prev][$k]acrossfade=d=$(awk "BEGIN{print $CROSSFADE_MS/1000}"):c1=tri:c2=tri[$cur]"
    done
    last="a$((i-1))"
    ffmpeg -y "${inputs[@]}" -filter_complex "$chain" -map "[$last]" "$OUT" \
      >/dev/null 2>"$WORKDIR/ffmpeg.err" || {
      echo "ERROR: ffmpeg acrossfade failed" >&2; cat "$WORKDIR/ffmpeg.err" >&2; exit 1; }
  fi
fi

echo "ok chunks=$CHUNK_COUNT out=$OUT"
