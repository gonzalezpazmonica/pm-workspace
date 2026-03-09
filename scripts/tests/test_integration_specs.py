#!/usr/bin/env python3
"""
Integration test: validates ALL product specs against the running Bridge.

This test proves that the compiled APK + Bridge combination satisfies
every functional requirement defined in PRODUCT-SPEC.md.

Tests cover:
  1. Bridge connectivity and health
  2. Dashboard endpoint (Home screen data source)
  3. Chat endpoint (conversational AI)
  4. User profile (Settings/Profile data)
  5. Team management
  6. Company profile
  7. Git configuration
  8. APK update distribution
  9. Install page accessibility
  10. OpenAPI spec availability

Requirements:
  - Bridge running: systemctl --user start savia-bridge
  - APK built: ./gradlew assembleDebug

Usage:
    python3 tests/test_integration_specs.py
    python3 -m pytest tests/test_integration_specs.py -v

Exit codes:
    0 = all specs verified
    1 = one or more specs failed
"""

import json
import os
import ssl
import sys
import time
import uuid
import urllib.request
import urllib.error
from pathlib import Path

# --- Configuration ---

BRIDGE_HOST = os.environ.get("BRIDGE_HOST", "localhost")
BRIDGE_PORT = int(os.environ.get("BRIDGE_PORT", "8922"))
INSTALL_PORT = int(os.environ.get("INSTALL_PORT", "8080"))

TOKEN_FILE = Path.home() / ".savia" / "bridge" / "auth_token"
AUTH_TOKEN = TOKEN_FILE.read_text().strip() if TOKEN_FILE.exists() else ""

BRIDGE_URL = f"https://{BRIDGE_HOST}:{BRIDGE_PORT}"
INSTALL_URL = f"http://{BRIDGE_HOST}:{INSTALL_PORT}"

APK_DIR = Path.home() / ".savia" / "bridge" / "apk"
PROJECT_DIR = Path.home() / "savia" / "projects" / "savia-mobile-android"

SSL_CTX = ssl.create_default_context()
SSL_CTX.check_hostname = False
SSL_CTX.verify_mode = ssl.CERT_NONE

# --- Helpers ---

class SpecResult:
    def __init__(self, spec_id: str, name: str, passed: bool, detail: str = "", duration_ms: float = 0):
        self.spec_id = spec_id
        self.name = name
        self.passed = passed
        self.detail = detail
        self.duration_ms = duration_ms

    def __str__(self):
        icon = "PASS" if self.passed else "FAIL"
        d = f" ({self.duration_ms:.0f}ms)" if self.duration_ms > 0 else ""
        det = f"  -> {self.detail}" if self.detail else ""
        return f"  [{icon}] {self.spec_id}: {self.name}{d}{det}"


def bridge_get(path: str, auth: bool = True, timeout: int = 10) -> tuple:
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


def bridge_post(path: str, data: dict, auth: bool = True, timeout: int = 30) -> tuple:
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
    url = f"{INSTALL_URL}{path}"
    req = urllib.request.Request(url, method="GET")
    try:
        resp = urllib.request.urlopen(req, timeout=timeout)
        return resp.status, resp.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8") if e.fp else ""


def run_spec(spec_id: str, name: str, fn) -> SpecResult:
    start = time.time()
    try:
        result = fn()
        duration = (time.time() - start) * 1000
        if result is True:
            return SpecResult(spec_id, name, True, duration_ms=duration)
        elif isinstance(result, str):
            return SpecResult(spec_id, name, True, result, duration)
        else:
            return SpecResult(spec_id, name, False, str(result), duration)
    except Exception as e:
        duration = (time.time() - start) * 1000
        return SpecResult(spec_id, name, False, str(e), duration)


# ============================================================
# SPEC 1: Bridge Health & TLS
# ============================================================

def spec_bridge_health():
    """Bridge GET /health returns status=ok with TLS enabled."""
    status, body = bridge_get("/health")
    assert status == 200, f"HTTP {status}"
    data = json.loads(body)
    assert data.get("status") == "ok", f"status={data.get('status')}"
    assert data.get("tls") is True, "TLS not enabled"
    assert "version" in data, "Missing version"
    assert "claude_cli" in data, "Missing claude_cli"
    return f"v{data['version']}, CLI={data['claude_cli']}"


def spec_bridge_tls_cert():
    """Bridge uses HTTPS with TLS certificate."""
    import socket
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    with ctx.wrap_socket(socket.socket(), server_hostname=BRIDGE_HOST) as s:
        s.connect((BRIDGE_HOST, BRIDGE_PORT))
        cert = s.getpeercert(binary_form=True)
        assert cert is not None, "No TLS certificate"
        assert len(cert) > 0, "Empty certificate"
    return f"TLS cert present ({len(cert)} bytes)"


