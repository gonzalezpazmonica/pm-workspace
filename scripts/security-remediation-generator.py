#!/usr/bin/env python3
"""security-remediation-generator.py — SPEC-070: Security Auto-Remediation PRs.

Generates concrete fix suggestions based on vulnerability type.

Usage:
  python3 scripts/security-remediation-generator.py \
      --type "sql-injection" \
      --code "cursor.execute('SELECT * FROM users WHERE id=' + user_id)"

Output JSON:
  {
    "vulnerability_type": str,
    "severity": "high" | "medium" | "low",
    "fix_description": str,
    "code_patch_suggestion": str,
    "references": [str],
    "confidence": float
  }
"""
from __future__ import annotations

import argparse
import json
import sys

# ── Vulnerability knowledge base ──────────────────────────────────────────────

VULN_CATALOG: dict[str, dict] = {
    "sql-injection": {
        "severity": "high",
        "fix_description": (
            "Replace string concatenation/interpolation in SQL queries with "
            "parameterized queries or prepared statements. Never build SQL strings "
            "from user-controlled input."
        ),
        "code_patch_suggestion": (
            "# BEFORE (vulnerable)\n"
            "cursor.execute('SELECT * FROM users WHERE id=' + user_id)\n\n"
            "# AFTER (safe — parameterized query)\n"
            "cursor.execute('SELECT * FROM users WHERE id = %s', (user_id,))\n\n"
            "# C# / .NET equivalent:\n"
            "// cmd.CommandText = \"SELECT * FROM users WHERE id = @id\";\n"
            "// cmd.Parameters.AddWithValue(\"@id\", userId);"
        ),
        "references": [
            "https://owasp.org/www-community/attacks/SQL_Injection",
            "https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html",
        ],
        "confidence": 0.95,
    },
    "xss": {
        "severity": "high",
        "fix_description": (
            "Escape all user-controlled data before inserting it into HTML output. "
            "Use context-appropriate escaping (HTML entity encoding for HTML context, "
            "JS escaping for script context). Prefer a trusted templating engine with "
            "auto-escaping enabled."
        ),
        "code_patch_suggestion": (
            "# BEFORE (vulnerable — raw interpolation)\n"
            "html = '<div>' + user_input + '</div>'\n\n"
            "# AFTER (safe — HTML escaped)\n"
            "import html as html_lib\n"
            "safe_input = html_lib.escape(user_input)\n"
            "output = f'<div>{safe_input}</div>'\n\n"
            "# JavaScript equivalent:\n"
            "// element.textContent = userInput;  // safe (not innerHTML)"
        ),
        "references": [
            "https://owasp.org/www-community/attacks/xss/",
            "https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html",
        ],
        "confidence": 0.93,
    },
    "hardcoded-cred": {
        "severity": "high",
        "fix_description": (
            "Remove hardcoded credentials, API keys, tokens, or secrets from source code. "
            "Load them from environment variables or a secrets manager at runtime. "
            "Rotate any credentials that were exposed."
        ),
        "code_patch_suggestion": (
            "# BEFORE (vulnerable — hardcoded secret)\n"
            "API_KEY = 'sk-abc123supersecret'\n\n"
            "# AFTER (safe — environment variable)\n"
            "import os\n"
            "API_KEY = os.environ['API_KEY']  # set in CI/CD secrets or .env (gitignored)\n\n"
            "# .env.example (committed — no real values):\n"
            "# API_KEY=your_api_key_here\n\n"
            "# .gitignore:\n"
            "# .env"
        ),
        "references": [
            "https://owasp.org/www-community/vulnerabilities/Use_of_hard-coded_password",
            "https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html",
        ],
        "confidence": 0.97,
    },
    "path-traversal": {
        "severity": "high",
        "fix_description": (
            "Validate and sanitize file paths supplied by users. Resolve the canonical "
            "absolute path and verify it falls within the expected base directory before "
            "opening or operating on the file."
        ),
        "code_patch_suggestion": (
            "# BEFORE (vulnerable)\n"
            "filepath = '/var/data/' + user_filename\n"
            "with open(filepath) as f: ...\n\n"
            "# AFTER (safe — canonical path check)\n"
            "import os\n"
            "BASE_DIR = os.path.realpath('/var/data')\n"
            "candidate = os.path.realpath(os.path.join(BASE_DIR, user_filename))\n"
            "if not candidate.startswith(BASE_DIR + os.sep):\n"
            "    raise ValueError('Path traversal detected')\n"
            "with open(candidate) as f: ..."
        ),
        "references": [
            "https://owasp.org/www-community/attacks/Path_Traversal",
            "https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html",
        ],
        "confidence": 0.92,
    },
    "insecure-deserialization": {
        "severity": "high",
        "fix_description": (
            "Avoid deserializing untrusted data using pickle, eval, or other unsafe "
            "mechanisms. Use JSON or a schema-validated format with an allowlist of "
            "accepted types."
        ),
        "code_patch_suggestion": (
            "# BEFORE (vulnerable)\n"
            "import pickle\n"
            "obj = pickle.loads(user_data)  # arbitrary code execution risk\n\n"
            "# AFTER (safe — JSON with schema validation)\n"
            "import json\n"
            "from jsonschema import validate\n"
            "schema = {'type': 'object', 'properties': {'name': {'type': 'string'}}}\n"
            "obj = json.loads(user_data)\n"
            "validate(instance=obj, schema=schema)"
        ),
        "references": [
            "https://owasp.org/www-community/vulnerabilities/Deserialization_of_untrusted_data",
            "https://cheatsheetseries.owasp.org/cheatsheets/Deserialization_Cheat_Sheet.html",
        ],
        "confidence": 0.90,
    },
    "command-injection": {
        "severity": "high",
        "fix_description": (
            "Never pass user input directly to shell commands. Use subprocess with "
            "argument lists (not shell=True) to prevent shell metacharacter injection."
        ),
        "code_patch_suggestion": (
            "# BEFORE (vulnerable)\n"
            "import os\n"
            "os.system('ping ' + user_host)\n\n"
            "# AFTER (safe — argument list, no shell=True)\n"
            "import subprocess\n"
            "result = subprocess.run(\n"
            "    ['ping', '-c', '1', user_host],\n"
            "    capture_output=True, text=True, timeout=5\n"
            ")"
        ),
        "references": [
            "https://owasp.org/www-community/attacks/Command_Injection",
            "https://cheatsheetseries.owasp.org/cheatsheets/OS_Command_Injection_Defense_Cheat_Sheet.html",
        ],
        "confidence": 0.94,
    },
    "csrf": {
        "severity": "medium",
        "fix_description": (
            "Protect state-changing endpoints with CSRF tokens. Validate the Origin / "
            "Referer header for requests and use SameSite=Strict or SameSite=Lax cookies."
        ),
        "code_patch_suggestion": (
            "# Django example — enable CSRF middleware (enabled by default)\n"
            "MIDDLEWARE = [\n"
            "    'django.middleware.csrf.CsrfViewMiddleware',\n"
            "    ...\n"
            "]\n\n"
            "# In forms:\n"
            "# {% csrf_token %}\n\n"
            "# Set secure cookie flags:\n"
            "SESSION_COOKIE_SAMESITE = 'Strict'\n"
            "CSRF_COOKIE_SAMESITE = 'Strict'"
        ),
        "references": [
            "https://owasp.org/www-community/attacks/csrf",
            "https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html",
        ],
        "confidence": 0.88,
    },
    "sensitive-data-exposure": {
        "severity": "medium",
        "fix_description": (
            "Encrypt sensitive data at rest and in transit. Do not log PII or credentials. "
            "Apply field-level encryption or masking for sensitive fields in responses and logs."
        ),
        "code_patch_suggestion": (
            "# BEFORE (exposing sensitive field)\n"
            "return {'user': user.email, 'password_hash': user.password_hash}\n\n"
            "# AFTER (exclude sensitive fields)\n"
            "return {'user': user.email}\n\n"
            "# For logs — mask PII:\n"
            "import re\n"
            "def mask_email(text: str) -> str:\n"
            "    return re.sub(r'[\\w.+-]+@[\\w-]+\\.[\\w.]+', '[EMAIL]', text)"
        ),
        "references": [
            "https://owasp.org/www-project-top-ten/2017/A3_2017-Sensitive_Data_Exposure",
            "https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html",
        ],
        "confidence": 0.85,
    },
    "broken-auth": {
        "severity": "high",
        "fix_description": (
            "Enforce strong password policies, multi-factor authentication, and secure "
            "session management. Use constant-time comparison for token/password checks. "
            "Invalidate sessions on logout and after privilege changes."
        ),
        "code_patch_suggestion": (
            "# BEFORE (timing-vulnerable token comparison)\n"
            "if token == stored_token: ...\n\n"
            "# AFTER (constant-time comparison)\n"
            "import hmac\n"
            "if hmac.compare_digest(token.encode(), stored_token.encode()): ...\n\n"
            "# Always expire sessions on logout:\n"
            "request.session.flush()"
        ),
        "references": [
            "https://owasp.org/www-project-top-ten/2017/A2_2017-Broken_Authentication",
            "https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html",
        ],
        "confidence": 0.87,
    },
    "open-redirect": {
        "severity": "medium",
        "fix_description": (
            "Validate redirect URLs against an allowlist of trusted domains or paths. "
            "Never use raw user input as a redirect target."
        ),
        "code_patch_suggestion": (
            "# BEFORE (open redirect)\n"
            "return redirect(request.GET.get('next', '/'))\n\n"
            "# AFTER (validated redirect)\n"
            "from urllib.parse import urlparse\n"
            "ALLOWED_HOSTS = {'example.com', 'api.example.com'}\n"
            "next_url = request.GET.get('next', '/')\n"
            "parsed = urlparse(next_url)\n"
            "if parsed.netloc and parsed.netloc not in ALLOWED_HOSTS:\n"
            "    next_url = '/'\n"
            "return redirect(next_url)"
        ),
        "references": [
            "https://cheatsheetseries.owasp.org/cheatsheets/Unvalidated_Redirects_and_Forwards_Cheat_Sheet.html",
        ],
        "confidence": 0.86,
    },
}

