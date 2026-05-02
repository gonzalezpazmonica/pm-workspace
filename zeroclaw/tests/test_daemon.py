#!/usr/bin/env python3
"""Tests for SaviaClaw daemon — runs without hardware."""
import sys
import os
import json
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


def test_import_util():
    from host.daemon_util import (
        find_port, truncate_lcd, call_llm, write_status, show_status)
    assert callable(find_port)
    assert callable(truncate_lcd)


def test_import_daemon():
    from host.saviaclaw_daemon import _handle_signal, run_daemon, setup_logging
    assert callable(_handle_signal)
    assert callable(run_daemon)


def test_truncate_lcd_short():
    from host.daemon_util import truncate_lcd
    l1, l2 = truncate_lcd("Hello")
    assert l1 == "Hello"
    assert l2 == ""


def test_truncate_lcd_two_lines():
    from host.daemon_util import truncate_lcd
    text = "This is a long message for the LCD display"
    l1, l2 = truncate_lcd(text)
    assert len(l1) == 16
    assert len(l2) <= 16


def test_truncate_lcd_newlines():
    from host.daemon_util import truncate_lcd
    l1, l2 = truncate_lcd("line1\nline2\nline3")
    assert "\n" not in l1
    assert "\n" not in l2


def test_find_port_returns_none_or_string():
    from host.daemon_util import find_port
    result = find_port()
    assert result is None or isinstance(result, str)


def test_write_status_creates_file():
    import host.daemon_util as mod
    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
        tmp = f.name
    orig = mod.STATUS_FILE
    mod.STATUS_FILE = tmp
    try:
        mod.write_status("testing", port="/dev/test", extra={"queries": 5})
        with open(tmp) as f:
            data = json.load(f)
        assert data["state"] == "testing"
        assert data["port"] == "/dev/test"
        assert data["queries"] == 5
    finally:
        mod.STATUS_FILE = orig
        os.unlink(tmp)


def test_signal_handler():
    import host.saviaclaw_daemon as mod
    mod._shutdown = False
    mod._handle_signal(15, None)
    assert mod._shutdown is True
    mod._shutdown = False


def test_file_sizes():
    base = os.path.join(os.path.dirname(__file__), '..', 'host')
    for name in ['saviaclaw_daemon.py', 'daemon_util.py']:
        path = os.path.join(base, name)
        with open(path) as f:
            lines = len(f.readlines())
        assert lines <= 150, f"{name} has {lines} lines (max 150)"


if __name__ == "__main__":
    print("SaviaClaw Daemon Tests (no hardware required)")
    print("-" * 45)
    test("Import daemon_util", test_import_util)
    test("Import daemon", test_import_daemon)
    test("Truncate LCD short", test_truncate_lcd_short)
    test("Truncate LCD two lines", test_truncate_lcd_two_lines)
    test("Truncate LCD newlines", test_truncate_lcd_newlines)
    test("find_port", test_find_port_returns_none_or_string)
    test("write_status", test_write_status_creates_file)
    test("Signal handler", test_signal_handler)
    test("File sizes <= 150", test_file_sizes)
    print(f"\n{passed} passed, {failed} failed")
    sys.exit(1 if failed else 0)
