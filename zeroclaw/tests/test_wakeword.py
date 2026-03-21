#!/usr/bin/env python3
"""Tests for wake word module — runs without audio hardware."""
import sys
import os
import struct
import wave
import tempfile
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

passed = 0
failed = 0


def test(name, fn):
    global passed, failed
    try:
        fn()
        print(f"  OK  {name}")
        passed += 1
    except Exception as e:
        print(f"  FAIL {name}: {e}")
        failed += 1


def _make_wav(path, samples, rate=16000):
    with wave.open(path, 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(rate)
        wf.writeframes(struct.pack(f"<{len(samples)}h", *samples))


def test_import():
    from host.wakeword import listen_loop, calibrate, test_vad, _rms_energy
    assert callable(listen_loop)
    assert callable(_rms_energy)


def test_rms_silence():
    from host.wakeword import _rms_energy
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        path = f.name
    _make_wav(path, [0] * 1600)
    rms = _rms_energy(path)
    os.unlink(path)
    assert rms == 0, f"silence should be 0, got {rms}"


def test_rms_loud():
    from host.wakeword import _rms_energy
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        path = f.name
    _make_wav(path, [10000, -10000] * 800)
    rms = _rms_energy(path)
    os.unlink(path)
    assert rms > 5000, f"loud signal should have high RMS, got {rms}"


def test_rms_empty():
    from host.wakeword import _rms_energy
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        path = f.name
    _make_wav(path, [])
    rms = _rms_energy(path)
    os.unlink(path)
    assert rms == 0


def test_keyword_match_no_whisper():
    from host.wakeword import _match_keyword
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        path = f.name
    _make_wav(path, [0] * 1600)
    match, text = _match_keyword(path)
    os.unlink(path)
    # Without whisper, should return True (energy-only fallback)
    assert match is True


def test_constants():
    from host import wakeword
    assert wakeword.KEYWORD == "savia"
    assert wakeword.SAMPLE_RATE == 16000
    assert wakeword.COOLDOWN_SECONDS >= 1


def test_file_size():
    path = os.path.join(os.path.dirname(__file__), '..', 'host', 'wakeword.py')
    with open(path) as f:
        lines = len(f.readlines())
    assert lines <= 150, f"wakeword.py has {lines} lines (max 150)"


if __name__ == "__main__":
    print("SaviaClaw Wake Word Tests (no hardware required)")
    print("-" * 48)
    test("Import wakeword", test_import)
    test("RMS silence = 0", test_rms_silence)
    test("RMS loud > 5000", test_rms_loud)
    test("RMS empty = 0", test_rms_empty)
    test("Keyword match fallback", test_keyword_match_no_whisper)
    test("Constants valid", test_constants)
    test("File size <= 150", test_file_size)
    print(f"\n{passed} passed, {failed} failed")
    sys.exit(1 if failed else 0)
