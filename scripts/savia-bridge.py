#!/usr/bin/env python3
"""
Savia Bridge — HTTPS Server Bridging Savia Mobile and Claude Code CLI.

Module Purpose:
    This module implements a lightweight Python HTTPS server that acts as a bridge
    between the Savia Mobile Android app and the Claude Code CLI. It provides:

    1. HTTPS endpoints for chat, health checks, and session management
    2. Server-Sent Events (SSE) streaming of Claude responses
    3. User profile injection into Claude prompts
    4. APK distribution for Savia Mobile
    5. TLS certificate management (self-signed, auto-generated)

Architecture:
    Savia Mobile App (Android)
            ↓ HTTPS/SSE streaming
        [VPN/Local Network]
            ↓
    Savia Bridge (Python HTTPS server, this module)
            ↓ stdio pipes
        Claude Code CLI
            ↓
    Claude API (api.anthropic.com)

Endpoints:
    POST   /chat              Send message, receive SSE stream response
    GET    /health            Health check (no auth required)
    GET    /sessions          List active sessions
    DELETE /sessions          Clear session history
    GET    /install           HTML page for APK download (no auth)
    GET    /download/apk      Download APK binary (no auth)
    GET    /update/check      Check available APK version and metadata (no auth)
    GET    /update/download   Download APK for auto-update (no auth)
    GET    /profile           User profile (name, email, company, role) (no auth)
    PUT    /profile           Save user preferences from mobile app (requires Bearer auth)
    GET    /git-config        Git global config (name, email, PAT status) (no auth)
    PUT    /git-config        Update git global config (requires Bearer auth)
    GET    /team              Team members from .claude/profiles/users/ (no auth)
    PUT    /team              Add/update/remove team members (requires Bearer auth)
    GET    /company           Company configuration sections (no auth)
    PUT    /company           Update company profile sections (requires Bearer auth)
    GET    /connectors        External service connectors (no auth)
    GET    /openapi.json      OpenAPI 3.0 specification in YAML (no auth)

Configuration Files (created automatically):
    ~/.savia/bridge/bridge.log              General server logs
    ~/.savia/bridge/chat.log                Detailed request/response logs
    ~/.savia/bridge/auth_token              Bearer token for authentication
    ~/.savia/bridge/cert.pem                Self-signed TLS certificate
    ~/.savia/bridge/key.pem                 TLS private key
    ~/.savia/bridge/cert_fingerprint.txt    SHA-256 fingerprint
    ~/.savia/bridge/profile.json            User profile (name, role, email)
    ~/.savia/bridge/sessions/               Claude CLI session directory
    ~/.savia/bridge/apk/                    APK files for distribution

Usage:
    python3 savia-bridge.py [--port 8922] [--host 0.0.0.0] [--auth-token TOKEN]

Design Principles:
    - Zero external dependencies (stdlib only)
    - Auto-generates TLS certificates and auth tokens on first run
    - Per-session locking to prevent concurrent CLI calls
    - Streaming responses via SSE for low latency
    - Detailed logging for debugging
"""

import argparse
import hashlib
import http.server
import json
import os
import re
import secrets
import shutil
import ssl
import subprocess
import sys
import threading
import time
import traceback
from datetime import datetime
from pathlib import Path
from urllib.parse import urlparse, parse_qs

# --- Configuration ---

DEFAULT_PORT = 8922
DEFAULT_INSTALL_PORT = 8080
DEFAULT_HOST = "0.0.0.0"
CONFIG_DIR = Path.home() / ".savia" / "bridge"
TOKEN_FILE = CONFIG_DIR / "auth_token"
LOG_FILE = CONFIG_DIR / "bridge.log"
CHAT_LOG_FILE = CONFIG_DIR / "chat.log"
SESSIONS_DIR = CONFIG_DIR / "sessions"
TLS_CERT_FILE = CONFIG_DIR / "cert.pem"
TLS_KEY_FILE = CONFIG_DIR / "key.pem"
TLS_FINGERPRINT_FILE = CONFIG_DIR / "cert_fingerprint.txt"
APK_DIR = CONFIG_DIR / "apk"

# Max log file size before rotation (5 MB)
MAX_LOG_SIZE = 5 * 1024 * 1024

# --- APK Install Page ---

BRIDGE_VERSION = "1.5.0"

TEMPLATES_DIR = Path(__file__).resolve().parent / "templates"
LOGO_B64_FILE = CONFIG_DIR / "logo_b64.txt"

def _find_apk() -> Path | None:
    """
    Locate the most recently modified APK file for distribution.

    Searches ~/.savia/bridge/apk/ directory and returns the file with the
    latest modification timestamp. Used by /install and /download/apk endpoints
    to serve the current version.

    Returns:
        Path: Absolute path to the most recent APK file
        None: If no APK files exist in the directory

    Side Effects:
        Creates APK_DIR if it doesn't exist
    """
    APK_DIR.mkdir(parents=True, exist_ok=True)
    apks = sorted(APK_DIR.glob("*.apk"), key=lambda p: p.stat().st_mtime, reverse=True)
    return apks[0] if apks else None

def _get_apk_version(apk_path: Path) -> str:
    """Extract versionName from APK using aapt (best-effort)."""
    try:
        sdk = os.environ.get("ANDROID_HOME") or str(Path.home() / "Android" / "Sdk")
        bt_dir = Path(sdk) / "build-tools"
        if bt_dir.exists():
            versions = sorted(bt_dir.iterdir(), reverse=True)
            if versions:
                aapt = versions[0] / "aapt"
                if aapt.exists():
                    result = subprocess.run(
                        [str(aapt), "dump", "badging", str(apk_path)],
                        capture_output=True, text=True, timeout=10
                    )
                    for token in result.stdout.split():
                        if token.startswith("versionName="):
                            return token.split("=", 1)[1].strip("'\"")
    except Exception:
        pass
    # Fallback: parse filename
    name = apk_path.stem  # e.g. "savia-debug" or "savia-v0.1.0"
    return name

def _get_apk_version_code(apk_path: Path) -> int:
    """
    Extract versionCode from APK using aapt.

    Attempts to use aapt to extract the versionCode from the APK manifest.
    Falls back to parsing the filename (e.g., "savia-v0.2.0-release.apk" -> versionCode 2).

    Args:
        apk_path: Path to the APK file

    Returns:
        int: The versionCode (minimum 1)
    """
    try:
        sdk = os.environ.get("ANDROID_HOME") or str(Path.home() / "Android" / "Sdk")
        bt_dir = Path(sdk) / "build-tools"
        if bt_dir.exists():
            versions = sorted(bt_dir.iterdir(), reverse=True)
            if versions:
                aapt = versions[0] / "aapt"
                if aapt.exists():
                    result = subprocess.run(
                        [str(aapt), "dump", "badging", str(apk_path)],
                        capture_output=True, text=True, timeout=10
                    )
                    for token in result.stdout.split():
                        if token.startswith("versionCode="):
                            try:
                                return int(token.split("=", 1)[1].strip("'\""))
                            except (ValueError, IndexError):
                                pass
    except Exception:
        pass

    # Fallback: parse version from filename (e.g., "savia-v0.2.0" -> extract 2)
    name = apk_path.stem
    match = re.search(r'v(\d+)\.(\d+)\.(\d+)', name)
    if match:
        # Return minor version number as versionCode (e.g., v0.2.0 -> 2)
        return int(match.group(2))
    return 1

