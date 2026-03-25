"""Gmail Browser Agent — read inbox via Playwright (SPEC-041b).

Persistent session, read-only functions. For sending, use gmail_actions.
Lessons: overlays block clicks, TrustedHTML blocks innerHTML,
compose URL is the most reliable way to send, Ctrl+Enter sends from editor.
"""
import os, urllib.parse
from pathlib import Path

SAVIA_DIR = Path.home() / ".savia"
SESSION_DIR = str(SAVIA_DIR / "browser-sessions" / "saviaclaw")
GMAIL_BASE = "https://mail.google.com/mail/u/0"


def _get_browser():
    """Launch or reuse persistent browser session."""
    os.environ["DISPLAY"] = ":99"
    from playwright.sync_api import sync_playwright
    p = sync_playwright().start()
    browser = p.chromium.launch_persistent_context(
        SESSION_DIR, headless=False, args=["--no-sandbox"],
        viewport={"width": 1280, "height": 800})
    page = browser.pages[0] if browser.pages else browser.new_page()
    return p, browser, page


def _dismiss_overlays(page):
    """Remove Gmail welcome wizards and popups."""
    page.evaluate("() => document.querySelectorAll('.uW2Fw-JD').forEach(e => e.remove())")
    page.wait_for_timeout(300)


def _check_logged_in(page):
    return "signin" not in page.url and "accounts.google" not in page.url


def read_inbox(limit=10):
    """Read inbox emails. Returns list of {sender, subject, snippet, unread}."""
    p, browser, page = _get_browser()
    try:
        page.goto(f"{GMAIL_BASE}/#inbox")
        page.wait_for_timeout(5000)
        if not _check_logged_in(page):
            return {"error": "session_expired"}
        _dismiss_overlays(page)
        return page.evaluate("""(limit) => {
            const r = [];
            document.querySelectorAll('tr.zA').forEach(el => {
                const sender = el.querySelector('.bA4 span, .yW span');
                const subject = el.querySelector('.bog');
                const snippet = el.querySelector('.y2');
                const unread = el.classList.contains('zE');
                r.push({sender: sender ? sender.innerText.trim() : '',
                    subject: subject ? subject.innerText.trim() : '',
                    snippet: snippet ? snippet.innerText.trim() : '',
                    unread: unread});
            });
            return r.slice(0, limit);
        }""", limit)
    finally:
        browser.close(); p.stop()


def read_email(index=0):
    """Open and read an email by inbox position. Returns full text."""
    p, browser, page = _get_browser()
    try:
        page.goto(f"{GMAIL_BASE}/#inbox")
        page.wait_for_timeout(5000)
        _dismiss_overlays(page)
        page.evaluate(f"""() => {{
            const rows = document.querySelectorAll('tr.zA');
            if (rows[{index}]) rows[{index}].dispatchEvent(
                new MouseEvent('click', {{bubbles:true}}));
        }}""")
        page.wait_for_timeout(4000)
        return page.evaluate("""() => {
            const selectors = ['.a3s.aiL', '.ii.gt', '.nH .a3s'];
            for (const s of selectors) {
                const el = document.querySelector(s);
                if (el && el.innerText.trim().length > 20)
                    return el.innerText.trim();
            }
            const main = document.querySelector('[role="main"]');
            return main ? main.innerText.trim().substring(0, 5000) : '';
        }""")
    finally:
        browser.close(); p.stop()


def count_unread():
    """Quick unread count from inbox."""
    p, browser, page = _get_browser()
    try:
        page.goto(f"{GMAIL_BASE}/#inbox")
        page.wait_for_timeout(5000)
        if not _check_logged_in(page):
            return -1
        _dismiss_overlays(page)
        return page.evaluate(
            "() => document.querySelectorAll('tr.zA.zE').length")
    finally:
        browser.close(); p.stop()
