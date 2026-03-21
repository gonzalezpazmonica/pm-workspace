#!/usr/bin/env python3
"""Tests for ZeroClaw guardrails — verifies gates are deterministic."""
import sys
import os
import tempfile
import time
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from host.guardrails import (
    gate_size, gate_rate, gate_command, gate_pii,
    gate_storage, gate_raw_cleanup, validate_incoming,
    ALLOWED_COMMANDS, _rate_log
)

passed = 0
failed = 0


def test(name, fn):
    global passed, failed
    try:
        fn()
        print(f"  ✅ {name}")
        passed += 1
    except Exception as e:
        print(f"  ❌ {name}: {e}")
        failed += 1


def test_size_blocks_oversized_audio():
    huge = b'\x00' * (6 * 1024 * 1024)  # 6MB > 5MB limit
    ok, reason = gate_size(huge, "audio")
    assert not ok, "should block oversized audio"
    assert "BLOCKED" in reason


def test_size_allows_normal_audio():
    normal = b'\x00' * (1 * 1024 * 1024)  # 1MB
    ok, _ = gate_size(normal, "audio")
    assert ok, "should allow normal audio"


def test_size_blocks_oversized_image():
    huge = b'\x00' * (3 * 1024 * 1024)  # 3MB > 2MB limit
    ok, _ = gate_size(huge, "image")
    assert not ok, "should block oversized image"


def test_rate_blocks_flooding():
    _rate_log.clear()
    for i in range(5):
        ok, _ = gate_rate("audio")
        assert ok, f"attempt {i+1} should pass"
    ok, reason = gate_rate("audio")
    assert not ok, "6th attempt should be blocked"
    assert "rate limit" in reason


def test_command_blocks_unknown():
    ok, _ = gate_command("ping")
    assert ok, "ping should be allowed"
    ok, reason = gate_command("rm_rf_slash")
    assert not ok, "unknown command must be blocked"
    assert "BLOCKED" in reason


def test_command_allowlist_complete():
    for cmd in ["ping", "led", "info", "sensors", "gpio", "help"]:
        ok, _ = gate_command(cmd)
        assert ok, f"{cmd} should be allowed"


def test_pii_detects_email():
    has_pii, findings = gate_pii("Contact me at john@example.com")
    assert has_pii, "should detect email"
    assert any("email" in f for f in findings)


def test_pii_clean_text():
    has_pii, _ = gate_pii("Connect the red wire to GPIO23")
    assert not has_pii, "clean text should have no PII"


def test_pii_detects_phone():
    has_pii, findings = gate_pii("Call me at 612345678")
    assert has_pii, "should detect phone pattern"


def test_storage_blocks_when_full():
    with tempfile.TemporaryDirectory() as d:
        # Create a big file that exceeds quota
        big_file = os.path.join(d, "big.bin")
        with open(big_file, "wb") as f:
            f.write(b'\x00' * (101 * 1024 * 1024))  # 101MB
        ok, reason = gate_storage(d, max_mb=100)
        assert not ok, "should block when storage full"


def test_raw_cleanup_deletes_old():
    with tempfile.TemporaryDirectory() as d:
        # Create a file and backdate it
        old_file = os.path.join(d, "old.wav")
        with open(old_file, "w") as f:
            f.write("old data")
        os.utime(old_file, (time.time() - 7200, time.time() - 7200))
        deleted = gate_raw_cleanup(d)
        assert deleted == 1, f"should delete 1 file, got {deleted}"
        assert not os.path.exists(old_file)


def test_validate_incoming_blocks_bad_data():
    _rate_log.clear()
    huge = b'\x00' * (6 * 1024 * 1024)
    ok, reasons = validate_incoming(huge, "audio")
    assert not ok, "should block oversized"
    assert len(reasons) >= 1


def test_validate_incoming_passes_good_data():
    _rate_log.clear()
    ok, reasons = validate_incoming(b'\x00' * 1000, "sensor", command="ping")
    assert ok, f"should pass: {reasons}"


def test_validate_blocks_bad_command():
    _rate_log.clear()
    ok, reasons = validate_incoming(b'', "sensor", command="evil_cmd")
    assert not ok, "should block unknown command"


if __name__ == "__main__":
    print("ZeroClaw Guardrails Tests")
    print("─" * 45)
    test("Size blocks oversized audio", test_size_blocks_oversized_audio)
    test("Size allows normal audio", test_size_allows_normal_audio)
    test("Size blocks oversized image", test_size_blocks_oversized_image)
    test("Rate blocks flooding", test_rate_blocks_flooding)
    test("Command blocks unknown", test_command_blocks_unknown)
    test("Command allowlist complete", test_command_allowlist_complete)
    test("PII detects email", test_pii_detects_email)
    test("PII clean text", test_pii_clean_text)
    test("PII detects phone", test_pii_detects_phone)
    test("Storage blocks when full", test_storage_blocks_when_full)
    test("Raw cleanup deletes old", test_raw_cleanup_deletes_old)
    test("Validate blocks bad data", test_validate_incoming_blocks_bad_data)
    test("Validate passes good data", test_validate_incoming_passes_good_data)
    test("Validate blocks bad command", test_validate_blocks_bad_command)
    print(f"\n{passed} passed, {failed} failed")
    sys.exit(1 if failed else 0)
