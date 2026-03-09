#!/usr/bin/env python3
"""
Integration tests for Savia Bridge endpoints.

Tests all Bridge HTTP/HTTPS endpoints against the running service.
Requires Bridge to be running (systemctl --user start savia-bridge).

Usage:
    python3 tests/test_bridge_endpoints.py
    python3 -m pytest tests/test_bridge_endpoints.py -v

Exit codes:
    0 = all tests passed
    1 = one or more tests failed
"""

import json
import os
import ssl
import sys
import time
import urllib.request
import urllib.error
from pathlib import Path

# ─── Configuration ──────────────────────────────────────────────────────────

BRIDGE_HOST = os.environ.get("BRIDGE_HOST", "localhost")
BRIDGE_PORT = int(os.environ.get("BRIDGE_PORT", "8922"))
INSTALL_PORT = int(os.environ.get("INSTALL_PORT", "8080"))

TOKEN_FILE = Path.home() / ".savia" / "bridge" / "auth_token"
AUTH_TOKEN = TOKEN_FILE.read_text().strip() if TOKEN_FILE.exists() else ""

BRIDGE_URL = f"https://{BRIDGE_HOST}:{BRIDGE_PORT}"
INSTALL_URL = f"http://{BRIDGE_HOST}:{INSTALL_PORT}"

# Trust self-signed certs
SSL_CTX = ssl.create_default_context()
SSL_CTX.check_hostname = False
SSL_CTX.verify_mode = ssl.CERT_NONE

# ─── Helpers ────────────────────────────────────────────────────────────────

class TestResult:
    def __init__(self, name: str, passed: bool, message: str = "", duration_ms: float = 0):
        self.name = name
        self.passed = passed
        self.message = message
        self.duration_ms = duration_ms

    def __str__(self):
        status = "✅ PASS" if self.passed else "❌ FAIL"
        duration = f" ({self.duration_ms:.0f}ms)" if self.duration_ms > 0 else ""
        msg = f"  → {self.message}" if self.message else ""
        return f"  {status} {self.name}{duration}{msg}"


def bridge_get(path: str, auth: bool = True, timeout: int = 10) -> tuple:
    """GET request to Bridge HTTPS server. Returns (status_code, body_str)."""
    url = f"{BRIDGE_URL}{path}"
    headers = {}
    if auth and AUTH_TOKEN:
        headers["Authorization"] = f"Bearer {AUTH_TOKEN}"
    req = urllib.request.Request(url, headers=headers, method="GET")
    try:
        resp = urllib.request.urlopen(req, context=SSL_CTX, timeout=timeout)
        return resp.status, resp.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8") if e.fp else ""


def bridge_post(path: str, data: dict, auth: bool = True, timeout: int = 15) -> tuple:
    """POST request to Bridge HTTPS server. Returns (status_code, body_str)."""
    url = f"{BRIDGE_URL}{path}"
    headers = {"Content-Type": "application/json"}
    if auth and AUTH_TOKEN:
        headers["Authorization"] = f"Bearer {AUTH_TOKEN}"
    body = json.dumps(data).encode("utf-8")
    req = urllib.request.Request(url, data=body, headers=headers, method="POST")
    try:
        resp = urllib.request.urlopen(req, context=SSL_CTX, timeout=timeout)
        return resp.status, resp.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8") if e.fp else ""


def install_get(path: str, timeout: int = 10) -> tuple:
    """GET request to Install HTTP server. Returns (status_code, body_str)."""
    url = f"{INSTALL_URL}{path}"
    req = urllib.request.Request(url, method="GET")
    try:
        resp = urllib.request.urlopen(req, timeout=timeout)
        return resp.status, resp.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8") if e.fp else ""


def timed_test(name: str, test_fn) -> TestResult:
    """Run a test function and return a TestResult."""
    start = time.time()
    try:
        result = test_fn()
        duration = (time.time() - start) * 1000
        if result is True:
            return TestResult(name, True, duration_ms=duration)
        elif isinstance(result, str):
            return TestResult(name, True, result, duration)
        else:
            return TestResult(name, False, str(result), duration)
    except Exception as e:
        duration = (time.time() - start) * 1000
        return TestResult(name, False, str(e), duration)


# ─── Bridge HTTPS Endpoint Tests ───────────────────────────────────────────