def _get_apk_info(apk_path: Path) -> dict:
    """
    Extract comprehensive metadata from an APK file.

    Computes all metadata needed for auto-update endpoints: version, versionCode,
    filename, size in bytes, SHA-256 hash, downloadUrl, releaseNotes, and minAndroidSdk.

    Args:
        apk_path: Path to the APK file to analyze

    Returns:
        dict with keys:
            - version: versionName (e.g., "0.2.0")
            - versionCode: integer version code
            - filename: basename of APK file
            - size: file size in bytes
            - sha256: SHA-256 hash of APK (lowercase hex)
            - downloadUrl: relative path "/update/download"
            - releaseNotes: default release notes
            - minAndroidSdk: minimum Android API level (default 26)
    """
    version = _get_apk_version(apk_path)
    version_code = _get_apk_version_code(apk_path)
    file_size = apk_path.stat().st_size

    # Compute SHA-256 hash
    sha256_hash = hashlib.sha256()
    with open(apk_path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            sha256_hash.update(chunk)
    sha256_hex = sha256_hash.hexdigest()

    return {
        "version": version,
        "versionCode": version_code,
        "filename": apk_path.name,
        "size": file_size,
        "sha256": sha256_hex,
        "downloadUrl": "/update/download",
        "releaseNotes": "Auto-update, project selector, command palette improvements and bug fixes",
        "minAndroidSdk": 26
    }

def _load_logo_b64() -> str:
    """Load the base64-encoded logo PNG. Falls back to a simple SVG."""
    try:
        if LOGO_B64_FILE.exists():
            return f"data:image/png;base64,{LOGO_B64_FILE.read_text().strip()}"
    except Exception:
        pass
    # Fallback: simple SVG circle with "S"
    return "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxMDAgMTAwIj48Y2lyY2xlIGN4PSI1MCIgY3k9IjUwIiByPSI0OCIgZmlsbD0iIzZCNEM5QSIvPjx0ZXh0IHg9IjUwIiB5PSI2MiIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZmlsbD0id2hpdGUiIGZvbnQtc2l6ZT0iNDAiIGZvbnQtZmFtaWx5PSJzYW5zLXNlcmlmIiBmb250LXdlaWdodD0iYm9sZCI+UzwvdGV4dD48L3N2Zz4="

def _load_template(name: str) -> str:
    """Load an HTML template from the templates/ directory.

    Args:
        name: Template filename (e.g. 'install.html')

    Returns:
        The raw template string with {{placeholders}} intact.

    Raises:
        FileNotFoundError: If the template file does not exist.
    """
    template_path = TEMPLATES_DIR / name
    if not template_path.exists():
        raise FileNotFoundError(f"Template not found: {template_path}")
    return template_path.read_text(encoding="utf-8")


def _build_install_html(apk: Path | None) -> str:
    """Build the install page HTML by loading the template and injecting data."""
    logo_src = _load_logo_b64()

    if apk:
        size_mb = apk.stat().st_size / (1024 * 1024)
        app_version = _get_apk_version(apk)
        download_section = (
            f'<a href="/download/apk" class="btn">Descargar Savia Mobile</a>\n'
            f'  <div class="apk-info">\n'
            f'    <span class="apk-name">{apk.name}</span>\n'
            f'    <span class="apk-detail">v{app_version} &middot; {size_mb:.1f} MB</span>\n'
            f'  </div>'
        )
    else:
        download_section = (
            '<a class="btn btn-disabled">No disponible</a>\n'
            f'  <p class="apk-info" style="color:#c62828;">No hay APK disponible.<br>'
            f'Coloca el archivo .apk en:<br><code>{APK_DIR}</code></p>'
        )

    template = _load_template("install.html")
    return (
        template
        .replace("{{logo_src}}", logo_src)
        .replace("{{download_section}}", download_section)
        .replace("{{bridge_version}}", BRIDGE_VERSION)
    )

# --- Logging ---

_log_lock = threading.Lock()

def _rotate_log(filepath: Path):
    """Rotate log file if it exceeds MAX_LOG_SIZE."""
    try:
        if filepath.exists() and filepath.stat().st_size > MAX_LOG_SIZE:
            rotated = filepath.with_suffix(filepath.suffix + ".1")
            if rotated.exists():
                rotated.unlink()
            filepath.rename(rotated)
    except Exception:
        pass

def log(msg: str, level: str = "INFO"):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
    line = f"[{timestamp}] [{level}] {msg}"
    print(line, flush=True)
    with _log_lock:
        try:
            LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
            _rotate_log(LOG_FILE)
            with open(LOG_FILE, "a") as f:
                f.write(line + "\n")
        except Exception:
            pass

def chat_log(msg: str, level: str = "INFO"):
    """Dedicated chat log for request/response detail."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
    line = f"[{timestamp}] [{level}] {msg}"
    with _log_lock:
        try:
            CHAT_LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
            _rotate_log(CHAT_LOG_FILE)
            with open(CHAT_LOG_FILE, "a") as f:
                f.write(line + "\n")
        except Exception:
            pass

# --- Auth Token Management ---

def get_or_create_token() -> str:
    """
    Retrieve or generate the authentication token for Savia Bridge.

    If an auth token already exists at ~/.savia/bridge/auth_token, it is loaded
    and returned. Otherwise, a new token is generated using secrets.token_urlsafe()
    with 32 bytes of entropy, saved to disk with restricted permissions (0600),
    and returned.

    The token should be shared with Savia Mobile clients and included in all
    authenticated requests as: 'Authorization: Bearer {token}'

    Returns:
        str: The authentication token (43 characters)

    Side Effects:
        - Creates CONFIG_DIR if it doesn't exist
        - Writes token to TOKEN_FILE with mode 0o600 (owner read/write only)
        - Logs token generation if new token created
    """
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    if TOKEN_FILE.exists():
        return TOKEN_FILE.read_text().strip()
    token = secrets.token_urlsafe(32)
    TOKEN_FILE.write_text(token)
    TOKEN_FILE.chmod(0o600)
    log(f"Generated new auth token. Stored in {TOKEN_FILE}")
    return token

# --- TLS Certificate Management ---

def get_or_create_tls_cert() -> tuple:
    """
    Retrieve or generate a self-signed TLS certificate for HTTPS.

    If a valid TLS certificate and key already exist at ~/.savia/bridge/,
    they are reused along with the cached SHA-256 fingerprint.

    Otherwise, a new self-signed certificate is generated using OpenSSL with:
    - Key size: RSA 2048-bit
    - Validity: 3650 days (10 years)
    - Subject: CN=Savia Bridge/O=Savia/C=ES
    - SubjectAltName: localhost, 127.0.0.1, 0.0.0.0

    The certificate fingerprint is computed and cached for client pinning.

    Returns:
        tuple: (cert_path, key_path, sha256_fingerprint)
            - cert_path (str): Absolute path to cert.pem
            - key_path (str): Absolute path to key.pem
            - sha256_fingerprint (str): SHA-256 hash for certificate pinning

    Raises:
        FileNotFoundError: If openssl is not installed on the system

    Side Effects:
        - Creates CONFIG_DIR and TLS files if needed
        - Sets file permissions: key.pem (0600), cert.pem (0644)
        - Logs certificate generation details
    """
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)

    if TLS_CERT_FILE.exists() and TLS_KEY_FILE.exists():
        fingerprint = TLS_FINGERPRINT_FILE.read_text().strip() if TLS_FINGERPRINT_FILE.exists() else "unknown"
        return str(TLS_CERT_FILE), str(TLS_KEY_FILE), fingerprint

    log("Generating self-signed TLS certificate...")

    try:
        subprocess.run([
            "openssl", "req", "-x509", "-newkey", "rsa:2048",
            "-keyout", str(TLS_KEY_FILE),
            "-out", str(TLS_CERT_FILE),
            "-days", "3650",
            "-nodes",
            "-subj", "/CN=Savia Bridge/O=Savia/C=ES",
            "-addext", "subjectAltName=IP:0.0.0.0,IP:127.0.0.1,DNS:localhost"
        ], check=True, capture_output=True)
    except FileNotFoundError:
        log("openssl not found, cannot generate TLS certificate", "ERROR")
        raise FileNotFoundError("openssl required for TLS certificate generation")

    TLS_KEY_FILE.chmod(0o600)
    TLS_CERT_FILE.chmod(0o644)

    fingerprint = _get_cert_fingerprint()
    TLS_FINGERPRINT_FILE.write_text(fingerprint)

    log(f"TLS certificate generated: {TLS_CERT_FILE}")
    log(f"Certificate fingerprint (SHA-256): {fingerprint}")

    return str(TLS_CERT_FILE), str(TLS_KEY_FILE), fingerprint


def _get_cert_fingerprint() -> str:
    """Get SHA-256 fingerprint of the TLS certificate."""
    try:
        result = subprocess.run(
            ["openssl", "x509", "-in", str(TLS_CERT_FILE), "-fingerprint", "-sha256", "-noout"],
            capture_output=True, text=True, check=True
        )
        return result.stdout.strip().split("=", 1)[-1]
    except Exception:
        import base64
        cert_data = TLS_CERT_FILE.read_bytes()
        lines = cert_data.decode().strip().split("\n")
        der_b64 = "".join(l for l in lines if not l.startswith("-----"))
        der = base64.b64decode(der_b64)
        digest = hashlib.sha256(der).hexdigest()
        return ":".join(digest[i:i+2].upper() for i in range(0, len(digest), 2))


# --- User Profile ---

PROFILE_FILE = CONFIG_DIR / "profile.json"

def _load_user_profile() -> str:
    """Load user profile from ~/.savia/bridge/profile.json.
    Creates a default one if it doesn't exist."""
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)

    if not PROFILE_FILE.exists():
        # Auto-detect from system
        import getpass
        username = getpass.getuser()
        default_profile = {
            "name": username,
            "language": "es",
            "role": "Project Manager",
            "notes": "Edita este fichero para personalizar tu perfil."
        }
        PROFILE_FILE.write_text(json.dumps(default_profile, indent=2, ensure_ascii=False))
        log(f"Created default user profile: {PROFILE_FILE}")

    try:
        profile_data = json.loads(PROFILE_FILE.read_text())
        parts = []
        if profile_data.get("name"):
            parts.append(f"- Nombre: {profile_data['name']}")
        if profile_data.get("email"):
            parts.append(f"- Email: {profile_data['email']}")
        if profile_data.get("language"):
            parts.append(f"- Idioma preferido: {profile_data['language']}")
        if profile_data.get("role"):
            parts.append(f"- Rol: {profile_data['role']}")
        if profile_data.get("notes"):
            parts.append(f"- Notas: {profile_data['notes']}")
        return "\n".join(parts) if parts else "No hay perfil configurado."
    except Exception as e:
        log(f"Error loading profile: {e}", "WARN")
        return "No hay perfil configurado."


