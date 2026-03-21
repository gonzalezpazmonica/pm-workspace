#!/usr/bin/env python3
"""ZeroClaw CLI — self-test, interactive mode, and entry point.

Usage:
  python3 zeroclaw/host/cli.py                    # auto-detect + test + interactive
  python3 zeroclaw/host/cli.py --port /dev/ttyUSB0
  python3 zeroclaw/host/cli.py --test
"""
import json
import sys
import argparse
from .bridge import ZeroClawBridge


def self_test(bridge):
    """Run self-test sequence on connected ZeroClaw."""
    tests = [
        ("Ping", lambda: bridge.ping()),
        ("Info", lambda: bridge.info()),
        ("LED blink", lambda: bridge.led("blink", 3)),
        ("Sensors", lambda: bridge.sensors()),
        ("GPIO2 read", lambda: bridge.gpio(2, "read")),
    ]
    passed = 0
    for name, fn in tests:
        result = fn()
        ok = "ok" in result or "data" in result
        icon = "✅" if ok else "❌"
        print(f"  {icon} {name}: {json.dumps(result)[:80]}")
        if ok:
            passed += 1
    print(f"\n  {passed}/{len(tests)} tests passed")
    return passed == len(tests)


def interactive(bridge):
    """Interactive command loop."""
    print("\n🦎 ZeroClaw Interactive — type commands (help, q to quit)")
    while True:
        try:
            cmd = input("zeroclaw> ").strip()
        except (EOFError, KeyboardInterrupt):
            break
        if cmd in ('q', 'quit', 'exit'):
            break
        if not cmd:
            continue
        result = bridge.send_text(cmd)
        print(json.dumps(result, indent=2))


def main():
    parser = argparse.ArgumentParser(description="ZeroClaw Host CLI")
    parser.add_argument("--port", help="Serial port (auto-detect)")
    parser.add_argument("--test", action="store_true", help="Self-test only")
    parser.add_argument("--interactive", "-i", action="store_true")
    args = parser.parse_args()

    bridge = ZeroClawBridge(port=args.port)
    if not bridge.connect():
        sys.exit(1)

    try:
        if args.test:
            sys.exit(0 if self_test(bridge) else 1)
        elif args.interactive:
            interactive(bridge)
        else:
            self_test(bridge)
            interactive(bridge)
    finally:
        bridge.close()


if __name__ == "__main__":
    main()