def test_health():
    """GET /health — returns JSON with status=ok, version, tls flag."""
    status, body = bridge_get("/health")
    assert status == 200, f"Expected 200, got {status}"
    data = json.loads(body)
    assert data.get("status") == "ok", f"Expected status=ok, got {data.get('status')}"
    assert "version" in data, "Missing 'version' field"
    assert data.get("tls") is True, "Expected tls=true"
    assert "claude_cli" in data, "Missing 'claude_cli' field"
    assert "timestamp" in data, "Missing 'timestamp' field"
    return f"v{data['version']}"


def test_health_no_auth():
    """GET /health without auth token — should still return 200 (no auth required)."""
    url = f"{BRIDGE_URL}/health"
    req = urllib.request.Request(url, method="GET")
    resp = urllib.request.urlopen(req, context=SSL_CTX, timeout=10)
    assert resp.status == 200, f"Expected 200, got {resp.status}"
    return True


def test_profile():
    """GET /profile — returns user profile JSON."""
    status, body = bridge_get("/profile")
    assert status == 200, f"Expected 200, got {status}"
    data = json.loads(body)
    assert "name" in data or "email" in data, f"Profile should have name or email, got: {list(data.keys())}"
    return data.get("name", "no-name")


def test_sessions():
    """GET /sessions — returns list of sessions."""
    status, body = bridge_get("/sessions")
    assert status == 200, f"Expected 200, got {status}"
    data = json.loads(body)
    assert isinstance(data, (list, dict)), f"Expected list or dict, got {type(data)}"
    return True


def test_team():
    """GET /team — returns team data."""
    status, body = bridge_get("/team")
    assert status == 200, f"Expected 200, got {status}"
    data = json.loads(body)
    assert isinstance(data, (list, dict)), f"Expected list or dict, got {type(data)}"
    return True


def test_company():
    """GET /company — returns company data."""
    status, body = bridge_get("/company")
    assert status == 200, f"Expected 200, got {status}"
    data = json.loads(body)
    assert isinstance(data, (list, dict)), f"Expected list or dict, got {type(data)}"
    return True


def test_git_config():
    """GET /git-config — returns git configuration."""
    status, body = bridge_get("/git-config")
    assert status == 200, f"Expected 200, got {status}"
    data = json.loads(body)
    assert isinstance(data, dict), f"Expected dict, got {type(data)}"
    return True


def test_connectors():
    """GET /connectors — returns connectors status."""
    status, body = bridge_get("/connectors")
    assert status == 200, f"Expected 200, got {status}"
    data = json.loads(body)
    assert isinstance(data, dict), f"Expected dict, got {type(data)}"
    return True


def test_openapi_bridge():
    """GET /openapi.json on Bridge HTTPS — returns YAML spec."""
    status, body = bridge_get("/openapi.json")
    assert status == 200, f"Expected 200, got {status}"
    assert "openapi:" in body or "openapi :" in body, "Response doesn't look like OpenAPI spec"
    assert "Savia Bridge" in body, "Missing 'Savia Bridge' in spec"
    return True


def test_logs():
    """GET /logs — returns log entries."""
    status, body = bridge_get("/logs")
    assert status == 200, f"Expected 200, got {status}"
    # Logs could be plain text or JSON
    assert len(body) > 0, "Empty logs response"
    return f"{len(body)} chars"


def test_update_check():
    """GET /update/check — returns APK info if available."""
    status, body = bridge_get("/update/check")
    # 200 if APK exists, 404 if not
    assert status in (200, 404), f"Expected 200 or 404, got {status}"
    data = json.loads(body)
    if status == 200:
        assert "version" in data or "versionName" in data or "version_name" in data, f"Missing version in APK info: {list(data.keys())}"
        return f"APK found"
    return "No APK"


def test_chat_json():
    """POST /chat (JSON response) — sends message, gets response."""
    status, body = bridge_post("/chat", {
        "message": "Responde solo: OK",
        "session_id": "00000000-0000-4000-a000-000000test01"
    })
    assert status == 200, f"Expected 200, got {status}: {body[:200]}"
    data = json.loads(body)
    assert "response" in data or "error" not in data, f"Unexpected response: {body[:200]}"
    response_text = data.get("response", "")
    return f"{len(response_text)} chars"


def test_chat_non_uuid_session():
    """POST /chat with non-UUID session_id — Bridge should convert to UUID."""
    status, body = bridge_post("/chat", {
        "message": "Responde solo: OK",
        "session_id": "test-non-uuid"
    })
    assert status == 200, f"Expected 200, got {status}: {body[:200]}"
    data = json.loads(body)
    # Should get a valid response, not "Invalid session ID"
    assert "error" not in data or "Invalid session" not in data.get("error", ""), \
        f"Bridge failed to convert non-UUID session: {body[:200]}"
    return True


