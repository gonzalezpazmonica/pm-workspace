#!/usr/bin/env python3
"""Tests for ZeroClaw host bridge — runs without ESP32 hardware."""
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

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


def test_import():
    from host.bridge import ZeroClawBridge
    assert ZeroClawBridge is not None


def test_detect_no_port():
    from host.bridge import ZeroClawBridge
    b = ZeroClawBridge(port="/dev/nonexistent")
    assert not b.connect()


def test_send_without_connect():
    from host.bridge import ZeroClawBridge
    b = ZeroClawBridge(port="/dev/nonexistent")
    result = b.send_command("ping")
    assert "error" in result
    assert result["error"] == "not connected"


def test_firmware_files_exist():
    base = os.path.join(os.path.dirname(__file__), '..', 'firmware')
    for f in ['boot.py', 'main.py', 'config.json']:
        path = os.path.join(base, f)
        assert os.path.isfile(path), f"Missing: {f}"


def test_firmware_lib_files():
    base = os.path.join(os.path.dirname(__file__), '..', 'firmware', 'lib')
    for f in ['status.py', 'commands.py']:
        path = os.path.join(base, f)
        assert os.path.isfile(path), f"Missing: lib/{f}"


def test_config_valid_json():
    import json
    path = os.path.join(os.path.dirname(__file__), '..', 'firmware', 'config.json')
    with open(path) as f:
        cfg = json.load(f)
    assert "device_id" in cfg
    assert "version" in cfg
    assert cfg["wifi_ssid"] == ""  # Should be empty in repo


def test_firmware_no_secrets():
    """Verify no hardcoded secrets in firmware files."""
    import re
    base = os.path.join(os.path.dirname(__file__), '..', 'firmware')
    for root, _, files in os.walk(base):
        for fname in files:
            if not fname.endswith('.py') and not fname.endswith('.json'):
                continue
            path = os.path.join(root, fname)
            with open(path) as f:
                content = f.read()
            # Check for common secret patterns
            assert not re.search(r'password\s*=\s*["\'][^"\']{4,}', content, re.I), \
                f"Possible password in {fname}"
            assert not re.search(r'ssid\s*=\s*["\'][^"\']{2,}', content, re.I), \
                f"Possible SSID in {fname}"


def test_setup_script_exists():
    path = os.path.join(os.path.dirname(__file__), '..', 'setup.sh')
    assert os.path.isfile(path)


def test_file_sizes():
    """All firmware files must be ≤150 lines."""
    base = os.path.join(os.path.dirname(__file__), '..', 'firmware')
    for root, _, files in os.walk(base):
        for fname in files:
            if not fname.endswith('.py'):
                continue
            path = os.path.join(root, fname)
            with open(path) as f:
                lines = len(f.readlines())
            assert lines <= 150, f"{fname}: {lines} lines (max 150)"


if __name__ == "__main__":
    print("ZeroClaw Bridge Tests (no hardware required)")
    print("─" * 45)
    test("Import bridge", test_import)
    test("No port detected", test_detect_no_port)
    test("Command without connection", test_send_without_connect)
    test("Firmware files exist", test_firmware_files_exist)
    test("Firmware lib files", test_firmware_lib_files)
    test("Config valid JSON", test_config_valid_json)
    test("No secrets in firmware", test_firmware_no_secrets)
    test("Setup script exists", test_setup_script_exists)
    test("File sizes ≤150 lines", test_file_sizes)
    print(f"\n{passed} passed, {failed} failed")
    sys.exit(1 if failed else 0)
