#!/usr/bin/env python3
"""Tests for ZeroClaw network setup — runs without hardware."""
import sys
import os
import json
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from host.network_setup import (
    detect_ssid, detect_host_ip, generate_esp32_config)

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


def test_detect_ssid_returns_string_or_none():
    result = detect_ssid()
    assert result is None or isinstance(result, str)


def test_detect_host_ip_returns_string_or_none():
    result = detect_host_ip()
    assert result is None or isinstance(result, str)
    if result:
        parts = result.split('.')
        assert len(parts) == 4, f"not valid IP: {result}"


def test_generate_config_structure():
    cfg = generate_esp32_config("TestSSID", "pass123", "192.168.1.100")
    assert cfg["wifi_ssid"] == "TestSSID"
    assert cfg["wifi_pass"] == "pass123"
    assert "192.168.1.100" in cfg["host_url"]
    assert cfg["device_id"] == "zeroclaw-01"
    assert "watchdog_ms" in cfg


def test_generate_config_custom_port():
    cfg = generate_esp32_config("Net", "pw", "10.0.0.1", host_port=9999)
    assert "9999" in cfg["host_url"]


def test_config_has_no_secrets_in_default():
    base = os.path.join(os.path.dirname(__file__), '..', 'firmware', 'config.json')
    with open(base) as f:
        cfg = json.load(f)
    assert cfg["wifi_ssid"] == "" or cfg["wifi_ssid"] == "TestSSID"


def test_wifi_server_file_exists():
    path = os.path.join(os.path.dirname(__file__), '..',
                        'firmware', 'lib', 'wifi_server.py')
    assert os.path.isfile(path), "wifi_server.py missing"


def test_wifi_server_under_150_lines():
    path = os.path.join(os.path.dirname(__file__), '..',
                        'firmware', 'lib', 'wifi_server.py')
    with open(path) as f:
        lines = len(f.readlines())
    assert lines <= 150, f"wifi_server.py: {lines} lines"


def test_main_py_dual_mode():
    """Verify main.py imports wifi_server conditionally."""
    path = os.path.join(os.path.dirname(__file__), '..',
                        'firmware', 'main.py')
    with open(path) as f:
        content = f.read()
    assert 'wifi_server' in content, "main.py should reference wifi_server"
    assert 'http_server.poll()' in content, "main.py should poll HTTP"
    assert 'sys.stdin.buffer.any()' in content, "main.py should check serial"


if __name__ == "__main__":
    print("ZeroClaw Network Tests (no hardware required)")
    print("─" * 45)
    test("SSID detection returns str or None", test_detect_ssid_returns_string_or_none)
    test("Host IP detection returns valid IP", test_detect_host_ip_returns_string_or_none)
    test("Config has correct structure", test_generate_config_structure)
    test("Config custom port", test_generate_config_custom_port)
    test("Default config has no secrets", test_config_has_no_secrets_in_default)
    test("wifi_server.py exists", test_wifi_server_file_exists)
    test("wifi_server.py ≤150 lines", test_wifi_server_under_150_lines)
    test("main.py dual mode (serial+WiFi)", test_main_py_dual_mode)
    print(f"\n{passed} passed, {failed} failed")
    sys.exit(1 if failed else 0)
