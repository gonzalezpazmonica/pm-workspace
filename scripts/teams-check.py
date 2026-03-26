#!/usr/bin/env python3
"""Savia Teams Check — Read chats and channels from Teams Web.

Uses Playwright with saved browser session (same as inbox-check).
Read-only: extracts conversations, files, activity. Never modifies.

Usage:
    python3 teams-check.py [account-alias|all]
    python3 teams-check.py account1 --section chats
    python3 teams-check.py account2 --section channels
"""
import json
import os
import sys
import time
from pathlib import Path

os.environ["PYTHONUTF8"] = "1"

SAVIA_DIR = Path.home() / ".savia"
OUTPUT_DIR = SAVIA_DIR / "teams-inbox"
ACCOUNTS_FILE = SAVIA_DIR / "mail-accounts.json"

TEAMS_URL = "https://teams.microsoft.com/v2/"
TEAMS_CHAT_URL = "https://teams.microsoft.com/v2/chat"
TEAMS_TEAMS_URL = "https://teams.microsoft.com/v2/teams"
TEAMS_ACTIVITY_URL = "https://teams.microsoft.com/v2/activity"


def load_accounts() -> dict:
    with open(ACCOUNTS_FILE, "r") as f:
        return json.load(f)


def wait_for_teams_load(page, timeout_ms=15000):
    """Wait for Teams to fully load (SPA takes time)."""
    try:
        page.wait_for_load_state("networkidle", timeout=timeout_ms)
    except Exception:
        pass
    page.wait_for_timeout(5000)


def extract_activity(page) -> list:
    """Extract recent activity feed."""
    return page.evaluate("""() => {
        const results = [];
        const items = document.querySelectorAll(
            '[data-tid*="activity"], [class*="activity"] li, ' +
            '[role="listitem"], [class*="feed-item"]'
        );
        items.forEach(el => {
            const text = (el.innerText || '').trim();
            if (text.length > 20 && text.length < 1000) {
                results.push(text.substring(0, 600));
            }
        });
        return results.slice(0, 30);
    }""")


def extract_chat_list(page) -> list:
    """Extract list of recent chats with preview."""
    return page.evaluate("""() => {
        const results = [];
        const items = document.querySelectorAll(
            '[data-tid*="chat-list-item"], [class*="chat-list"] [role="listitem"], ' +
            '[role="treeitem"], [class*="listItem"]'
        );
        items.forEach(el => {
            const text = (el.innerText || '').trim();
            if (text.length > 10 && text.length < 800) {
                results.push(text.substring(0, 500));
            }
        });
        return results.slice(0, 30);
    }""")


def extract_chat_messages(page) -> list:
    """Extract messages from the currently open chat."""
    return page.evaluate("""() => {
        const results = [];
        const msgs = document.querySelectorAll(
            '[data-tid*="message"], [class*="message-body"], ' +
            '[role="group"] [class*="text"], [class*="chat-message"]'
        );
        msgs.forEach(el => {
            const text = (el.innerText || '').trim();
            if (text.length > 5 && text.length < 2000) {
                results.push(text.substring(0, 1000));
            }
        });
        return results.slice(-40);
    }""")


def extract_channel_list(page) -> list:
    """Extract list of teams and channels."""
    return page.evaluate("""() => {
        const results = [];
        const items = document.querySelectorAll(
            '[data-tid*="team-"], [class*="channel-list"] [role="treeitem"], ' +
            '[role="treeitem"], [class*="team-name"], [class*="channel-name"]'
        );
        items.forEach(el => {
            const text = (el.innerText || '').trim();
            if (text.length > 3 && text.length < 300) {
                results.push(text.substring(0, 200));
            }
        });
        return results.slice(0, 40);
    }""")


def read_teams_direct(alias: str, cfg: dict, section: str = "all") -> dict:
    """Read Teams data directly via browser session."""
    from playwright.sync_api import sync_playwright

    session_dir = str(SAVIA_DIR / cfg["session_dir"])
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    result = {
        "account": alias,
        "ts": time.strftime("%Y-%m-%dT%H:%M:%S"),
    }

    with sync_playwright() as p:
        browser = p.chromium.launch_persistent_context(
            session_dir,
            headless=False,
            args=["--window-position=-2000,-2000", "--window-size=1400,900"],
            viewport={"width": 1400, "height": 900},
            timeout=0,
        )
        page = browser.pages[0] if browser.pages else browser.new_page()

        try:
            # 1. Activity feed
            if section in ("all", "activity"):
                page.goto(TEAMS_ACTIVITY_URL)
                wait_for_teams_load(page)
                url = page.url
                if "login.microsoftonline" in url or "sso." in url:
                    page.screenshot(
                        path=str(OUTPUT_DIR / f"{alias}-login-blocked.png")
                    )
                    browser.close()
                    return {"account": alias, "error": "session_expired"}
                result["activity"] = extract_activity(page)
                page.screenshot(
                    path=str(OUTPUT_DIR / f"{alias}-activity.png")
                )

            # 2. Chats
            if section in ("all", "chats"):
                page.goto(TEAMS_CHAT_URL)
                wait_for_teams_load(page)
                result["chats"] = extract_chat_list(page)
                page.screenshot(
                    path=str(OUTPUT_DIR / f"{alias}-chats.png")
                )

                # Open first 5 chats and read recent messages
                chat_details = []
                chat_items = page.query_selector_all(
                    '[role="treeitem"], [data-tid*="chat-list-item"], '
                    '[class*="listItem"]'
                )
                for i, item in enumerate(chat_items[:5]):
                    try:
                        item.click()
                        page.wait_for_timeout(3000)
                        msgs = extract_chat_messages(page)
                        if msgs:
                            chat_details.append({
                                "chat_index": i,
                                "preview": (item.inner_text() or "")[:200],
                                "messages": msgs[-10:],
                            })
                    except Exception:
                        continue
                result["chat_details"] = chat_details

            # 3. Teams/Channels
            if section in ("all", "channels"):
                page.goto(TEAMS_TEAMS_URL)
                wait_for_teams_load(page)
                result["channels"] = extract_channel_list(page)
                page.screenshot(
                    path=str(OUTPUT_DIR / f"{alias}-channels.png")
                )

        except Exception as e:
            result["error"] = str(e)[:300]
            try:
                page.screenshot(
                    path=str(OUTPUT_DIR / f"{alias}-error.png")
                )
            except Exception:
                pass
        finally:
            browser.close()

    # Save full result to disk
    out_file = OUTPUT_DIR / f"{alias}-teams.json"
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    return result


def main():
    accounts = load_accounts()
    target = sys.argv[1] if len(sys.argv) > 1 else "all"
    section = "all"
    if "--section" in sys.argv:
        idx = sys.argv.index("--section")
        section = sys.argv[idx + 1] if idx + 1 < len(sys.argv) else "all"

    aliases = list(accounts.keys()) if target == "all" else [target]

    results = []
    for alias in aliases:
        cfg = accounts.get(alias)
        if not cfg:
            results.append({"account": alias, "error": "unknown_account"})
            continue
        results.append(read_teams_direct(alias, cfg, section))

    print(
        json.dumps(results, ensure_ascii=False, indent=2),
        file=open(1, "w", encoding="utf-8", closefd=False),
    )


if __name__ == "__main__":
    main()
