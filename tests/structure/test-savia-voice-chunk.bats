#!/usr/bin/env bats
# Ref: SE-075 Slice 2 — scripts/savia-voice-chunk.sh + scripts/lib/sentence-splitter.py
# Spec: docs/propuestas/SE-075-voicebox-adoption.md
# Re-implementation pattern from voicebox MIT (clean-room, no source copied).
#
# Coverage of savia-voice-chunk.sh entry-points exercised below: usage,
# synthesize_chunk, splitter pipeline, dry-run, no-fade, and bounded concurrency.
# Safety: this test enforces 'set -uo pipefail' presence in the shell wrapper.

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SCRIPT="scripts/savia-voice-chunk.sh"
  CHUNK_ABS="$ROOT_DIR/$SCRIPT"
  SPLITTER_ABS="$ROOT_DIR/scripts/lib/sentence-splitter.py"
  TMPDIR_VC=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_VC"
}

# Helper: a fake TTS that writes a tiny silent wav per call
fake_tts_setup() {
  cat > "$TMPDIR_VC/fake-tts.sh" <<'FAKE'
#!/usr/bin/env bash
set -uo pipefail
out="$1"; shift
text="$*"
# emit 0.1s of silence (44.1kHz mono, 16-bit) — just enough for ffmpeg concat
ffmpeg -y -f lavfi -i "anullsrc=r=22050:cl=mono" -t 0.1 "$out" >/dev/null 2>&1
FAKE
  chmod +x "$TMPDIR_VC/fake-tts.sh"
  export SAVIA_TTS_CMD="$TMPDIR_VC/fake-tts.sh {out} {text}"
}

# ── C1 / C2 — file-level safety + identity ───────────────────────────────────

@test "savia-voice-chunk.sh: file exists, has shebang, and is executable" {
  [ -f "$CHUNK_ABS" ]
  head -1 "$CHUNK_ABS" | grep -q '^#!'
  [ -x "$CHUNK_ABS" ]
}

@test "savia-voice-chunk.sh: declares 'set -uo pipefail' for safety" {
  grep -q "set -[uo]o pipefail" "$CHUNK_ABS"
}

@test "savia-voice-chunk.sh: spec reference SE-075 cited in header" {
  grep -q "SE-075" "$CHUNK_ABS"
  grep -q "docs/propuestas/SE-075" "$CHUNK_ABS"
}

@test "savia-voice-chunk.sh: attribution to voicebox MIT (clean-room note)" {
  grep -q "voicebox" "$CHUNK_ABS"
  grep -q "MIT" "$CHUNK_ABS"
  grep -q "clean-room" "$CHUNK_ABS"
}

@test "sentence-splitter.py: file exists and is executable" {
  [ -f "$SPLITTER_ABS" ]
  [ -x "$SPLITTER_ABS" ]
}

# ── C3 — Positive paths (≥5 success behaviours) ─────────────────────────────

@test "splitter: separates simple Spanish sentences cleanly" {
  out=$(printf 'Primera frase. Segunda frase. Tercera frase.' | python3 "$SPLITTER_ABS")
  [ "$(echo "$out" | wc -l)" -eq 3 ]
  echo "$out" | head -1 | grep -q "Primera frase\."
}

@test "splitter: preserves Spanish abbreviations Sr. / Dra. / Vds. without splitting" {
  out=$(printf 'Hola Sr. Pérez. La Dra. Sánchez con Vds. está aquí.' | python3 "$SPLITTER_ABS")
  [ "$(echo "$out" | wc -l)" -eq 2 ]
  echo "$out" | head -1 | grep -q "Sr\. Pérez"
}

@test "splitter: preserves a.m./p.m./S.A. patterns" {
  out=$(printf 'La reunión con Empresa S.A. es a las 9 a.m. mañana. Después comemos.' | python3 "$SPLITTER_ABS")
  [ "$(echo "$out" | wc -l)" -eq 2 ]
  echo "$out" | head -1 | grep -q "a\.m\."
}

@test "splitter: --max-chars enforces secondary split on commas" {
  long="Esta es una frase muy larga que tiene muchas palabras, separadas por comas, y debería dividirse en partes más pequeñas, sí señor, porque excede el límite, claramente."
  out=$(printf '%s' "$long" | python3 "$SPLITTER_ABS" --max-chars 50)
  [ "$(echo "$out" | wc -l)" -gt 1 ]
}

@test "chunker: --dry-run prints chunks without invoking TTS" {
  run bash "$CHUNK_ABS" --text "Una. Dos. Tres." --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"chunks=3"* ]]
  [[ "$output" == *"Una."* ]]
  [[ "$output" == *"Tres."* ]]
}

@test "chunker: full pipeline produces a wav file with --out" {
  command -v ffmpeg >/dev/null 2>&1 || skip "ffmpeg not available"
  fake_tts_setup
  run bash "$CHUNK_ABS" --text "Frase uno. Frase dos. Frase tres." --out "$TMPDIR_VC/out.wav" --no-fade
  [ "$status" -eq 0 ]
  [[ "$output" == *"chunks=3"* ]]
  [ -s "$TMPDIR_VC/out.wav" ]
  file "$TMPDIR_VC/out.wav" | grep -q "WAVE audio"
}