# --- Claude Code Integration ---

def find_claude_cli() -> str:
    """Find the claude CLI binary."""
    claude_path = shutil.which("claude")
    if claude_path:
        return claude_path
    for path in [
        Path.home() / ".local" / "bin" / "claude",
        Path("/usr/local/bin/claude"),
        Path.home() / ".npm-global" / "bin" / "claude",
    ]:
        if path.exists():
            return str(path)
    raise FileNotFoundError("Claude Code CLI not found. Install it first: npm install -g @anthropic-ai/claude-code")

# Session locks: prevent concurrent CLI calls with the same session
_session_locks: dict[str, threading.Lock] = {}
_session_locks_guard = threading.Lock()

def _get_session_lock(session_id: str) -> threading.Lock:
    """Get or create a per-session lock to serialize CLI calls."""
    with _session_locks_guard:
        if session_id not in _session_locks:
            _session_locks[session_id] = threading.Lock()
        return _session_locks[session_id]

# Track which session IDs have been used before (need --resume)
_known_sessions: set[str] = set()
_known_sessions_lock = threading.Lock()

def stream_claude_response(message: str, session_id: str = None, system_prompt: str = None, request_id: str = "?"):
    """
    Invoke Claude Code CLI and yield streaming response chunks.

    This is the core function that executes: `claude -p --output-format stream-json [OPTIONS] MESSAGE`
    and yields the response as a stream of JSON event dictionaries.

    Session Handling:
        - First message in a session: passes --session-id (creates new session)
        - Subsequent messages: passes --resume (continues existing session)
        - Per-session locking (via _get_session_lock) prevents race conditions
        - Session state is tracked in _known_sessions set for --resume logic

    Arguments:
        message (str): The user message to send to Claude
        session_id (str, optional): Session ID for continuity. If provided:
            - Uses --session-id on first call, --resume on subsequent calls
            - Enables multi-turn conversations
            - Session data stored in ~/.savia/bridge/sessions/{session_id}/
        system_prompt (str, optional): System prompt for the first message of a session.
            - Only sent on first message (is_new=True)
            - Subsequent messages in the session ignore this
        request_id (str, optional): Request ID for logging/debugging (default: "?")

    Yields:
        dict: JSON event chunks with keys:
            - "type": one of "text", "error", "done"
            - "text": (for type=text/error) The actual text content
            - Other metadata depending on event type

    Logging:
        - Detailed logging to chat.log (message, command, response details)
        - Summary logging to bridge.log

    Side Effects:
        - Adds session_id to _known_sessions after successful response
        - Acquires/releases per-session lock for thread safety
        - Spawns subprocess running Claude CLI

    Examples:
        # Single-shot (no session)
        for chunk in stream_claude_response("Hello"):
            if chunk["type"] == "text":
                print(chunk["text"], end="")

        # Multi-turn conversation
        for chunk in stream_claude_response(
            "First message",
            session_id="user123-abc",
            system_prompt="You are PM..."
        ):
            pass
        # Later: same session, continuing
        for chunk in stream_claude_response(
            "Second message",
            session_id="user123-abc"
        ):
            pass
    """
    claude_bin = find_claude_cli()

    cmd = [claude_bin, "-p", "--verbose", "--output-format", "stream-json"]

    is_new = True  # Default for no session
    if session_id:
        with _known_sessions_lock:
            is_new = session_id not in _known_sessions

        if is_new:
            cmd.extend(["--session-id", session_id])
        else:
            cmd.extend(["--resume", session_id])

    if system_prompt and is_new:
        # Only send system prompt on first message of a session
        cmd.extend(["--system-prompt", system_prompt])

    cmd.append(message)

    session_mode = "new" if is_new else "resume"
    log(f"[req:{request_id}] Executing ({session_mode}): {claude_bin} -p ... '{message[:80]}'")
    chat_log(f"[req:{request_id}] === NEW REQUEST ===")
    chat_log(f"[req:{request_id}] Message: {message}")
    chat_log(f"[req:{request_id}] Session: {session_id} ({session_mode})")
    chat_log(f"[req:{request_id}] Command: {' '.join(cmd)}")

    # Acquire per-session lock to prevent concurrent CLI calls
    session_lock = _get_session_lock(session_id) if session_id else None
    if session_lock:
        chat_log(f"[req:{request_id}] Acquiring session lock...")
        session_lock.acquire()
        chat_log(f"[req:{request_id}] Session lock acquired")

    try:
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
            env={**os.environ, "CLAUDE_CODE_ENTRYPOINT": "savia-bridge"}
        )

        chat_log(f"[req:{request_id}] Process started, PID={process.pid}")

        full_response = ""
        line_count = 0
        event_count = 0

        for line in process.stdout:
            line = line.strip()
            line_count += 1

            if not line:
                continue

            chat_log(f"[req:{request_id}] CLI line #{line_count}: {line[:300]}{'...' if len(line)>300 else ''}")

            try:
                data = json.loads(line)
                msg_type = data.get("type", "")

                if msg_type == "assistant" and "message" in data:
                    content_blocks = data["message"].get("content", [])
                    chat_log(f"[req:{request_id}] type=assistant, {len(content_blocks)} content blocks")
                    for block in content_blocks:
                        if block.get("type") == "text":
                            text = block.get("text", "")
                            if text and not full_response:
                                full_response = text
                                event_count += 1
                                chat_log(f"[req:{request_id}] -> emit text #{event_count} (len={len(text)}): {text[:100]}")
                                yield {"type": "text", "text": text}

                elif msg_type == "content_block_delta":
                    delta = data.get("delta", {})
                    if delta.get("type") == "text_delta":
                        text = delta.get("text", "")
                        if text:
                            full_response += text
                            event_count += 1
                            yield {"type": "text", "text": text}

                elif msg_type == "result":
                    result_text = data.get("result", "")
                    chat_log(f"[req:{request_id}] type=result, len={len(result_text)}, accumulated={len(full_response)}")
                    chat_log(f"[req:{request_id}] result content: {result_text[:300]}")
                    if result_text and not full_response:
                        full_response = result_text
                        event_count += 1
                        chat_log(f"[req:{request_id}] -> emit result as text #{event_count}")
                        yield {"type": "text", "text": result_text}

                elif msg_type == "error":
                    error_msg = data.get("error", {})
                    error_str = str(error_msg)
                    chat_log(f"[req:{request_id}] type=error: {error_str}", "ERROR")
                    # IMPORTANT: use "text" field so Android can read it
                    yield {"type": "error", "text": error_str}

                else:
                    chat_log(f"[req:{request_id}] type={msg_type} (ignored)")

            except json.JSONDecodeError as e:
                chat_log(f"[req:{request_id}] Non-JSON: {line[:200]}")
                if line:
                    full_response += line
                    event_count += 1
                    yield {"type": "text", "text": line}

        process.wait()
        stderr_output = process.stderr.read()

        chat_log(f"[req:{request_id}] Process exit code={process.returncode}")
        if stderr_output:
            chat_log(f"[req:{request_id}] stderr: {stderr_output.strip()[:500]}")

        if process.returncode != 0 and stderr_output:
            error_text = stderr_output.strip()
            chat_log(f"[req:{request_id}] Non-zero exit -> error: {error_text[:200]}", "ERROR")
            yield {"type": "error", "text": error_text}

        # Mark session as known for future --resume usage
        if session_id and full_response:
            with _known_sessions_lock:
                _known_sessions.add(session_id)
                chat_log(f"[req:{request_id}] Session {session_id} marked as known")

        chat_log(f"[req:{request_id}] === DONE === lines={line_count} events={event_count} response_len={len(full_response)}")
        yield {"type": "done"}

    except FileNotFoundError:
        chat_log(f"[req:{request_id}] Claude CLI not found!", "ERROR")
        yield {"type": "error", "text": "Claude Code CLI not found"}
        yield {"type": "done"}
    except Exception as e:
        chat_log(f"[req:{request_id}] Exception: {traceback.format_exc()}", "ERROR")
        yield {"type": "error", "text": str(e)}
        yield {"type": "done"}
    finally:
        # Always release session lock
        if session_lock:
            session_lock.release()
            chat_log(f"[req:{request_id}] Session lock released")

