"""Gmail checker via Playwright — SaviaClaw's window to the world.
Uses persistent browser session (no password needed after first auth).
Checks inbox, detects new emails, notifies via Talk, responds if needed.
"""
import os, json, time
from pathlib import Path

SAVIA_DIR = Path.home() / ".savia"
SESSION_DIR = str(SAVIA_DIR / "browser-sessions" / "saviaclaw")
GMAIL_STATE = str(SAVIA_DIR / "gmail-last-check.json")
INBOX_URL = "https://mail.google.com/mail/u/0/#inbox"

def _load_state():
    if os.path.isfile(GMAIL_STATE):
        with open(GMAIL_STATE) as f: return json.load(f)
    return {"last_count": 0, "known_subjects": []}

def _save_state(state):
    os.makedirs(os.path.dirname(GMAIL_STATE), exist_ok=True)
    with open(GMAIL_STATE, "w") as f: json.dump(state, f)

def check_inbox(logger=None):
    """Check inbox using gmail_browser component."""
    try:
        from .gmail_browser import read_inbox
        emails = read_inbox(10)
        if isinstance(emails, dict) and "error" in emails:
            if logger: logger.warning("Gmail: %s", emails["error"])
            return emails
        unread = [e for e in emails if e.get("unread")]
        return {"emails": unread, "count": len(unread)}
    except Exception as e:
        if logger: logger.error("Gmail check: %s", e)
        return None

def check_and_notify(claude_fn, notify_fn, logger=None):
    """Check Gmail, notify via Talk if new emails found."""
    result = check_inbox(logger)
    if not result or "error" in result: return

    state = _load_state()
    new_emails = []
    for e in result.get("emails", []):
        if e["subject"] not in state["known_subjects"]:
            new_emails.append(e)
            state["known_subjects"].append(e["subject"])

    # Keep only last 50 known subjects
    state["known_subjects"] = state["known_subjects"][-50:]
    state["last_count"] = result.get("count", 0)
    _save_state(state)

    if new_emails:
        msg = f"Correo nuevo ({len(new_emails)}):\n"
        for e in new_emails:
            msg += f"- De: {e['sender']} — {e['subject']}\n"
        if logger: logger.info("Gmail: %d new emails", len(new_emails))
        notify_fn(msg)
