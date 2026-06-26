#!/usr/bin/env python3
"""savia-kokoro.py — SE-075 Slice 3.

CLI wrapper over Kokoro TTS for use from Savia.
Supports text synthesis, stdin input, JSON output, telemetry, and automatic
chunking of long texts (>500 chars) via scripts/lib/sentence-splitter.py.

Usage:
    python3 scripts/savia-kokoro.py --text "Texto" --output /tmp/out.wav
    python3 scripts/savia-kokoro.py --text "Texto" --output /tmp/out.wav --json
    echo "texto" | python3 scripts/savia-kokoro.py --output /tmp/out.wav
    python3 scripts/savia-kokoro.py --text "..." --voice em_alex --lang es --speed 1.2

Voices:
    ef_dora   — Spanish female (default)
    em_alex   — Spanish male
    af_heart  — English female

Environment:
    SAVIA_KOKORO_VOICE     override default voice
    SAVIA_KOKORO_LANG      override default lang
    SAVIA_KOKORO_SPEED     override default speed

Telemetry:
    output/kokoro-telemetry.jsonl  — one JSONL record per call

Reference: SE-075 Slice 3 (docs/propuestas/SE-075-voicebox-adoption.md)
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

# ── Constants ──────────────────────────────────────────────────────────────
SAMPLE_RATE = 24000
LONG_TEXT_THRESHOLD = 500  # chars — triggers sentence-splitter chunking
DEFAULT_VOICE = "ef_dora"
DEFAULT_LANG = "es"
DEFAULT_SPEED = 1.0

SCRIPT_DIR = Path(__file__).resolve().parent
SPLITTER = SCRIPT_DIR / "lib" / "sentence-splitter.py"
REPO_ROOT = SCRIPT_DIR.parent
TELEMETRY_FILE = REPO_ROOT / "output" / "kokoro-telemetry.jsonl"


# ── Telemetry ──────────────────────────────────────────────────────────────

def _write_telemetry(voice: str, lang: str, duration_s: float,
                     chars: int, ok: bool) -> None:
    """Append one record to kokoro-telemetry.jsonl (best-effort, never raises)."""
    try:
        TELEMETRY_FILE.parent.mkdir(parents=True, exist_ok=True)
        record = {
            "ts": datetime.now(timezone.utc).isoformat(),
            "voice": voice,
            "lang": lang,
            "duration_s": round(duration_s, 3),
            "chars": chars,
            "ok": ok,
        }
        with TELEMETRY_FILE.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(record) + "\n")
    except Exception:  # pragma: no cover
        pass


# ── Kokoro synthesis ───────────────────────────────────────────────────────

def _import_kokoro():
    """Import kokoro and soundfile; raise ImportError with install hint if absent."""
    try:
        from kokoro import KPipeline  # type: ignore
        import numpy as np  # noqa: F401
        import soundfile as sf  # noqa: F401
        return KPipeline
    except ImportError as exc:
        raise ImportError(
            "kokoro not installed. Install with: pip install kokoro soundfile"
        ) from exc


def _make_pipeline(KPipeline, lang: str):
    """Create KPipeline, redirecting any stray stdout prints to stderr."""
    import contextlib
    import warnings
    warnings.filterwarnings("ignore", category=FutureWarning)
    warnings.filterwarnings("ignore", category=UserWarning)
    # Some kokoro/torch versions print warnings via print() not logging.
    # Redirect fd 1 → /dev/stderr during init so --json output stays clean.
    with contextlib.redirect_stdout(sys.stderr):
        return KPipeline(lang_code=lang)


def _synthesize_text(text: str, voice: str, lang: str, speed: float,
                     output: Path) -> float:
    """Synthesize *text* to *output* .wav. Returns duration in seconds."""
    KPipeline = _import_kokoro()
    import numpy as np
    import soundfile as sf

    pipeline = _make_pipeline(KPipeline, lang)
    samples = []
    for _, _, audio in pipeline(text, voice=voice, speed=speed):
        arr = audio.numpy() if hasattr(audio, "numpy") else audio
        samples.append(arr)

    if not samples:
        raise RuntimeError("Kokoro produced no audio samples")

    combined = np.concatenate(samples).astype("float32")
    sf.write(str(output), combined, SAMPLE_RATE)
    return len(combined) / SAMPLE_RATE


def _synthesize_chunks(text: str, voice: str, lang: str, speed: float,
                       output: Path) -> float:
    """Split *text* into sentence chunks, synthesize each, concat with ffmpeg."""
    import numpy as np
    import soundfile as sf
    KPipeline = _import_kokoro()

    # Get chunks from sentence-splitter
    result = subprocess.run(
        [sys.executable, str(SPLITTER), "--max-chars", "500"],
        input=text,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"sentence-splitter failed: {result.stderr}")

    chunks = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    if not chunks:
        raise RuntimeError("sentence-splitter returned no chunks")

    pipeline = _make_pipeline(KPipeline, lang)

    chunk_wavs: list[Path] = []
    with tempfile.TemporaryDirectory() as tmpdir:
        for idx, chunk in enumerate(chunks):
            chunk_path = Path(tmpdir) / f"chunk_{idx:04d}.wav"
            samples = []
            for _, _, audio in pipeline(chunk, voice=voice, speed=speed):
                arr = audio.numpy() if hasattr(audio, "numpy") else audio
                samples.append(arr)
            if samples:
                combined = np.concatenate(samples).astype("float32")
                sf.write(str(chunk_path), combined, SAMPLE_RATE)
                chunk_wavs.append(chunk_path)

        if not chunk_wavs:
            raise RuntimeError("No chunks produced audio")

        if len(chunk_wavs) == 1:
            import shutil
            shutil.copy(str(chunk_wavs[0]), str(output))
        else:
            # Concatenate with ffmpeg if available, else numpy concat
            if _ffmpeg_available():
                list_file = Path(tmpdir) / "concat.txt"
                with list_file.open("w") as fh:
                    for w in chunk_wavs:
                        fh.write(f"file '{w}'\n")
                proc = subprocess.run(
                    ["ffmpeg", "-y", "-f", "concat", "-safe", "0",
                     "-i", str(list_file), "-c", "copy", str(output)],
                    capture_output=True,
                )
                if proc.returncode != 0:
                    raise RuntimeError(
                        f"ffmpeg concat failed: {proc.stderr.decode()}"
                    )
            else:
                # numpy fallback
                all_samples = []
                for w in chunk_wavs:
                    data, _ = sf.read(str(w), dtype="float32")
                    all_samples.append(data)
                sf.write(str(output), np.concatenate(all_samples), SAMPLE_RATE)

        # Measure final duration
        data, sr = sf.read(str(output), dtype="float32")
        return len(data) / sr


def _ffmpeg_available() -> bool:
    try:
        subprocess.run(["ffmpeg", "-version"], capture_output=True, check=True)
        return True
    except (FileNotFoundError, subprocess.CalledProcessError):
        return False


# ── CLI ────────────────────────────────────────────────────────────────────

def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    ap = argparse.ArgumentParser(
        prog="savia-kokoro.py",
        description="Kokoro CPU TTS wrapper for Savia — SE-075 Slice 3",
    )
    ap.add_argument("--text", help="Text to synthesize (also accepts stdin)")
    ap.add_argument("--output", required=True, help="Output WAV path")
    ap.add_argument("--voice",
                    default=os.environ.get("SAVIA_KOKORO_VOICE", DEFAULT_VOICE),
                    help="Voice id (ef_dora, em_alex, af_heart)")
    ap.add_argument("--lang",
                    default=os.environ.get("SAVIA_KOKORO_LANG", DEFAULT_LANG),
                    help="Language code (es, en-us)")
    ap.add_argument("--speed", type=float,
                    default=float(os.environ.get("SAVIA_KOKORO_SPEED", DEFAULT_SPEED)),
                    help="Speech speed multiplier (default 1.0)")
    ap.add_argument("--json", action="store_true", dest="json_out",
                    help="Print JSON result to stdout")
    return ap.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)

    # ── Resolve text ──────────────────────────────────────────────────────
    text = args.text
    if not text and not sys.stdin.isatty():
        text = sys.stdin.read()
    if not text or not text.strip():
        msg = "ERROR: no text provided — use --text or pipe stdin"
        if args.json_out:
            print(json.dumps({"error": msg}))
        else:
            print(msg, file=sys.stderr)
        return 1

    text = text.strip()
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    # ── Check kokoro available ────────────────────────────────────────────
    try:
        _import_kokoro()
    except ImportError as exc:
        payload = {
            "error": "kokoro not installed",
            "install": "pip install kokoro soundfile",
            "detail": str(exc),
        }
        if args.json_out:
            print(json.dumps(payload))
        else:
            print(json.dumps(payload), file=sys.stderr)
        return 1

    # ── Synthesize ────────────────────────────────────────────────────────
    t0 = time.monotonic()
    ok = False
    duration_s = 0.0
    error_msg: str | None = None

    try:
        if len(text) > LONG_TEXT_THRESHOLD:
            duration_s = _synthesize_chunks(
                text, args.voice, args.lang, args.speed, output
            )
        else:
            duration_s = _synthesize_text(
                text, args.voice, args.lang, args.speed, output
            )
        ok = True
    except Exception as exc:
        error_msg = str(exc)

    elapsed = time.monotonic() - t0

    # ── Telemetry ─────────────────────────────────────────────────────────
    _write_telemetry(
        voice=args.voice,
        lang=args.lang,
        duration_s=duration_s,
        chars=len(text),
        ok=ok,
    )

    # ── Output ────────────────────────────────────────────────────────────
    if not ok:
        payload = {"error": error_msg or "synthesis failed"}
        if args.json_out:
            print(json.dumps(payload))
        else:
            print(f"ERROR: {error_msg}", file=sys.stderr)
        return 1

    if args.json_out:
        print(json.dumps({
            "file": str(output.resolve()),
            "duration_s": round(duration_s, 3),
            "voice": args.voice,
            "lang": args.lang,
            "chars": len(text),
            "elapsed_s": round(elapsed, 3),
        }))
    else:
        print(f"ok file={output} duration={duration_s:.3f}s")

    return 0


if __name__ == "__main__":
    sys.exit(main())