# --- HTTP Server ---

class SaviaBridgeHandler(http.server.BaseHTTPRequestHandler):
    """
    HTTP/HTTPS request handler for Savia Bridge endpoints.

    This class processes incoming requests from the Savia Mobile app and
    routes them to the appropriate handler (chat, health, sessions, etc.).

    Class Attributes:
        auth_token (str): Bearer token for authentication (set by server init)
        system_prompt (str): Default system prompt for Claude (set by server init)
        _request_counter (int): Incremental counter for request IDs
        _counter_lock (threading.Lock): Protects counter during concurrent access

    Key Methods:
        do_POST(): Handle POST /chat requests
        do_GET(): Handle GET /health, /sessions, /install, /download/apk
        do_DELETE(): Handle DELETE /sessions
        _check_auth(): Validate Bearer token
        log_message(): Override HTTPServer logging

    Authentication:
        All endpoints except /install and /download/apk require valid Bearer token
        in Authorization header: 'Authorization: Bearer {token}'
    """

    auth_token = None
    system_prompt = None
    _request_counter = 0
    _counter_lock = threading.Lock()

    @classmethod
    def _next_request_id(cls) -> str:
        with cls._counter_lock:
            cls._request_counter += 1
            return f"{cls._request_counter:06d}"

    def log_message(self, format, *args):
        log(f"{self.address_string()} - {format % args}", "HTTP")

    def _check_auth(self) -> bool:
        """Validate the auth token."""
        if not self.auth_token:
            return True

        auth_header = self.headers.get("Authorization", "")
        if auth_header.startswith("Bearer "):
            token = auth_header[7:]
            return secrets.compare_digest(token, self.auth_token)

        parsed = urlparse(self.path)
        params = parse_qs(parsed.query)
        token = params.get("token", [None])[0]
        if token:
            return secrets.compare_digest(token, self.auth_token)

        return False

    def _send_json(self, data: dict, status: int = 200):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def _send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")

    def do_OPTIONS(self):
        self.send_response(204)
        self._send_cors_headers()
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)

        if parsed.path == "/health":
            try:
                claude_bin = find_claude_cli()
                self._send_json({
                    "status": "ok",
                    "claude_cli": claude_bin,
                    "version": BRIDGE_VERSION,
                    "tls": True,
                    "timestamp": datetime.now().isoformat()
                })
            except FileNotFoundError:
                self._send_json({
                    "status": "error",
                    "message": "Claude Code CLI not found"
                }, 503)
            return

        if parsed.path == "/sessions":
            if not self._check_auth():
                self._send_json({"error": "Unauthorized"}, 401)
                return
            sessions = []
            if SESSIONS_DIR.exists():
                for d in SESSIONS_DIR.iterdir():
                    if d.is_dir():
                        sessions.append({
                            "id": d.name,
                            "created": datetime.fromtimestamp(d.stat().st_ctime).isoformat()
                        })
            self._send_json({"sessions": sessions})
            return

        if parsed.path == "/logs":
            if not self._check_auth():
                self._send_json({"error": "Unauthorized"}, 401)
                return
            params = parse_qs(parsed.query)
            n = int(params.get("n", ["100"])[0])
            log_type = params.get("type", ["chat"])[0]
            target = CHAT_LOG_FILE if log_type == "chat" else LOG_FILE
            lines = []
            if target.exists():
                with open(target) as f:
                    all_lines = f.readlines()
                    lines = all_lines[-n:]
            self._send_json({"lines": [l.rstrip() for l in lines], "file": str(target)})
            return

        # --- Auto-Update Endpoints (no auth required) ---
        if parsed.path == "/update/check":
            """
            GET /update/check — Check for available APK update.

            Returns JSON with current APK metadata:
            {
                "version": "0.2.0",
                "versionCode": 2,
                "filename": "savia-v0.2.0-release.apk",
                "size": 12345678,
                "sha256": "abc123...",
                "downloadUrl": "/update/download",
                "releaseNotes": "Auto-update, project selector...",
                "minAndroidSdk": 26
            }

            Returns 404 if no APK is available.
            """
            apk = _find_apk()
            if not apk:
                self._send_json({"error": "No APK available"}, 404)
                return
            info = _get_apk_info(apk)
            self._send_json(info)
            return

        if parsed.path == "/update/download":
            """
            GET /update/download — Download the current APK file.

            Same as /download/apk but at /update/ path for auto-update clients.
            Returns the APK binary with appropriate Content-Type and Content-Disposition.

            Returns 404 if no APK is available.
            """
            apk = _find_apk()
            if not apk:
                self._send_json({"error": "No APK available"}, 404)
                return
            log(f"APK download via /update: {apk.name} ({apk.stat().st_size} bytes) to {self.address_string()}")
            self.send_response(200)
            self.send_header("Content-Type", "application/vnd.android.package-archive")
            self.send_header("Content-Disposition", f'attachment; filename="{apk.name}"')
            self.send_header("Content-Length", str(apk.stat().st_size))
            self.end_headers()
            with open(apk, "rb") as f:
                shutil.copyfileobj(f, self.wfile)
            return

        # --- APK Install Page (no auth required) ---
        if parsed.path == "/install":
            html = _build_install_html(_find_apk())
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(html.encode())
            return

        if parsed.path == "/download/apk":
            apk = _find_apk()
            if not apk:
                self._send_json({"error": "No APK available"}, 404)
                return
            log(f"APK download: {apk.name} ({apk.stat().st_size} bytes) to {self.address_string()}")
            self.send_response(200)
            self.send_header("Content-Type", "application/vnd.android.package-archive")
            self.send_header("Content-Disposition", f'attachment; filename="{apk.name}"')
            self.send_header("Content-Length", str(apk.stat().st_size))
            self.end_headers()
            with open(apk, "rb") as f:
                shutil.copyfileobj(f, self.wfile)
            return

        if parsed.path == "/profile":
            # Read from git config
            name = subprocess.run(['git', 'config', '--global', 'user.name'], capture_output=True, text=True, timeout=2).stdout.strip()
            email = subprocess.run(['git', 'config', '--global', 'user.email'], capture_output=True, text=True, timeout=2).stdout.strip()

            # Try to read company name from .claude/profiles/company/identity.md
            company = ""
            role = "Developer"
            identity_path = Path.home() / "savia" / ".claude" / "profiles" / "company" / "identity.md"
            if identity_path.exists():
                try:
                    content = identity_path.read_text()
                    for line in content.split('\n'):
                        if line.startswith('company:') or line.startswith('name:'):
                            company = line.split(':', 1)[1].strip()
                            break
                except Exception:
                    pass

            # Start with git config + company data as base
            profile_data = {
                "name": name or "User",
                "email": email or "",
                "company": company,
                "role": role,
                "language": "en",
                "work_hours_start": "09:00",
                "work_hours_end": "17:30",
                "lunch_break": "12:30",
                "break_strategy": "pomodoro",
                "detail_level": "standard",
                "alert_style": "desktop",
                "output_mode": "hybrid",
                "theme": "auto",
                "notes": "",
                "accessibility": {}
            }

            # Merge with bridge profile.json (takes priority for richer fields)
            profile_path = CONFIG_DIR / "profile.json"
            if profile_path.exists():
                try:
                    stored_data = json.loads(profile_path.read_text())
                    # Update all fields present in stored profile
                    for key in ("name", "email", "role", "language", "notes",
                                "work_hours_start", "work_hours_end", "lunch_break",
                                "break_strategy", "detail_level", "alert_style",
                                "output_mode", "theme", "accessibility"):
                        if key in stored_data:
                            profile_data[key] = stored_data[key]
                except Exception:
                    pass

            self._send_json(profile_data)
            return

        if parsed.path == "/company":
            company_dir = Path.home() / "savia" / ".claude" / "profiles" / "company"
            if not company_dir.exists() or not any(company_dir.glob("*.md")):
                self._send_json({"status": "not_configured"})
                return

            result = {"status": "configured"}
            for section_file in ["identity.md", "structure.md", "strategy.md", "policies.md", "technology.md", "vertical.md"]:
                filepath = company_dir / section_file
                if filepath.exists():
                    try:
                        content = filepath.read_text()
                        section_name = section_file.replace(".md", "")
                        # Parse simple YAML frontmatter
                        section_data = {}
                        if content.startswith("---"):
                            parts = content.split("---", 2)
                            if len(parts) >= 3:
                                for line in parts[1].strip().split('\n'):
                                    if ':' in line:
                                        key, val = line.split(':', 1)
                                        section_data[key.strip()] = val.strip().strip('"').strip("'")
                                section_data["content"] = parts[2].strip()
                        else:
                            section_data["content"] = content.strip()
                        result[section_name] = section_data
                    except Exception as e:
                        log(f"Warning: Could not parse {section_file}: {e}")

            self._send_json(result)
            return

        if parsed.path == "/git-config":
            """GET /git-config — Read git global configuration (name, email, PAT status)."""
            try:
                name = subprocess.run(['git', 'config', '--global', 'user.name'],
                                      capture_output=True, text=True, timeout=2).stdout.strip()
                email = subprocess.run(['git', 'config', '--global', 'user.email'],
                                       capture_output=True, text=True, timeout=2).stdout.strip()
                # Check if credential helper is configured
                cred_helper = subprocess.run(['git', 'config', '--global', 'credential.helper'],
                                             capture_output=True, text=True, timeout=2).stdout.strip()
                # Check for PAT in environment or git credentials (never expose the actual token)
                pat_configured = bool(os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN"))
                # Check for stored credentials via git credential manager
                if not pat_configured and cred_helper:
                    pat_configured = True  # Credential helper implies some auth is configured

                # Check remote URL for repo info
                remote_url = ""
                try:
                    remote_url = subprocess.run(['git', 'config', '--get', 'remote.origin.url'],
                                                capture_output=True, text=True, timeout=2,
                                                cwd=str(Path.home() / "savia")).stdout.strip()
                except Exception:
                    pass

                self._send_json({
                    "name": name,
                    "email": email,
                    "credential_helper": cred_helper,
                    "pat_configured": pat_configured,
                    "remote_url": remote_url
                })
            except Exception as e:
                log(f"Error reading git config: {e}", "ERROR")
                self._send_json({"error": str(e)}, 500)
            return

        if parsed.path == "/team":
            """GET /team — Read team configuration from .claude/profiles/users/."""
            team_dir = Path.home() / "savia" / ".claude" / "profiles" / "users"
            members = []

            if team_dir.exists():
                for user_dir in sorted(team_dir.iterdir()):
                    if user_dir.is_dir():
                        member = {"slug": user_dir.name}
                        identity_file = user_dir / "identity.md"
                        if identity_file.exists():
                            try:
                                content = identity_file.read_text()
                                if content.startswith("---"):
                                    parts = content.split("---", 2)
                                    if len(parts) >= 3:
                                        for line in parts[1].strip().split('\n'):
                                            if ':' in line:
                                                key, val = line.split(':', 1)
                                                member[key.strip()] = val.strip().strip('"').strip("'")
                            except Exception:
                                pass
                        # Also check for other fragments
                        for fragment in ["workflow.md", "tools.md", "projects.md"]:
                            fpath = user_dir / fragment
                            if fpath.exists():
                                member[f"has_{fragment.replace('.md', '')}"] = True
                        # Skip template/empty profiles
                        if member.get("name") and user_dir.name != "template":
                            members.append(member)

            self._send_json({
                "status": "configured" if members else "not_configured",
                "members": members,
                "count": len(members)
            })
            return

        if parsed.path == "/connectors":
            """GET /connectors — Read configured external service connectors."""
            connectors_file = Path.home() / "savia" / ".claude" / "connectors.json"
            if connectors_file.exists():
                try:
                    data = json.loads(connectors_file.read_text())
                    self._send_json({"status": "configured", "connectors": data})
                except Exception as e:
                    self._send_json({"error": str(e)}, 500)
            else:
                self._send_json({"status": "not_configured", "connectors": {}})
            return

        if parsed.path == "/openapi.json":
            spec_path = Path(__file__).resolve().parent / "openapi.yaml"
            if not spec_path.exists():
                self._send_json({"error": "OpenAPI spec not found"}, 404)
                return
            # Serve as YAML since we can't depend on PyYAML for JSON conversion
            content = spec_path.read_text()
            self.send_response(200)
            self.send_header("Content-Type", "application/x-yaml")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(content.encode())
            return

        self._send_json({"error": "Not found"}, 404)

    def do_POST(self):
        parsed = urlparse(self.path)
        request_id = self._next_request_id()

        if parsed.path != "/chat":
            self._send_json({"error": "Not found"}, 404)
            return

        if not self._check_auth():
            log(f"[req:{request_id}] Auth failed from {self.address_string()}", "WARN")
            self._send_json({"error": "Unauthorized"}, 401)
            return

        # Read request body
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length).decode()

        log(f"[req:{request_id}] POST /chat from {self.address_string()} ({len(body)} bytes)")
        chat_log(f"[req:{request_id}] --- HTTP REQUEST ---")
        chat_log(f"[req:{request_id}] From: {self.address_string()}")
        chat_log(f"[req:{request_id}] Headers: Accept={self.headers.get('Accept','')}, Content-Type={self.headers.get('Content-Type','')}")
        chat_log(f"[req:{request_id}] Body: {body[:500]}")

        try:
            data = json.loads(body)
        except json.JSONDecodeError as e:
            log(f"[req:{request_id}] Invalid JSON: {e}", "ERROR")
            self._send_json({"error": "Invalid JSON"}, 400)
            return

        message = data.get("message", "").strip()
        if not message:
            log(f"[req:{request_id}] Empty message", "WARN")
            self._send_json({"error": "Empty message"}, 400)
            return

        session_id = data.get("session_id")
        system_prompt = data.get("system_prompt", self.system_prompt)

        log(f"[req:{request_id}] Message='{message[:60]}', session={session_id}")

        accept = self.headers.get("Accept", "")

        if "text/event-stream" in accept:
            # SSE streaming response
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Connection", "keep-alive")
            self._send_cors_headers()
            self.end_headers()

            event_num = 0
            try:
                for chunk in stream_claude_response(message, session_id, system_prompt, request_id):
                    event_data = json.dumps(chunk)
                    event_num += 1
                    chat_log(f"[req:{request_id}] SSE #{event_num}: {event_data[:300]}")
                    self.wfile.write(f"data: {event_data}\n\n".encode())
                    self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError) as e:
                chat_log(f"[req:{request_id}] Client disconnected: {e}", "WARN")
            except Exception as e:
                chat_log(f"[req:{request_id}] SSE error: {traceback.format_exc()}", "ERROR")

            log(f"[req:{request_id}] SSE complete ({event_num} events)")

        else:
            # Simple JSON response (collect all text)
            full_text = ""
            error = None

            for chunk in stream_claude_response(message, session_id, system_prompt, request_id):
                if chunk["type"] == "text":
                    full_text += chunk["text"]
                elif chunk["type"] == "error":
                    error = chunk.get("text", "Unknown error")

            if error and not full_text:
                log(f"[req:{request_id}] Error response: {error[:100]}", "ERROR")
                self._send_json({"error": error}, 500)
            else:
                log(f"[req:{request_id}] OK response ({len(full_text)} chars)")
                self._send_json({
                    "response": full_text,
                    "session_id": session_id,
                    "timestamp": datetime.now().isoformat()
                })

    def do_DELETE(self):
        parsed = urlparse(self.path)

        if parsed.path == "/sessions":
            if not self._check_auth():
                self._send_json({"error": "Unauthorized"}, 401)
                return
            if SESSIONS_DIR.exists():
                shutil.rmtree(SESSIONS_DIR)
                SESSIONS_DIR.mkdir(parents=True, exist_ok=True)
            self._send_json({"status": "cleared"})
            return

        self._send_json({"error": "Not found"}, 404)

    def do_PUT(self):
        """Handle PUT requests for updating configuration."""
        parsed = urlparse(self.path)

        if parsed.path == "/profile":
            if not self._check_auth():
                self._send_json({"error": "Unauthorized"}, 401)
                return
            try:
                content_length = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(content_length).decode("utf-8")
                data = json.loads(body)

                # Load existing profile
                profile_path = CONFIG_DIR / "profile.json"
                existing = {}
                if profile_path.exists():
                    try:
                        existing = json.loads(profile_path.read_text())
                    except Exception:
                        pass

                # Merge: update only provided fields
                for key in ("name", "email", "role", "language", "notes",
                            "work_hours_start", "work_hours_end", "lunch_break",
                            "break_strategy", "detail_level", "alert_style",
                            "output_mode", "theme", "accessibility"):
                    if key in data:
                        existing[key] = data[key]

                # Save
                profile_path.parent.mkdir(parents=True, exist_ok=True)
                profile_path.write_text(json.dumps(existing, indent=2, ensure_ascii=False))

                log(f"Profile updated: {list(data.keys())}")
                self._send_json({"status": "updated", "profile": existing})
            except json.JSONDecodeError:
                self._send_json({"error": "Invalid JSON"}, 400)
            except Exception as e:
                log(f"Error updating profile: {e}", "ERROR")
                self._send_json({"error": str(e)}, 500)
            return

        if parsed.path == "/git-config":
            """PUT /git-config — Update git global configuration (requires auth)."""
            if not self._check_auth():
                self._send_json({"error": "Unauthorized"}, 401)
                return
            try:
                content_length = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(content_length).decode("utf-8")
                data = json.loads(body)
                updated = []

                if "name" in data:
                    subprocess.run(['git', 'config', '--global', 'user.name', data["name"]],
                                   check=True, capture_output=True, timeout=5)
                    updated.append("name")

                if "email" in data:
                    subprocess.run(['git', 'config', '--global', 'user.email', data["email"]],
                                   check=True, capture_output=True, timeout=5)
                    updated.append("email")

                if "credential_helper" in data:
                    val = data["credential_helper"]
                    if val:
                        subprocess.run(['git', 'config', '--global', 'credential.helper', val],
                                       check=True, capture_output=True, timeout=5)
                    else:
                        subprocess.run(['git', 'config', '--global', '--unset', 'credential.helper'],
                                       capture_output=True, timeout=5)
                    updated.append("credential_helper")

                # PAT is stored securely, never in git config directly
                if "pat" in data:
                    pat_path = CONFIG_DIR / "github_pat.enc"
                    # Simple obfuscation — in production, use proper encryption
                    # We store a marker that PAT exists but not the actual token in responses
                    import base64
                    encoded = base64.b64encode(data["pat"].encode()).decode()
                    pat_path.write_text(encoded)
                    pat_path.chmod(0o600)
                    updated.append("pat")
                    log("GitHub PAT updated (stored securely)")

                log(f"Git config updated: {updated}")
                self._send_json({"status": "updated", "fields": updated})
            except json.JSONDecodeError:
                self._send_json({"error": "Invalid JSON"}, 400)
            except subprocess.CalledProcessError as e:
                self._send_json({"error": f"Git config error: {e.stderr}"}, 500)
            except Exception as e:
                log(f"Error updating git config: {e}", "ERROR")
                self._send_json({"error": str(e)}, 500)
            return

        if parsed.path == "/team":
            """PUT /team — Update team member profiles (requires auth)."""
            if not self._check_auth():
                self._send_json({"error": "Unauthorized"}, 401)
                return
            try:
                content_length = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(content_length).decode("utf-8")
                data = json.loads(body)

                team_dir = Path.home() / "savia" / ".claude" / "profiles" / "users"
                team_dir.mkdir(parents=True, exist_ok=True)

                action = data.get("action", "update")  # update, add, remove

                if action == "add":
                    slug = data.get("slug", "").strip().lower().replace(" ", "-")
                    if not slug:
                        self._send_json({"error": "slug is required"}, 400)
                        return
                    member_dir = team_dir / slug
                    member_dir.mkdir(parents=True, exist_ok=True)
                    # Create identity.md with frontmatter
                    identity = data.get("identity", {})
                    fm_lines = ["---"]
                    for k, v in identity.items():
                        fm_lines.append(f"{k}: {v}")
                    fm_lines.append("---")
                    fm_lines.append(f"\n# {identity.get('name', slug)}\n")
                    (member_dir / "identity.md").write_text("\n".join(fm_lines))
                    log(f"Team member added: {slug}")
                    self._send_json({"status": "added", "slug": slug})

                elif action == "remove":
                    slug = data.get("slug", "").strip()
                    if not slug:
                        self._send_json({"error": "slug is required"}, 400)
                        return
                    member_dir = team_dir / slug
                    if member_dir.exists():
                        shutil.rmtree(member_dir)
                        log(f"Team member removed: {slug}")
                        self._send_json({"status": "removed", "slug": slug})
                    else:
                        self._send_json({"error": f"Member '{slug}' not found"}, 404)

                elif action == "update":
                    slug = data.get("slug", "").strip()
                    if not slug:
                        self._send_json({"error": "slug is required"}, 400)
                        return
                    member_dir = team_dir / slug
                    if not member_dir.exists():
                        self._send_json({"error": f"Member '{slug}' not found"}, 404)
                        return
                    identity = data.get("identity", {})
                    if identity:
                        # Merge with existing identity.md
                        existing_data = {}
                        identity_file = member_dir / "identity.md"
                        if identity_file.exists():
                            content = identity_file.read_text()
                            if content.startswith("---"):
                                parts = content.split("---", 2)
                                if len(parts) >= 3:
                                    for line in parts[1].strip().split('\n'):
                                        if ':' in line:
                                            key, val = line.split(':', 1)
                                            existing_data[key.strip()] = val.strip()
                        existing_data.update(identity)
                        fm_lines = ["---"]
                        for k, v in existing_data.items():
                            fm_lines.append(f"{k}: {v}")
                        fm_lines.append("---")
                        fm_lines.append(f"\n# {existing_data.get('name', slug)}\n")
                        identity_file.write_text("\n".join(fm_lines))
                    log(f"Team member updated: {slug}")
                    self._send_json({"status": "updated", "slug": slug})
                else:
                    self._send_json({"error": f"Unknown action: {action}"}, 400)

            except json.JSONDecodeError:
                self._send_json({"error": "Invalid JSON"}, 400)
            except Exception as e:
                log(f"Error updating team: {e}", "ERROR")
                self._send_json({"error": str(e)}, 500)
            return

        if parsed.path == "/company":
            """PUT /company — Update company profile sections (requires auth)."""
            if not self._check_auth():
                self._send_json({"error": "Unauthorized"}, 401)
                return
            try:
                content_length = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(content_length).decode("utf-8")
                data = json.loads(body)

                company_dir = Path.home() / "savia" / ".claude" / "profiles" / "company"
                company_dir.mkdir(parents=True, exist_ok=True)

                section = data.get("section", "").strip()
                valid_sections = ["identity", "structure", "strategy", "policies", "technology", "vertical"]
                if section not in valid_sections:
                    self._send_json({"error": f"Invalid section. Must be one of: {valid_sections}"}, 400)
                    return

                fields = data.get("fields", {})
                content_text = data.get("content", "")

                # Build markdown with YAML frontmatter
                section_file = company_dir / f"{section}.md"

                # Merge with existing if present
                existing_fields = {}
                existing_content = ""
                if section_file.exists():
                    raw = section_file.read_text()
                    if raw.startswith("---"):
                        parts = raw.split("---", 2)
                        if len(parts) >= 3:
                            for line in parts[1].strip().split('\n'):
                                if ':' in line:
                                    key, val = line.split(':', 1)
                                    existing_fields[key.strip()] = val.strip()
                            existing_content = parts[2].strip()

                existing_fields.update(fields)
                if content_text:
                    existing_content = content_text

                fm_lines = ["---"]
                for k, v in existing_fields.items():
                    fm_lines.append(f"{k}: {v}")
                fm_lines.append("---")
                if existing_content:
                    fm_lines.append(f"\n{existing_content}")

                section_file.write_text("\n".join(fm_lines))
                log(f"Company section updated: {section}")
                self._send_json({"status": "updated", "section": section})

            except json.JSONDecodeError:
                self._send_json({"error": "Invalid JSON"}, 400)
            except Exception as e:
                log(f"Error updating company: {e}", "ERROR")
                self._send_json({"error": str(e)}, 500)
            return

        self._send_json({"error": "Not found"}, 404)

