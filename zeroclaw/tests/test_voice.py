#!/usr/bin/env python3
"""Tests for voice module — runs without audio hardware."""
import sys
import os
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


def test_import():
    from host.voice import say, record, listen, check_deps, transcribe
    assert callable(say)
    assert callable(record)
    assert callable(listen)
    assert callable(check_deps)
    assert callable(transcribe)


def test_check_deps_returns_dict():
    from host.voice import check_deps
    deps = check_deps()
    assert isinstance(deps, dict)
    for key in ["espeak-ng", "spd-say", "arecord", "aplay"]:
        assert key in deps
    assert isinstance(deps["espeak-ng"], bool)


def test_say_no_crash_without_tts():
    from host.voice import say
    # Should not crash even if no TTS backend
    result = say("test", lang="es")
    assert isinstance(result, bool)


def test_record_no_crash_without_device():
    from host.voice import record
    # Should return None gracefully without audio device
    result = record(seconds=1)
    # Either returns a path or None — should not crash
    assert result is None or os.path.isfile(result)
    if result:
        os.unlink(result)


def test_listen_no_crash():
    from host.voice import listen
    result = listen(seconds=1)
    assert result is None or isinstance(result, str)


def test_constants():
    from host import voice
    assert voice.LANG == "es"
    assert voice.SAMPLE_RATE == 16000
    assert voice.RECORD_SECONDS >= 1
    assert voice.WHISPER_MODEL in ("tiny", "base", "small", "medium")


def test_file_size():
    path = os.path.join(os.path.dirname(__file__), '..', 'host', 'voice.py')
    with open(path) as f:
        lines = len(f.readlines())
    assert lines <= 150, f"voice.py has {lines} lines (max 150)"


if __name__ == "__main__":
    print("SaviaClaw Voice Tests (no hardware required)")
    print("-" * 45)
    test("Import voice module", test_import)
    test("check_deps returns dict", test_check_deps_returns_dict)
    test("say doesn't crash", test_say_no_crash_without_tts)
    test("record doesn't crash", test_record_no_crash_without_device)
    test("listen doesn't crash", test_listen_no_crash)
    test("Constants valid", test_constants)
    test("File size <= 150", test_file_size)
    print(f"\n{passed} passed, {failed} failed")
    sys.exit(1 if failed else 0)