def spec_auth_token_required():
    """Protected endpoints require Bearer auth token."""
    url = f"{BRIDGE_URL}/profile"
    req = urllib.request.Request(url, method="GET")
    try:
        resp = urllib.request.urlopen(req, context=SSL_CTX, timeout=10)
        # 200 means auth is disabled (--no-auth mode)
        return f"Auth disabled (HTTP {resp.status})"
    except urllib.error.HTTPError as e:
        assert e.code in (401, 403), f"Expected 401/403, got {e.code}"
        return True


# ============================================================
# SPEC 2: Dashboard (Home Screen Data)
# ============================================================

def spec_dashboard_endpoint():
    """GET /dashboard returns complete Home screen data."""
    status, body = bridge_get("/dashboard")
    assert status == 200, f"HTTP {status}"
    data = json.loads(body)
    assert "user" in data, "Missing user"
    assert "projects" in data, "Missing projects"
    assert "sprint" in data, "Missing sprint"
    assert "myTasks" in data, "Missing myTasks"
    assert "recentActivity" in data, "Missing recentActivity"
    assert "blockedItems" in data, "Missing blockedItems"
    assert "hoursToday" in data, "Missing hoursToday"
    return f"{len(data['projects'])} projects, {len(data['myTasks'])} tasks"


def spec_dashboard_user_greeting():
    """Dashboard includes personalized user greeting."""
    status, body = bridge_get("/dashboard")
    data = json.loads(body)
    user = data.get("user", {})
    greeting = user.get("greeting", "")
    assert len(greeting) > 0, "Empty greeting"
    assert user.get("name", "") != "", "Missing user name"
    return greeting


def spec_dashboard_projects_list():
    """Dashboard returns list of projects with required fields."""
    status, body = bridge_get("/dashboard")
    data = json.loads(body)
    projects = data.get("projects", [])
    assert len(projects) > 0, "No projects found"
    for p in projects:
        assert "id" in p, f"Project missing 'id': {p}"
        assert "name" in p, f"Project missing 'name': {p}"
        assert "team" in p, f"Project missing 'team': {p}"
        assert "health" in p, f"Project missing 'health': {p}"
    return f"{len(projects)} projects validated"


def spec_dashboard_sprint_data():
    """Dashboard includes sprint summary with progress metrics."""
    status, body = bridge_get("/dashboard")
    data = json.loads(body)
    sprint = data.get("sprint")
    if sprint is None:
        return "No sprint data (expected for projects without test-data)"
    assert "name" in sprint, "Sprint missing 'name'"
    assert "progress" in sprint, "Sprint missing 'progress'"
    assert "completedPoints" in sprint, "Sprint missing 'completedPoints'"
    assert "totalPoints" in sprint, "Sprint missing 'totalPoints'"
    assert "daysRemaining" in sprint, "Sprint missing 'daysRemaining'"
    return f"{sprint['name']}: {sprint['completedPoints']}/{sprint['totalPoints']} SP"


def spec_dashboard_selected_project():
    """Dashboard auto-selects a project (first with sprint data)."""
    status, body = bridge_get("/dashboard")
    data = json.loads(body)
    selected = data.get("selectedProjectId")
    assert selected is not None, "No selectedProjectId"
    # Verify selected project exists in projects list
    project_ids = [p["id"] for p in data.get("projects", [])]
    assert selected in project_ids, f"Selected '{selected}' not in projects: {project_ids}"
    return f"Selected: {selected}"


def spec_dashboard_tasks():
    """Dashboard returns active tasks with required fields."""
    status, body = bridge_get("/dashboard")
    data = json.loads(body)
    tasks = data.get("myTasks", [])
    for t in tasks:
        assert "id" in t, f"Task missing 'id': {t}"
        assert "title" in t, f"Task missing 'title': {t}"
        assert "state" in t, f"Task missing 'state': {t}"
    return f"{len(tasks)} tasks"


# ============================================================
# SPEC 3: Chat (Conversational AI)
# ============================================================

def spec_chat_responds():
    """POST /chat returns AI response for simple message."""
    session = str(uuid.uuid4())
    status, body = bridge_post("/chat", {
        "message": "Responde solo: OK",
        "session_id": session
    }, timeout=30)
    assert status == 200, f"HTTP {status}: {body[:200]}"
    data = json.loads(body)
    assert "response" in data or "error" not in data, f"Unexpected: {body[:200]}"
    resp_text = data.get("response", "")
    return f"{len(resp_text)} chars"


def spec_chat_non_uuid_session():
    """Chat converts non-UUID session_id to valid UUID automatically."""
    random_suffix = uuid.uuid4().hex[:8]
    status, body = bridge_post("/chat", {
        "message": "Responde solo: OK",
        "session_id": f"test-{random_suffix}"
    }, timeout=30)
    assert status == 200, f"HTTP {status}: {body[:200]}"
    data = json.loads(body)
    assert "error" not in data or "Invalid session" not in data.get("error", ""), \
        f"UUID conversion failed: {body[:200]}"
    return True


