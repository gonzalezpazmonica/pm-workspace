#!/usr/bin/env python3
"""
code-twin-simulate.py — SPEC-190 Slice 5

Symbolic simulation engine for Application Code Twin (ACT).
Reads a CTF (Code Twin File) and simulates the target method symbolically
using seed data and heuristic confidence scoring.

Usage:
  python3 scripts/code-twin-simulate.py <module_id> <method> <args_json> <seeds_dir>

Arguments:
  module_id   — CTF module_id to locate (e.g. AuthService)
  method      — method to simulate (e.g. login)
  args_json   — JSON object with method arguments (e.g. '{"email":"...","password":"..."}')
  seeds_dir   — directory containing *.jsonl seed files; twin_dir = parent(seeds_dir)

Exit codes:
  0 — simulation succeeded, result produced
  1 — simulation raised a domain error (INVALID_CREDENTIALS, USER_DISABLED, …)
  2 — engine error (missing CTF, bad args, seeds not found)

Output:
  Line 1: [SIMULATION — NOT GROUND TRUTH] confidence=<value>
  Line 2+: JSON payload

IMPORTANT: Output is NEVER ground truth. confidence is NEVER 1.0.
"""

import sys
import os
import json
import re
import pathlib
import uuid

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

HEADER = "[SIMULATION \u2014 NOT GROUND TRUTH]"
CONFIDENCE_BASE = 0.95
CONFIDENCE_PENALTY_BCRYPT = 0.05
CONFIDENCE_PENALTY_JWT = 0.02


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def err(msg: str, code: int = 2) -> None:
    """Print error to stderr and exit with given code."""
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(code)


def load_jsonl(path: pathlib.Path) -> list:
    """Load a JSONL file and return a list of dicts."""
    rows = []
    with open(path, encoding="utf-8") as fh:
        for lineno, raw in enumerate(fh, 1):
            raw = raw.strip()
            if raw:
                try:
                    rows.append(json.loads(raw))
                except json.JSONDecodeError as exc:
                    err(f"Invalid JSON at {path}:{lineno}: {exc}")
    return rows


def find_ctf(twin_dir: str, module_id: str):
    """
    Scan twin_dir recursively for a .md file whose frontmatter contains
    `module_id: <module_id>`. Returns (Path, content_str) or (None, None).
    """
    pattern = re.compile(
        rf"^module_id:\s*{re.escape(module_id)}\s*$", re.MULTILINE
    )
    for p in sorted(pathlib.Path(twin_dir).rglob("*.md")):
        try:
            content = p.read_text(encoding="utf-8")
        except OSError:
            continue
        if pattern.search(content):
            return p, content
    return None, None


def extract_method_block(content: str, method: str):
    """
    Extract the markdown block for a given method from a CTF.
    Returns the raw block text or None.
    """
    pattern = re.compile(
        rf"####\s+{re.escape(method)}\s*\([^)]*\).*?(?=\n####|\Z)",
        re.DOTALL,
    )
    m = pattern.search(content)
    return m.group(0) if m else None


def extract_logic_steps(block: str) -> list:
    """Extract numbered logic steps from a method block."""
    logic_m = re.search(
        r"\*\*Logic\*\*:(.*?)(?=\*\*Side effects\*\*|\*\*Edge cases\*\*|\Z)",
        block,
        re.DOTALL,
    )
    if not logic_m:
        return []
    return re.findall(r"^\d+\.\s+(.+)$", logic_m.group(1), re.MULTILINE)


def extract_edge_cases(block: str) -> list:
    """Extract edge case descriptions from a method block."""
    edge_m = re.search(
        r"\*\*Edge cases\*\*:(.*?)(?=\n####|\Z)", block, re.DOTALL
    )
    if not edge_m:
        return []
    return re.findall(r"[^\u2192\n]+\u2192[^\u2192\n]+", edge_m.group(1))


def calculate_confidence(steps: list, edges: list) -> float:
    """
    Calculate simulation confidence (0.0–<1.0).
    Base 0.95; deduct for external services that cannot be perfectly simulated.
    Confidence is NEVER 1.0.
    """
    conf = CONFIDENCE_BASE
    all_text = " ".join(steps + edges).lower()
    if "bcrypt" in all_text:
        conf -= CONFIDENCE_PENALTY_BCRYPT
    if "jwt" in all_text:
        conf -= CONFIDENCE_PENALTY_JWT
    # Hard cap: never 1.0
    return round(min(conf, 0.99), 4)


# ---------------------------------------------------------------------------
# Symbolic password check (sim: convention)
# ---------------------------------------------------------------------------

def sim_password_check(password: str, hash_str: str) -> bool:
    """
    Symbolic bcrypt replacement.
    If hash starts with 'sim:', compare password to the suffix.
    Real bcrypt hashes cannot be verified — return False (conservative).
    """
    if hash_str.startswith("sim:"):
        expected = hash_str[4:]
        return password == expected
    return False


