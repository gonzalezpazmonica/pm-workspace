#!/usr/bin/env python3
"""Savia Inbox Check — Read and classify emails from Outlook Web.

Uses Playwright with saved browser session to read emails.
Accounts are configured in ~/.savia/mail-accounts.json (local, gitignored).

Usage:
    python3 inbox-check.py [account-alias|all]
"""
import json
import os
import sys
import time
from pathlib import Path

os.environ["PYTHONUTF8"] = "1"

SAVIA_DIR = Path.home() / ".savia"
OUTPUT_DIR = SAVIA_DIR / "outlook-inbox"
COMMANDS_DIR = SAVIA_DIR / "browser-commands"
ACCOUNTS_FILE = SAVIA_DIR / "mail-accounts.json"

# SPEC-SH03 helpers
sys.path.insert(0, str(Path(__file__).resolve().parent))
from heartbeat_helpers import HeartbeatPoller  # noqa: E402


def load_accounts() -> dict:
    """Load account config from local file (never in git)."""
    if not ACCOUNTS_FILE.exists():
        print(f"No accounts configured. Create {ACCOUNTS_FILE}")
        sys.exit(1)
    with open(ACCOUNTS_FILE, "r") as f:
        return json.load(f)


def read_inbox_via_daemon(alias: str) -> dict:
    """Send check-mail command to running daemon and poll heartbeat (SH03)."""
    COMMANDS_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    cmd_file = COMMANDS_DIR / f"{alias}-cmd.json"
    result_file = OUTPUT_DIR / f"{alias}-mail-result.json"

    # Clear stale result before sending command
    if result_file.exists():
        result_file.unlink()

    with open(cmd_file, "w") as f:
        json.dump({"action": "check-mail"}, f)

    poller = HeartbeatPoller(result_file, op="check-mail", hard_cap_s=600)
    final = poller.run_until_terminal()
    if not isinstance(final, dict) or not final:
        final = {"account": alias, "error": "no_payload"}
    final.setdefault("account", alias)
    final["_poll_rc"] = poller.exit_code
    return final


def read_inbox_direct(alias: str, cfg: dict) -> dict:
    """Read inbox directly (fallback if daemon not running)."""
    from playwright.sync_api import sync_playwright

    session_dir = str(SAVIA_DIR / cfg["session_dir"])
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    with sync_playwright() as p:
        browser = p.chromium.launch_persistent_context(
            session_dir,
            headless=False,
            args=["--window-position=-2000,-2000", "--window-size=1200,800"],
            viewport={"width": 1200, "height": 800},
            timeout=0,
        )
        page = browser.pages[0] if browser.pages else browser.new_page()
        page.goto(cfg.get("mail_url", "https://outlook.office365.com/mail/inbox"))
        page.wait_for_timeout(8000)

        url = page.url
        if "login.microsoftonline" in url or "sso." in url:
            browser.close()
            return {"account": alias, "error": "session_expired"}

        emails = page.evaluate("""() => {
            const results = [];
            document.querySelectorAll('[draggable="true"]').forEach(el => {
                const text = (el.innerText || '').trim();
                if (text.length > 10) results.push(text.substring(0, 500));
            });
            return results.slice(0, 25);
        }""")

        page.screenshot(path=str(OUTPUT_DIR / f"{alias}-screenshot.png"))
        browser.close()

    return {
        "account": alias,
        "ts": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "count": len(emails),
        "emails": emails,
    }


def main():
    accounts = load_accounts()
    target = sys.argv[1] if len(sys.argv) > 1 else "all"
    aliases = list(accounts.keys()) if target == "all" else [target]

    results = []
    for alias in aliases:
        cfg = accounts.get(alias)
        if not cfg:
            results.append({"account": alias, "error": "unknown_account"})
            continue

        # Try daemon first, fallback to direct
        status_file = OUTPUT_DIR / f"{alias}-status.json"
        daemon_running = False
        if status_file.exists():
            with open(status_file) as f:
                st = json.load(f)
            daemon_running = st.get("status") == "running"

        if daemon_running:
            results.append(read_inbox_via_daemon(alias))
        else:
            results.append(read_inbox_direct(alias, cfg))

    print(
        json.dumps(results, ensure_ascii=False, indent=2),
        file=open(1, "w", encoding="utf-8", closefd=False),
    )


if __name__ == "__main__":
    main()