def test_auth_required():
    """GET /profile without auth — should return 401."""
    url = f"{BRIDGE_URL}/profile"
    req = urllib.request.Request(url, method="GET")
    try:
        resp = urllib.request.urlopen(req, context=SSL_CTX, timeout=10)
        # If auth is disabled (--no-auth), 200 is ok
        return f"Auth disabled (got {resp.status})"
    except urllib.error.HTTPError as e:
        assert e.code == 401 or e.code == 403, f"Expected 401/403, got {e.code}"
        return True


def test_not_found():
    """GET /nonexistent — should return 404."""
    status, body = bridge_get("/nonexistent-endpoint-xyz")
    assert status == 404, f"Expected 404, got {status}"
    return True


# ─── Install HTTP Server Tests ──────────────────────────────────────────────

def test_install_page():
    """GET /install on HTTP server — returns HTML install page."""
    status, body = install_get("/install")
    assert status == 200, f"Expected 200, got {status}"
    assert "Savia Mobile" in body, "Missing 'Savia Mobile' in install page"
    assert "openapi.json" in body, "Missing OpenAPI link in install page"
    return True


def test_install_root():
    """GET / on HTTP server — same as /install."""
    status, body = install_get("/")
    assert status == 200, f"Expected 200, got {status}"
    assert "Savia Mobile" in body, "Install page should contain 'Savia Mobile'"
    return True


def test_install_update_check():
    """GET /update/check on HTTP server — returns APK info."""
    status, body = install_get("/update/check")
    assert status in (200, 404), f"Expected 200 or 404, got {status}"
    data = json.loads(body)
    assert isinstance(data, dict), f"Expected dict, got {type(data)}"
    return "APK found" if status == 200 else "No APK"


def test_install_openapi():
    """GET /openapi.json on HTTP server — returns YAML spec."""
    status, body = install_get("/openapi.json")
    assert status == 200, f"Expected 200, got {status}"
    assert "openapi:" in body, "Response doesn't look like OpenAPI spec"
    return True


# ─── Test Runner ────────────────────────────────────────────────────────────

def run_all_tests():
    """Run all Bridge endpoint tests and report results."""
    print(f"\n{'='*60}")
    print(f"  Savia Bridge Endpoint Tests")
    print(f"  Bridge: {BRIDGE_URL}")
    print(f"  Install: {INSTALL_URL}")
    print(f"  Token: {'present' if AUTH_TOKEN else 'MISSING'}")
    print(f"{'='*60}\n")

    # Group tests
    bridge_tests = [
        ("health", test_health),
        ("health_no_auth", test_health_no_auth),
        ("auth_required", test_auth_required),
        ("profile", test_profile),
        ("sessions", test_sessions),
        ("team", test_team),
        ("company", test_company),
        ("git_config", test_git_config),
        ("connectors", test_connectors),
        ("openapi_bridge", test_openapi_bridge),
        ("logs", test_logs),
        ("update_check", test_update_check),
        ("not_found", test_not_found),
    ]

    chat_tests = [
        ("chat_json", test_chat_json),
        ("chat_non_uuid_session", test_chat_non_uuid_session),
    ]

    install_tests = [
        ("install_page", test_install_page),
        ("install_root", test_install_root),
        ("install_update_check", test_install_update_check),
        ("install_openapi", test_install_openapi),
    ]

    all_results = []

    print("  Bridge HTTPS Endpoints:")
    for name, fn in bridge_tests:
        result = timed_test(name, fn)
        all_results.append(result)
        print(result)

    print("\n  Chat Endpoint (requires Claude CLI):")
    for name, fn in chat_tests:
        result = timed_test(name, fn)
        all_results.append(result)
        print(result)

    print("\n  Install HTTP Server:")
    for name, fn in install_tests:
        result = timed_test(name, fn)
        all_results.append(result)
        print(result)

    # Summary
    passed = sum(1 for r in all_results if r.passed)
    failed = sum(1 for r in all_results if not r.passed)
    total = len(all_results)
    total_time = sum(r.duration_ms for r in all_results)

    print(f"\n{'='*60}")
    print(f"  Results: {passed}/{total} passed, {failed} failed ({total_time:.0f}ms)")
    print(f"{'='*60}\n")

    if failed > 0:
        print("  Failed tests:")
        for r in all_results:
            if not r.passed:
                print(f"    ❌ {r.name}: {r.message}")
        print()

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(run_all_tests())
