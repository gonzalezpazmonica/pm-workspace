#!/usr/bin/env python3
"""SaviaClaw Wake Word — VAD + keyword match. Offline, stdlib only."""
import subprocess
import tempfile
import struct
import wave
import os
import time
import shutil

KEYWORD = "savia"

def _audio_env():
    env = os.environ.copy()
    env.setdefault("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    return env
SAMPLE_RATE = 16000
CHUNK_SECONDS = 2
SILENCE_THRESHOLD = 300  # RMS energy — calibrated with Jabra Evolve 65
LISTEN_SECONDS = 4
COOLDOWN_SECONDS = 3  # min gap between triggers


def _rms_energy(wav_path):
    """Calculate RMS energy of a WAV file. Stdlib only."""
    with wave.open(wav_path, 'rb') as wf:
        frames = wf.readframes(wf.getnframes())
    if len(frames) < 2:
        return 0
    samples = struct.unpack(f"<{len(frames)//2}h", frames)
    if not samples:
        return 0
    return int((sum(s * s for s in samples) / len(samples)) ** 0.5)


def _record_chunk(seconds=CHUNK_SECONDS):
    """Record a short audio chunk. Returns path or None."""
    if not shutil.which("arecord"):
        return None
    fd, path = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    try:
        subprocess.run(
            ["arecord", "-D", "pulse", "-f", "S16_LE", "-r", str(SAMPLE_RATE),
             "-c", "1", "-d", str(seconds), "-q", path],
            timeout=seconds + 3, check=True, capture_output=True,
            env=_audio_env())
        return path
    except subprocess.SubprocessError:
        _cleanup(path)
        return None


def _cleanup(path):
    try:
        os.unlink(path)
    except OSError:
        pass


def _match_keyword(wav_path):
    """Check if WAV contains the wake word. Whisper if available."""
    try:
        import whisper
        model = whisper.load_model("tiny")
        result = model.transcribe(wav_path, language="es")
        text = result.get("text", "").lower().strip()
        return KEYWORD in text, text
    except ImportError:
        return True, "(whisper not available — energy trigger only)"


def calibrate():
    """Measure ambient noise. Shows RMS to help set threshold."""
    print("Calibrating... stay quiet for 5 seconds.")
    readings = []
    for i in range(5):
        wav = _record_chunk(1)
        if not wav:
            continue
        rms = _rms_energy(wav)
        readings.append(rms)
        print(f"  Sample {i+1}: RMS={rms}")
        _cleanup(wav)
    if readings:
        avg = sum(readings) // len(readings)
        print(f"Ambient avg: {avg} | Suggested: {avg*3} | Current: {SILENCE_THRESHOLD}")


def listen_loop(on_wake, threshold=SILENCE_THRESHOLD):
    """Main loop: detect voice → check keyword → call on_wake().

    Args:
        on_wake: callback function, receives no args. Called when wake detected.
        threshold: RMS energy threshold for voice detection.
    """
    print(f"Listening for '{KEYWORD}' (threshold={threshold})...")
    last_trigger = 0
    while True:
        wav = _record_chunk(CHUNK_SECONDS)
        if not wav:
            time.sleep(1)
            continue
        rms = _rms_energy(wav)
        if rms > threshold:
            now = time.time()
            if now - last_trigger < COOLDOWN_SECONDS:
                _cleanup(wav)
                continue
            match, text = _match_keyword(wav)
            _cleanup(wav)
            if match:
                print(f"Wake! (RMS={rms}, text='{text}')")
                last_trigger = time.time()
                on_wake()
            else:
                print(f"Voice but no keyword (RMS={rms}, text='{text}')")
        else:
            _cleanup(wav)


def test_vad():
    """Test VAD with 3 samples."""
    print("Testing VAD — speak or stay quiet.")
    for i in range(3):
        wav = _record_chunk(2)
        if wav:
            rms = _rms_energy(wav)
            above = "VOICE" if rms > SILENCE_THRESHOLD else "silence"
            print(f"  Sample {i+1}: RMS={rms} → {above}")
            _cleanup(wav)
        else:
            print(f"  Sample {i+1}: record failed")


if __name__ == "__main__":
    import argparse
    p = argparse.ArgumentParser(description="SaviaClaw Wake Word")
    p.add_argument("--test", action="store_true")
    p.add_argument("--calibrate", action="store_true")
    p.add_argument("--listen", action="store_true")
    args = p.parse_args()
    if args.calibrate:
        calibrate()
    elif args.test:
        test_vad()
    elif args.listen:
        listen_loop(lambda: print(">>> WAKE TRIGGERED <<<"))
    else:
        p.print_help()
