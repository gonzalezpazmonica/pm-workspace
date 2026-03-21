"""ZeroClaw connectivity test — verify host↔ESP32 network path.

Tests: serial, WiFi, HTTP, and round-trip latency.
"""
import subprocess
import platform
import time
import json


def test_serial(port=None):
    """Test serial USB connection to ESP32."""
    cmd = ["python3", "-m", "mpremote"]
    if port:
        cmd += ["connect", port]
    cmd += ["exec", "print('serial_ok')"]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        return "serial_ok" in r.stdout
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def test_ping(ip, count=3):
    """Ping ESP32 IP from host. Cross-platform."""
    flag = "-n" if platform.system() == "Windows" else "-c"
    try:
        r = subprocess.run(
            ["ping", flag, str(count), ip],
            capture_output=True, text=True, timeout=15)
        return r.returncode == 0, r.stdout
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False, "ping timeout"


def test_http(ip, port=8765):
    """Test HTTP connectivity (future: when ESP32 runs HTTP server)."""
    import urllib.request
    try:
        url = f"http://{ip}:{port}/ping"
        with urllib.request.urlopen(url, timeout=5) as resp:
            return resp.status == 200
    except Exception:
        return False


def run_all(esp32_ip=None, serial_port=None):
    """Run all connectivity tests. Returns results dict."""
    results = {}

    # Serial
    results["serial"] = test_serial(serial_port)

    # WiFi (if we know the IP)
    if esp32_ip:
        ok, output = test_ping(esp32_ip)
        results["ping"] = ok
        results["ping_output"] = output[:200] if output else ""
        results["http"] = test_http(esp32_ip)
    else:
        results["ping"] = None
        results["http"] = None
        results["note"] = "No ESP32 IP known. Run network setup first."

    return results


def print_results(results):
    """Pretty-print connectivity test results."""
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("  🔌 ZeroClaw Connectivity Test")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    tests = [
        ("USB Serial", results.get("serial")),
        ("WiFi Ping", results.get("ping")),
        ("HTTP", results.get("http")),
    ]
    for name, ok in tests:
        if ok is None:
            icon = "⏭️"
            status = "skipped"
        elif ok:
            icon = "✅"
            status = "pass"
        else:
            icon = "❌"
            status = "FAIL"
        print(f"  {icon} {name}: {status}")
    if results.get("note"):
        print(f"  ℹ️  {results['note']}")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