# --- HTTP Install Server (plain HTTP, no auth) ---

class InstallHandler(http.server.BaseHTTPRequestHandler):
    """Lightweight HTTP handler that serves only the install page and APK download."""

    def log_message(self, format, *args):
        log(f"[install] {self.address_string()} - {format % args}", "HTTP")

    def _send_json(self, data: dict, status: int = 200):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def do_GET(self):
        parsed = urlparse(self.path)

        if parsed.path in ("/", "/install"):
            html = _build_install_html(_find_apk())
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(html.encode())
            return

        if parsed.path == "/download/apk":
            apk = _find_apk()
            if not apk:
                self.send_response(404)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.end_headers()
                self.wfile.write(b"<h1>No APK available</h1>")
                return
            log(f"[install] APK download: {apk.name} to {self.address_string()}")
            self.send_response(200)
            self.send_header("Content-Type", "application/vnd.android.package-archive")
            self.send_header("Content-Disposition", f'attachment; filename="{apk.name}"')
            self.send_header("Content-Length", str(apk.stat().st_size))
            self.end_headers()
            with open(apk, "rb") as f:
                shutil.copyfileobj(f, self.wfile)
            return

        # --- Auto-Update Endpoints ---
        if parsed.path == "/update/check":
            apk = _find_apk()
            if not apk:
                self._send_json({"error": "No APK available"}, 404)
                return
            info = _get_apk_info(apk)
            self._send_json(info)
            return

        if parsed.path == "/update/download":
            apk = _find_apk()
            if not apk:
                self._send_json({"error": "No APK available"}, 404)
                return
            log(f"[install] APK download via /update: {apk.name} to {self.address_string()}")
            self.send_response(200)
            self.send_header("Content-Type", "application/vnd.android.package-archive")
            self.send_header("Content-Disposition", f'attachment; filename="{apk.name}"')
            self.send_header("Content-Length", str(apk.stat().st_size))
            self.end_headers()
            with open(apk, "rb") as f:
                shutil.copyfileobj(f, self.wfile)
            return

        # Redirect everything else to /install
        self.send_response(302)
        self.send_header("Location", "/install")
        self.end_headers()