def sim_token(user_id: str, roles: list) -> str:
    """Generate a deterministic-ish simulation token. NOT a real JWT."""
    short_id = re.sub(r"[^a-zA-Z0-9]", "", user_id)[:8]
    suffix = uuid.uuid4().hex[:8]
    return f"sim-token-{short_id}-{suffix}"


# ---------------------------------------------------------------------------
# Method handlers
# ---------------------------------------------------------------------------

def simulate_login(args_json: str, seeds_dir: str, logic: dict) -> tuple:
    """
    Simulate AuthService.login symbolically.

    Follows CTF logic:
      1. UserRepository.findByEmail(email) — READ
      2. bcrypt.compare / disabled check
      3. JwtService.sign — fake token
      4. UserRepository.updateLastLogin — WRITE

    Returns (result_dict, exit_code).
    """
    try:
        args = json.loads(args_json)
    except json.JSONDecodeError as exc:
        err(f"Invalid args JSON: {exc}")

    email = args.get("email")
    password = args.get("password")
    if not email or password is None:
        err("args must contain 'email' and 'password'")

    seeds_path = pathlib.Path(seeds_dir) / "users.jsonl"
    if not seeds_path.exists():
        err(f"Seeds file not found: {seeds_path}")

    users = load_jsonl(seeds_path)
    confidence = calculate_confidence(logic["steps"], logic["edges"])
    db_trace = []
    side_effects = []

    # Step 1: UserRepository.findByEmail(email) — always a READ
    db_trace.append({"op": "READ", "table": "users", "filter": f"email={email}"})
    user = next((u for u in users if u.get("email") == email), None)

    if user is None:
        return {
            "confidence": confidence,
            "result": None,
            "error": {
                "code": "INVALID_CREDENTIALS",
                "status": 401,
                "message": "Invalid credentials",
            },
            "db_trace": db_trace,
            "side_effects": side_effects,
        }, 1

    # Edge case: user.disabled=true → THROW 403 USER_DISABLED
    if user.get("disabled", False):
        return {
            "confidence": confidence,
            "result": None,
            "error": {
                "code": "USER_DISABLED",
                "status": 403,
                "message": "User account is disabled",
            },
            "db_trace": db_trace,
            "side_effects": side_effects,
        }, 1

    # Step 2: bcrypt.compare(password, user.passwordHash)
    if not sim_password_check(password, user.get("password_hash", "")):
        return {
            "confidence": confidence,
            "result": None,
            "error": {
                "code": "INVALID_CREDENTIALS",
                "status": 401,
                "message": "Invalid credentials",
            },
            "db_trace": db_trace,
            "side_effects": side_effects,
        }, 1

    # Step 3: JwtService.sign(...)
    token = sim_token(user["id"], user.get("roles", []))

    # Step 4: UserRepository.updateLastLogin(user.id, now) — WRITE
    db_trace.append({"op": "WRITE", "table": "users", "fields": ["last_login_at"]})
    side_effects.append("DB WRITE users.last_login_at")

    return {
        "confidence": confidence,
        "result": {
            "token": token,
            "user": {
                "id": user["id"],
                "roles": user.get("roles", []),
            },
        },
        "db_trace": db_trace,
        "side_effects": side_effects,
    }, 0


# Registry of supported method handlers
METHOD_HANDLERS = {
    "login": simulate_login,
}


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    if len(sys.argv) != 5:
        err(
            f"Usage: {os.path.basename(sys.argv[0])} "
            "<module_id> <method> <args_json> <seeds_dir>"
        )

    module_id = sys.argv[1]
    method = sys.argv[2]
    args_json = sys.argv[3]
    seeds_dir = sys.argv[4]

    if not os.path.isdir(seeds_dir):
        err(f"seeds_dir not found or not a directory: {seeds_dir}")

    twin_dir = str(pathlib.Path(seeds_dir).parent)

    ctf_path, ctf_content = find_ctf(twin_dir, module_id)
    if ctf_path is None:
        err(f"CTF not found for module_id='{module_id}' in '{twin_dir}'")

    block = extract_method_block(ctf_content, method)
    if block is None:
        err(f"Method '{method}' not found in CTF '{ctf_path}'")

    steps = extract_logic_steps(block)
    edges = extract_edge_cases(block)
    logic = {"steps": steps, "edges": edges}

    handler = METHOD_HANDLERS.get(method)
    if handler is None:
        err(f"No simulation handler registered for method '{method}'")

    result, exit_code = handler(args_json, seeds_dir, logic)
    confidence = result["confidence"]

    payload = {
        "module_id": module_id,
        "method": method,
        **result,
    }

    print(f"{HEADER} confidence={confidence}")
    print(json.dumps(payload, indent=2))
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
