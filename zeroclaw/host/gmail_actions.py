"""Gmail actions — send, verify and CLI for gmail_browser (SPEC-041b).

Compose via URL (most reliable), verify via Sent folder, Ctrl+Enter to send.
"""
import json, sys, urllib.parse
from gmail_browser import (
    _get_browser, _dismiss_overlays, _check_logged_in,
    GMAIL_BASE, read_inbox, read_email, count_unread,
)


def send_email(to, subject, body, cc=None):
    """Send email via Gmail compose URL. Most reliable method."""
    p, browser, page = _get_browser()
    try:
        params = f"view=cm&fs=1&to={to}&su={urllib.parse.quote(subject)}"
        params += f"&body={urllib.parse.quote(body)}"
        if cc:
            params += f"&cc={cc}"
        page.goto(f"{GMAIL_BASE}/?{params}")
        page.wait_for_timeout(5000)
        _dismiss_overlays(page)
        page.evaluate("""() => {
            const ed = document.querySelector(
                '[g_editable="true"], [contenteditable="true"][role="textbox"]');
            if (ed) ed.focus();
        }""")
        page.wait_for_timeout(500)
        page.keyboard.press("Control+Enter")
        page.wait_for_timeout(5000)
        return verify_sent(subject, page)
    finally:
        browser.close(); p.stop()


def verify_sent(subject_contains, page=None):
    """Check Sent folder for email with given subject. Verification step."""
    own_browser = page is None
    if own_browser:
        p, browser, page = _get_browser()
    try:
        page.goto(f"{GMAIL_BASE}/#sent")
        page.wait_for_timeout(3000)
        _dismiss_overlays(page)
        emails = page.evaluate("""() => {
            const r = [];
            document.querySelectorAll('tr.zA').forEach(el => {
                r.push(el.innerText.trim().substring(0, 300));
            });
            return r;
        }""")
        for e in emails:
            if subject_contains.lower() in e.lower():
                return {"sent": True, "match": e[:150]}
        return {"sent": False, "checked": len(emails)}
    finally:
        if own_browser:
            browser.close(); p.stop()


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "inbox"
    if cmd == "inbox":
        for e in read_inbox(5):
            flag = "*" if e.get("unread") else " "
            print(f" {flag} [{e['sender']}] {e['subject']}")
    elif cmd == "read":
        idx = int(sys.argv[2]) if len(sys.argv) > 2 else 0
        print(read_email(idx))
    elif cmd == "send":
        r = send_email(sys.argv[2], sys.argv[3], sys.argv[4],
                       sys.argv[5] if len(sys.argv) > 5 else None)
        print(json.dumps(r, indent=2))
    elif cmd == "unread":
        print(f"Unread: {count_unread()}")
    elif cmd == "verify":
        print(json.dumps(verify_sent(sys.argv[2]), indent=2))
    else:
        print("Usage: gmail_actions.py {inbox|read|send|unread|verify} [args]")