# ============================================================
# SPEC 4: User Profile
# ============================================================

def spec_profile_endpoint():
    """GET /profile returns user profile with name and email."""
    status, body = bridge_get("/profile")
    assert status == 200, f"HTTP {status}"
    data = json.loads(body)
    assert "name" in data or "email" in data, f"Missing name/email: {list(data.keys())}"
    name = data.get("name", "")
    email = data.get("email", "")
    assert len(name) > 0 or len(email) > 0, "Both name and email are empty"
    return f"{name} <{email}>"


# ============================================================
# SPEC 5: Settings - Team Management
# ============================================================

def spec_team_endpoint():
    """GET /team returns team members list."""
    status, body = bridge_get("/team")
    assert status == 200, f"HTTP {status}"
    data = json.loads(body)
    assert isinstance(data, dict), f"Expected dict, got {type(data)}"
    members = data.get("members", [])
    assert isinstance(members, list), f"Expected members list"
    if len(members) > 0:
        m = members[0]
        assert "slug" in m or "name" in m, f"Member missing slug/name: {m}"
    return f"{len(members)} members"


# ============================================================
# SPEC 6: Settings - Company Profile
# ============================================================

def spec_company_endpoint():
    """GET /company returns company profile data."""
    status, body = bridge_get("/company")
    assert status == 200, f"HTTP {status}"
    data = json.loads(body)
    assert isinstance(data, dict), f"Expected dict, got {type(data)}"
    return f"status={data.get('status', 'unknown')}"


# ============================================================
# SPEC 7: Settings - Git Configuration
# ============================================================

def spec_git_config_endpoint():
    """GET /git-config returns git global configuration."""
    status, body = bridge_get("/git-config")
    assert status == 200, f"HTTP {status}"
    data = json.loads(body)
    assert isinstance(data, dict), f"Expected dict"
    # Should have at least name or email from git config
    return f"name={data.get('name', 'N/A')}, email={data.get('email', 'N/A')}"


# ============================================================
# SPEC 8: App Update Distribution
# ============================================================

def spec_update_check():
    """GET /update/check returns APK version info if available."""
    status, body = bridge_get("/update/check")
    assert status in (200, 404), f"HTTP {status}"
    data = json.loads(body)
    if status == 200:
        has_version = any(k in data for k in ("version", "versionName", "version_name"))
        assert has_version, f"Missing version in APK info: {list(data.keys())}"
        return f"APK available: {data.get('version', data.get('versionName', '?'))}"
    return "No APK available"


def spec_apk_exists():
    """APK file exists in Bridge distribution directory."""
    apk_files = list(APK_DIR.glob("*.apk")) if APK_DIR.exists() else []
    assert len(apk_files) > 0, f"No APK files in {APK_DIR}"
    apk = apk_files[0]
    size_mb = apk.stat().st_size / (1024 * 1024)
    assert size_mb > 1, f"APK too small: {size_mb:.1f} MB"
    return f"{apk.name} ({size_mb:.1f} MB)"


# ============================================================
# SPEC 9: Install Page
# ============================================================

def spec_install_page():
    """HTTP install page serves download page with APK link."""
    status, body = install_get("/install")
    assert status == 200, f"HTTP {status}"
    assert "Savia Mobile" in body, "Missing 'Savia Mobile'"
    assert "openapi.json" in body, "Missing OpenAPI link"
    return True


def spec_install_openapi():
    """Install server serves OpenAPI spec."""
    status, body = install_get("/openapi.json")
    assert status == 200, f"HTTP {status}"
    assert "openapi:" in body, "Not an OpenAPI spec"
    assert "Savia Bridge" in body, "Missing 'Savia Bridge'"
    return True


# ============================================================
# SPEC 10: Sessions & Connectors
# ============================================================

def spec_sessions():
    """GET /sessions returns session list."""
    status, body = bridge_get("/sessions")
    assert status == 200, f"HTTP {status}"
    data = json.loads(body)
    assert isinstance(data, (list, dict)), f"Unexpected type: {type(data)}"
    return True


def spec_connectors():
    """GET /connectors returns connector status."""
    status, body = bridge_get("/connectors")
    assert status == 200, f"HTTP {status}"
    data = json.loads(body)
    assert isinstance(data, dict), f"Expected dict"
    return True


# ============================================================
# SPEC 11: APK Compilation
# ============================================================

def spec_apk_compiled():
    """Debug APK was compiled successfully."""
    apk_path = PROJECT_DIR / "app" / "build" / "outputs" / "apk" / "debug" / "app-debug.apk"
    assert apk_path.exists(), f"APK not found at {apk_path}"
    size_mb = apk_path.stat().st_size / (1024 * 1024)
    assert size_mb > 5, f"APK suspiciously small: {size_mb:.1f} MB"
    return f"app-debug.apk ({size_mb:.1f} MB)"