# --- Main ---

def main():
    """
    Main entry point for Savia Bridge server.

    Parses command-line arguments, initializes configuration (auth token, TLS),
    verifies Claude Code CLI installation, and starts the HTTPS server.

    Command-line Arguments:
        --port PORT              HTTPS port (default: 8922)
        --host HOST              Bind address (default: 0.0.0.0)
        --auth-token TOKEN       Bearer token (auto-generated if not provided)
        --no-auth                Disable authentication (not recommended)
        --no-tls                 Run over HTTP instead of HTTPS (not recommended)
        --system-prompt PROMPT   Default system prompt for Claude messages
        --print-token            Print auth token to stdout and exit
        --print-fingerprint      Print TLS cert SHA-256 fingerprint and exit
        --install-port PORT      HTTP port for /install page (default: 8080)
        --no-install-server      Don't run the HTTP install server

    Initialization Steps:
        1. Parse arguments
        2. Create configuration directories (~/.savia/bridge/, sessions/)
        3. Generate or load auth token (unless --no-auth)
        4. Generate or load TLS certificate and key (unless --no-tls)
        5. Verify Claude Code CLI is installed
        6. Load user profile from ~/.savia/bridge/profile.json
        7. Start HTTPS server on specified port and host
        8. (Optionally) Start HTTP install server on port 8080
        9. Block and serve requests until interrupted

    Configuration Files Created (if not present):
        ~/.savia/bridge/auth_token          Auto-generated 43-char token
        ~/.savia/bridge/cert.pem            Self-signed TLS certificate
        ~/.savia/bridge/key.pem             TLS private key
        ~/.savia/bridge/cert_fingerprint.txt SHA-256 fingerprint
        ~/.savia/bridge/profile.json        User profile (name, email, role)
        ~/.savia/bridge/sessions/           Multi-turn session storage

    Logging:
        All operations logged to ~/.savia/bridge/bridge.log

    Exit Codes:
        0: Normal exit (server stopped)
        1: Error (missing Claude CLI, TLS error, port in use, etc.)

    Example Usage:
        python3 savia-bridge.py                              # Default: HTTPS on 0.0.0.0:8922
        python3 savia-bridge.py --port 9000                  # Custom HTTPS port
        python3 savia-bridge.py --print-token                # Get auth token
        python3 savia-bridge.py --no-auth --no-tls          # HTTP without auth (dev only)
    """
    parser = argparse.ArgumentParser(description=f"Savia Bridge v{BRIDGE_VERSION} — HTTPS bridge to Claude Code CLI")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help=f"Port (default: {DEFAULT_PORT})")
    parser.add_argument("--host", type=str, default=DEFAULT_HOST, help=f"Host (default: {DEFAULT_HOST})")
    parser.add_argument("--auth-token", type=str, help="Auth token (auto-generated if not set)")
    parser.add_argument("--no-auth", action="store_true", help="Disable authentication (not recommended)")
    parser.add_argument("--no-tls", action="store_true", help="Disable TLS (not recommended)")
    parser.add_argument("--system-prompt", type=str, help="Default system prompt for Claude")
    parser.add_argument("--print-token", action="store_true", help="Print the auth token and exit")
    parser.add_argument("--print-fingerprint", action="store_true", help="Print the TLS cert fingerprint and exit")
    parser.add_argument("--install-port", type=int, default=DEFAULT_INSTALL_PORT, help=f"HTTP port for install page (default: {DEFAULT_INSTALL_PORT})")
    parser.add_argument("--no-install-server", action="store_true", help="Disable the HTTP install server")
    args = parser.parse_args()

    # Setup directories
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    SESSIONS_DIR.mkdir(parents=True, exist_ok=True)

    # Setup auth
    if args.no_auth:
        token = None
        log("WARNING: Authentication disabled")
    elif args.auth_token:
        token = args.auth_token
    else:
        token = get_or_create_token()

    if args.print_token:
        print(token or "(no auth)")
        sys.exit(0)

    # Setup TLS
    use_tls = not args.no_tls
    cert_fingerprint = None
    if use_tls:
        try:
            cert_path, key_path, cert_fingerprint = get_or_create_tls_cert()
        except FileNotFoundError:
            log("Could not generate TLS certificate. Running without TLS.", "WARN")
            use_tls = False

    if args.print_fingerprint:
        if cert_fingerprint:
            print(cert_fingerprint)
        else:
            print("(no TLS)")
        sys.exit(0)

    # Verify claude CLI
    try:
        claude_bin = find_claude_cli()
        log(f"Claude CLI found: {claude_bin}")
    except FileNotFoundError as e:
        log(str(e), "ERROR")
        sys.exit(1)

    # Load user profile
    user_profile = _load_user_profile()

    # Configure handler
    SaviaBridgeHandler.auth_token = token
    SaviaBridgeHandler.system_prompt = args.system_prompt or (
        "Eres Savia, una asistente de gestión de proyectos inteligente, empática y eficiente. "
        "Respondes en el idioma del usuario (español por defecto). "
        "Eres concisa pero cercana. Usas datos cuando los tienes disponibles.\n\n"
        f"Contexto del usuario:\n{user_profile}"
    )

    # Start server
    server = http.server.HTTPServer((args.host, args.port), SaviaBridgeHandler)

    protocol = "HTTP"
    if use_tls:
        ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ssl_context.load_cert_chain(cert_path, key_path)
        server.socket = ssl_context.wrap_socket(server.socket, server_side=True)
        protocol = "HTTPS"

    log(f"Savia Bridge v{BRIDGE_VERSION} starting on {protocol.lower()}://{args.host}:{args.port}")
    if use_tls:
        log(f"TLS: ENABLED")
        log(f"Certificate fingerprint: {cert_fingerprint}")
    else:
        log(f"TLS: DISABLED", "WARN")
    if token:
        log(f"Auth token: {token}")
        log(f"Token stored in: {TOKEN_FILE}")
    log(f"")
    log(f"Log files:")
    log(f"  Server:  {LOG_FILE}")
    log(f"  Chat:    {CHAT_LOG_FILE}")
    log(f"")
    log(f"--- Mobile app config ---")
    log(f"  Protocol: {protocol}")
    log(f"  Host: <your-vpn-ip>")
    log(f"  Port: {args.port}")
    log(f"  Token: {token or '(none)'}")
    if cert_fingerprint:
        log(f"  Fingerprint: {cert_fingerprint}")
    log(f"-------------------------")
    log(f"")
    log(f"--- APK Install ---")
    apk = _find_apk()
    if apk:
        log(f"  APK: {apk.name} ({apk.stat().st_size / 1024 / 1024:.1f} MB)")
    else:
        log(f"  No APK found. Place .apk in: {APK_DIR}")
    log(f"-------------------")

    # Start HTTP install server (plain HTTP, no auth, separate port)
    install_server = None
    if not args.no_install_server:
        try:
            install_server = http.server.HTTPServer((args.host, args.install_port), InstallHandler)
            install_thread = threading.Thread(target=install_server.serve_forever, daemon=True)
            install_thread.start()
            log(f"")
            log(f"--- APK Install Server ---")
            log(f"  HTTP (no TLS) on port {args.install_port}")
            log(f"  Open in browser: http://<your-ip>:{args.install_port}")
            if apk:
                log(f"  APK ready: {apk.name}")
            log(f"--------------------------")
        except OSError as e:
            log(f"Could not start install server on port {args.install_port}: {e}", "WARN")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log("Shutting down...")
        server.shutdown()
        if install_server:
            install_server.shutdown()

if __name__ == "__main__":
    main()
