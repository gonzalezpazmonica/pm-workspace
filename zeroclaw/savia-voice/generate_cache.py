#!/usr/bin/env python3
"""Generate audio cache for all phrases — run once, commit to git.

Usage:
  python generate_cache.py [--voice ef_dora] [--lang es]

Generates WAV files in cache/es/ (or cache/{lang}/) that are
committed to git. Users who clone the repo get instant TTS
without needing to run Kokoro at startup.
"""

import argparse
import sys
import time
import wave
from pathlib import Path

import numpy as np

from tts_cache import CACHE_PHRASES, FILLERS, STALLS, KOKORO_RATE


def safe_filename(text):
    """Convert phrase to filesystem-safe name."""
    name = text.lower().strip()
    for ch in ".,;:!?¿¡\"'()[]{}":
        name = name.replace(ch, "")
    name = name.replace(" ", "_").replace("…", "").replace("...", "")
    return name[:60]  # limit length


def main():
    parser = argparse.ArgumentParser(description="Generate TTS audio cache")
    parser.add_argument("--voice", default="ef_dora", help="Kokoro voice")
    parser.add_argument("--lang", default="es", help="Language code")
    args = parser.parse_args()

    out_dir = Path(__file__).parent / "cache" / args.lang
    out_dir.mkdir(parents=True, exist_ok=True)

    # Collect all phrases
    all_phrases = []
    for phrase in CACHE_PHRASES:
        all_phrases.append(("response", phrase))
    for cat, phrases in FILLERS.items():
        for p in phrases:
            all_phrases.append((f"filler-{cat}", p))
    for cat, phrases in STALLS.items():
        for p in phrases:
            all_phrases.append((f"stall-{cat}", p))

    print(f"Generating {len(all_phrases)} audio files in {out_dir}/")
    print(f"Voice: {args.voice} | Lang: {args.lang}")
    print()

    # Load Kokoro
    print("Loading Kokoro...")
    from kokoro import KPipeline
    pipe = KPipeline(lang_code="e", repo_id="hexgrad/Kokoro-82M")
    print("Kokoro ready.\n")

    generated = 0
    skipped = 0
    errors = 0

    for category, phrase in all_phrases:
        fname = safe_filename(phrase)
        wav_path = out_dir / f"{fname}.wav"

        if wav_path.exists():
            skipped += 1
            continue

        try:
            t0 = time.time()
            segs = list(pipe(phrase, voice=args.voice))
            if not segs:
                print(f"  SKIP (no output): {phrase}")
                errors += 1
                continue

            audio = np.concatenate([s[2] for s in segs])
            data = (audio * 32767).astype(np.int16)

            with wave.open(str(wav_path), "wb") as wf:
                wf.setnchannels(1)
                wf.setsampwidth(2)
                wf.setframerate(KOKORO_RATE)
                wf.writeframes(data.tobytes())

            dur = len(data) / KOKORO_RATE
            elapsed = time.time() - t0
            print(f"  [{category}] \"{phrase}\" → {fname}.wav "
                  f"({dur:.1f}s audio, {elapsed:.1f}s gen)")
            generated += 1

        except Exception as e:
            print(f"  ERROR: {phrase} → {e}")
            errors += 1

    print(f"\nDone: {generated} generated, {skipped} skipped, "
          f"{errors} errors")
    print(f"Total files: {len(list(out_dir.glob('*.wav')))}")
    total_mb = sum(f.stat().st_size for f in out_dir.glob("*.wav")) / 1e6
    print(f"Total size: {total_mb:.1f} MB")


if __name__ == "__main__":
    main()