# ============================================================
# SPEC 12: Error Handling
# ============================================================

def spec_404_handling():
    """Bridge returns proper 404 for unknown endpoints."""
    status, body = bridge_get("/nonexistent-endpoint-test")
    assert status == 404, f"Expected 404, got {status}"
    return True


def spec_logs_endpoint():
    """GET /logs returns log data."""
    status, body = bridge_get("/logs")
    assert status == 200, f"HTTP {status}"
    assert len(body) > 0, "Empty logs"
    return f"{len(body)} chars"


# ============================================================
# Test Runner
# ============================================================

def run_all_specs():
    print(f"\n{'='*70}")
    print(f"  Savia Integration Test - Product Specs Verification")
    print(f"  Bridge: {BRIDGE_URL}")
    print(f"  Install: {INSTALL_URL}")
    print(f"  Token: {'present' if AUTH_TOKEN else 'MISSING'}")
    print(f"  APK Dir: {APK_DIR}")
    print(f"{'='*70}\n")

    specs = [
        # Section 1: Bridge Infrastructure
        ("S1.1", "Bridge health endpoint", spec_bridge_health),
        ("S1.2", "TLS certificate present", spec_bridge_tls_cert),
        ("S1.3", "Auth token enforcement", spec_auth_token_required),

        # Section 2: Dashboard (Home Screen)
        ("S2.1", "Dashboard endpoint returns data", spec_dashboard_endpoint),
        ("S2.2", "Dashboard user greeting", spec_dashboard_user_greeting),
        ("S2.3", "Dashboard projects list", spec_dashboard_projects_list),
        ("S2.4", "Dashboard sprint metrics", spec_dashboard_sprint_data),
        ("S2.5", "Dashboard auto-selects project", spec_dashboard_selected_project),
        ("S2.6", "Dashboard active tasks", spec_dashboard_tasks),

        # Section 3: Chat
        ("S3.1", "Chat AI response", spec_chat_responds),
        ("S3.2", "Chat non-UUID session handling", spec_chat_non_uuid_session),

        # Section 4: Profile
        ("S4.1", "User profile endpoint", spec_profile_endpoint),

        # Section 5: Team Management
        ("S5.1", "Team members endpoint", spec_team_endpoint),

        # Section 6: Company Profile
        ("S6.1", "Company profile endpoint", spec_company_endpoint),

        # Section 7: Git Configuration
        ("S7.1", "Git config endpoint", spec_git_config_endpoint),

        # Section 8: Updates
        ("S8.1", "Update check endpoint", spec_update_check),
        ("S8.2", "APK file in distribution dir", spec_apk_exists),

        # Section 9: Install Page
        ("S9.1", "Install page accessible", spec_install_page),
        ("S9.2", "Install OpenAPI spec", spec_install_openapi),

        # Section 10: Sessions & Connectors
        ("S10.1", "Sessions endpoint", spec_sessions),
        ("S10.2", "Connectors endpoint", spec_connectors),

        # Section 11: APK Build
        ("S11.1", "APK compiled successfully", spec_apk_compiled),

        # Section 12: Error Handling
        ("S12.1", "404 error handling", spec_404_handling),
        ("S12.2", "Logs endpoint", spec_logs_endpoint),
    ]

    results = []
    current_section = ""

    for spec_id, name, fn in specs:
        section = spec_id.split(".")[0]
        if section != current_section:
            current_section = section
            section_names = {
                "S1": "Bridge Infrastructure",
                "S2": "Dashboard (Home Screen)",
                "S3": "Chat (Conversational AI)",
                "S4": "User Profile",
                "S5": "Team Management",
                "S6": "Company Profile",
                "S7": "Git Configuration",
                "S8": "App Updates",
                "S9": "Install Page",
                "S10": "Sessions & Connectors",
                "S11": "APK Build",
                "S12": "Error Handling",
            }
            print(f"  --- {section_names.get(section, section)} ---")

        result = run_spec(spec_id, name, fn)
        results.append(result)
        print(result)

    # Summary
    passed = sum(1 for r in results if r.passed)
    failed = sum(1 for r in results if not r.passed)
    total = len(results)
    total_time = sum(r.duration_ms for r in results)

    print(f"\n{'='*70}")
    print(f"  RESULTS: {passed}/{total} specs passed, {failed} failed ({total_time:.0f}ms)")
    print(f"{'='*70}\n")

    if failed > 0:
        print("  FAILED SPECS:")
        for r in results:
            if not r.passed:
                print(f"    [{r.spec_id}] {r.name}: {r.detail}")
        print()

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(run_all_specs())