# ── Canonical aliases ─────────────────────────────────────────────────────────

ALIASES: dict[str, str] = {
    "sqli": "sql-injection",
    "sql_injection": "sql-injection",
    "cross-site-scripting": "xss",
    "cross_site_scripting": "xss",
    "hardcoded-secret": "hardcoded-cred",
    "hardcoded-password": "hardcoded-cred",
    "hardcoded_cred": "hardcoded-cred",
    "hardcoded_credential": "hardcoded-cred",
    "path_traversal": "path-traversal",
    "directory-traversal": "path-traversal",
    "deserialization": "insecure-deserialization",
    "cmd-injection": "command-injection",
    "command_injection": "command-injection",
    "os-injection": "command-injection",
    "sensitive_data": "sensitive-data-exposure",
    "data-exposure": "sensitive-data-exposure",
    "auth": "broken-auth",
    "broken_auth": "broken-auth",
    "redirect": "open-redirect",
}

# ── Generator ─────────────────────────────────────────────────────────────────

def generate(vuln_type: str, code: str = "") -> dict:
    """Generate a remediation suggestion for the given vulnerability type.

    Args:
        vuln_type: Vulnerability identifier (from VULN_CATALOG or ALIASES).
        code: Optional vulnerable code fragment (used to contextualize the patch).

    Returns:
        Dict with vulnerability_type, severity, fix_description,
        code_patch_suggestion, references, confidence.
    """
    normalized = vuln_type.strip().lower()
    canonical = ALIASES.get(normalized, normalized)
    entry = VULN_CATALOG.get(canonical)

    if entry is None:
        # Unknown type — return generic advice with lower confidence
        return {
            "vulnerability_type": vuln_type,
            "severity": "medium",
            "fix_description": (
                f"No specific remediation template found for '{vuln_type}'. "
                "Apply defense-in-depth: validate all inputs, apply least privilege, "
                "keep dependencies updated, and follow OWASP guidelines."
            ),
            "code_patch_suggestion": (
                "# Review code for:\n"
                "# - Unvalidated user input\n"
                "# - Missing authentication/authorization checks\n"
                "# - Use of deprecated or insecure APIs"
            ),
            "references": [
                "https://owasp.org/www-project-top-ten/",
            ],
            "confidence": 0.40,
        }

    patch = entry["code_patch_suggestion"]
    if code:
        patch = f"# Vulnerable code provided:\n# {code}\n\n{patch}"

    return {
        "vulnerability_type": canonical,
        "severity": entry["severity"],
        "fix_description": entry["fix_description"],
        "code_patch_suggestion": patch,
        "references": list(entry["references"]),
        "confidence": entry["confidence"],
    }


# ── CLI ───────────────────────────────────────────────────────────────────────

def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="SPEC-070 security remediation generator"
    )
    p.add_argument(
        "--type",
        dest="vuln_type",
        required=True,
        help=(
            "Vulnerability type: sql-injection, xss, hardcoded-cred, "
            "path-traversal, command-injection, insecure-deserialization, "
            "csrf, sensitive-data-exposure, broken-auth, open-redirect, ..."
        ),
    )
    p.add_argument(
        "--code",
        default="",
        help="Optional: vulnerable code fragment for context",
    )
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    result = generate(args.vuln_type, args.code)
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