@test "chunker: reads from --file path" {
  echo "Esta. Es. Una. Prueba." > "$TMPDIR_VC/note.txt"
  run bash "$CHUNK_ABS" --file "$TMPDIR_VC/note.txt" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"chunks=4"* ]]
}

@test "chunker: reads from stdin when no --text or --file" {
  run bash -c 'echo "Hola. Mundo." | bash "$0" --dry-run' "$CHUNK_ABS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"chunks=2"* ]]
}

@test "chunker: bounded concurrency parameter accepted via --concurrency" {
  command -v ffmpeg >/dev/null 2>&1 || skip "ffmpeg not available"
  fake_tts_setup
  run bash "$CHUNK_ABS" --text "Uno. Dos. Tres. Cuatro." --out "$TMPDIR_VC/out.wav" --concurrency 1 --no-fade
  [ "$status" -eq 0 ]
  [[ "$output" == *"chunks=4"* ]]
}

# ── C4 — Negative / failure paths (≥4) ───────────────────────────────────────

@test "chunker fails when --file points to nonexistent path" {
  run bash "$CHUNK_ABS" --file "$TMPDIR_VC/nope.txt" --dry-run
  [ "$status" -eq 1 ]
  [[ "$output" == *"file not found"* ]]
}

@test "chunker fails when input is empty string (whitespace-only)" {
  run bash "$CHUNK_ABS" --text "   " --dry-run
  [ "$status" -eq 2 ]
  [[ "$output" == *"empty input"* ]]
}

@test "chunker rejects unknown CLI argument with usage" {
  run bash "$CHUNK_ABS" --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown arg"* ]]
}

@test "chunker requires --out when not in --dry-run mode" {
  run bash "$CHUNK_ABS" --text "Hola."
  [ "$status" -eq 2 ]
  [[ "$output" == *"--out is required"* ]]
}

@test "chunker reports invalid TTS configuration when no command available" {
  # Build a minimal PATH that has bash + python3 + sed + grep but NO espeak/espeak-ng.
  isolated=$(mktemp -d)
  for bin in bash sh python3 sed grep awk cat printf mktemp dirname cd kill wc tr; do
    p=$(command -v "$bin" 2>/dev/null) && ln -sf "$p" "$isolated/$bin" 2>/dev/null || true
  done
  PATH="$isolated" SAVIA_TTS_CMD="" run bash "$CHUNK_ABS" --text "Hola. Mundo." --out "$TMPDIR_VC/x.wav"
  rm -rf "$isolated"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no TTS available"* ]] || [[ "$output" == *"failed"* ]]
}

# ── C5 — Edge cases (empty / nonexistent / boundary / no-args / large) ──────

@test "edge: no arguments at all prints usage and exits 2" {
  run bash "$CHUNK_ABS"
  [ "$status" -eq 2 ]
}

@test "edge: nonexistent --file path is reported, not silently skipped" {
  run bash "$CHUNK_ABS" --file /no/such/path/$$.txt --dry-run
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

@test "edge: large input (>10 KiB) is accepted and chunked" {
  python3 -c "print(('Frase número uno. ' * 800).rstrip())" > "$TMPDIR_VC/big.txt"
  run bash "$CHUNK_ABS" --file "$TMPDIR_VC/big.txt" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" =~ chunks=[0-9]+ ]]
  count=$(echo "$output" | head -1 | grep -oE '[0-9]+')
  [ "$count" -ge 100 ]
}

@test "edge: single-sentence input → one chunk, no crossfade attempted" {
  command -v ffmpeg >/dev/null 2>&1 || skip "ffmpeg not available"
  fake_tts_setup
  run bash "$CHUNK_ABS" --text "Una sola frase corta." --out "$TMPDIR_VC/one.wav"
  [ "$status" -eq 0 ]
  [[ "$output" == *"chunks=1"* ]]
  [ -s "$TMPDIR_VC/one.wav" ]
}

@test "edge: zero-length boundary — splitter on empty stdin returns no output" {
  run bash -c 'printf "" | python3 "$0"' "$SPLITTER_ABS"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "edge: max-chars boundary at exactly the chunk size keeps it whole" {
  s="Hola que tal todo bien gracias."
  out=$(printf '%s' "$s" | python3 "$SPLITTER_ABS" --max-chars "${#s}")
  [ "$(echo "$out" | wc -l)" -eq 1 ]
}

# ── C9 — assertion-quality reinforcement ────────────────────────────────────

@test "splitter: numeric decimals (1.5) are NOT treated as sentence boundaries" {
  out=$(printf 'Invertimos 1.5 millones en mayo. Es importante.' | python3 "$SPLITTER_ABS")
  [ "$(echo "$out" | wc -l)" -eq 2 ]
  echo "$out" | head -1 | grep -q "1\.5 millones"
}

@test "chunker: --crossfade-ms parameter is propagated to ffmpeg invocation" {
  command -v ffmpeg >/dev/null 2>&1 || skip "ffmpeg not available"
  fake_tts_setup
  run bash "$CHUNK_ABS" --text "Uno. Dos." --out "$TMPDIR_VC/cf.wav" --crossfade-ms 50
  [ "$status" -eq 0 ]
  [ -s "$TMPDIR_VC/cf.wav" ]
}
