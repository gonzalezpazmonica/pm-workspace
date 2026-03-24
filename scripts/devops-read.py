#!/usr/bin/env python3
"""Savia DevOps Reader — READ-ONLY browser scraping of Azure DevOps.

CRITICAL: This script NEVER modifies anything. No clicks on Edit, Save,
New, Delete, or any action button. Only navigation and text extraction.

Uses browser session (account2) to read Azure DevOps pages.
"""
import json
import os
import sys
import time
from pathlib import Path

os.environ["PYTHONUTF8"] = "1"

SAVIA_DIR = Path.home() / ".savia"
OUTPUT_DIR = SAVIA_DIR / "devops-read"
ACCOUNTS_FILE = SAVIA_DIR / "mail-accounts.json"


def load_account(alias="account2"):
    with open(ACCOUNTS_FILE, "r") as f:
        accounts = json.load(f)
    return accounts[alias]


def safe_extract_text(page, selector, limit=100):
    """Extract text from elements matching selector. READ ONLY."""
    return page.evaluate(
        """([sel, lim]) => {
        const results = [];
        document.querySelectorAll(sel).forEach(el => {
            const text = (el.innerText || '').trim();
            if (text.length > 3 && text.length < 2000)
                results.push(text.substring(0, 1000));
        });
        return results.slice(0, lim);
    }""",
        [selector, limit],
    )


def safe_extract_table(page):
    """Extract table/grid data from the page. READ ONLY."""
    return page.evaluate("""() => {
        const results = [];
        // Try grid rows (Azure DevOps uses various grid patterns)
        const rows = document.querySelectorAll(
            '.grid-row, [role="row"], tr.grid-row-normal, ' +
            '.work-item-row, [class*="backlog-row"], ' +
            '.agile-board-card, [class*="board-tile"]'
        );
        rows.forEach(row => {
            const text = (row.innerText || '').trim();
            if (text.length > 5 && text.length < 2000)
                results.push(text.substring(0, 800));
        });
        return results.slice(0, 100);
    }""")


def safe_extract_cards(page):
    """Extract board cards. READ ONLY."""
    return page.evaluate("""() => {
        const results = [];
        const cards = document.querySelectorAll(
            '[class*="board-tile"], [class*="card"], ' +
            '[class*="work-item"], [role="listitem"]'
        );
        cards.forEach(card => {
            const text = (card.innerText || '').trim();
            if (text.length > 10 && text.length < 1000)
                results.push(text.substring(0, 600));
        });
        return results.slice(0, 80);
    }""")


def read_devops(base_url: str, pages_to_read: list = None, team: str = ""):
    """Read Azure DevOps pages. STRICTLY READ-ONLY."""
    from playwright.sync_api import sync_playwright
    from urllib.parse import quote

    cfg = load_account("account2")
    session_dir = str(SAVIA_DIR / cfg["session_dir"])
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    team_encoded = quote(team, safe="") if team else ""

    if pages_to_read is None:
        pages_to_read = ["backlog", "board", "sprint"]

    result = {
        "url": base_url,
        "ts": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "pages": {},
    }

    with sync_playwright() as p:
        browser = p.chromium.launch_persistent_context(
            session_dir,
            headless=False,
            args=["--window-position=-2000,-2000", "--window-size=1600,1000"],
            viewport={"width": 1600, "height": 1000},
            timeout=0,
        )
        page = browser.pages[0] if browser.pages else browser.new_page()

        try:
            # Test access first
            page.goto(base_url, timeout=30000)
            page.wait_for_timeout(8000)
            url = page.url
            if "login.microsoftonline" in url or "sso." in url:
                page.screenshot(path=str(OUTPUT_DIR / "login-blocked.png"))
                browser.close()
                return {"error": "session_expired", "url": base_url}

            page.screenshot(path=str(OUTPUT_DIR / "landing.png"))
            result["pages"]["landing"] = {
                "title": page.title(),
                "url": page.url,
            }

            # 1. Backlog
            if "backlog" in pages_to_read:
                backlog_url = (
                    base_url.rstrip("/")
                    + "/_backlogs/backlog/{team_encoded}/Backlog%20items"
                )
                page.goto(backlog_url, timeout=30000)
                page.wait_for_timeout(8000)
                page.screenshot(path=str(OUTPUT_DIR / "backlog.png"))
                items = safe_extract_table(page)
                text = safe_extract_text(
                    page,
                    '[class*="backlog"], [class*="grid"], '
                    "[role='treegrid'], [role='grid']",
                )
                result["pages"]["backlog"] = {
                    "url": page.url,
                    "title": page.title(),
                    "items_count": len(items),
                    "items": items,
                    "grid_text": text,
                }

            # 2. Board
            if "board" in pages_to_read:
                board_url = (
                    base_url.rstrip("/")
                    + "/_boards/board/{team_encoded}/Backlog%20items"
                )
                page.goto(board_url, timeout=30000)
                page.wait_for_timeout(8000)
                page.screenshot(path=str(OUTPUT_DIR / "board.png"))
                cards = safe_extract_cards(page)
                result["pages"]["board"] = {
                    "url": page.url,
                    "title": page.title(),
                    "cards_count": len(cards),
                    "cards": cards,
                }

            # 3. Current sprint
            if "sprint" in pages_to_read:
                sprint_url = (
                    base_url.rstrip("/")
                    + "/_sprints/taskboard/{team_encoded}"
                )
                page.goto(sprint_url, timeout=30000)
                page.wait_for_timeout(8000)
                page.screenshot(path=str(OUTPUT_DIR / "sprint.png"))
                sprint_items = safe_extract_table(page)
                sprint_cards = safe_extract_cards(page)
                result["pages"]["sprint"] = {
                    "url": page.url,
                    "title": page.title(),
                    "items_count": len(sprint_items),
                    "items": sprint_items,
                    "cards": sprint_cards,
                }

            # 4. Queries — recent/active items
            if "queries" in pages_to_read:
                queries_url = base_url.rstrip("/") + "/_queries"
                page.goto(queries_url, timeout=30000)
                page.wait_for_timeout(6000)
                page.screenshot(path=str(OUTPUT_DIR / "queries.png"))
                result["pages"]["queries"] = {
                    "url": page.url,
                    "title": page.title(),
                }

        except Exception as e:
            result["error"] = str(e)[:400]
            try:
                page.screenshot(path=str(OUTPUT_DIR / "error.png"))
            except Exception:
                pass
        finally:
            browser.close()

    # Save to disk
    out_file = OUTPUT_DIR / "devops-snapshot.json"
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    return result


def main():
    url = sys.argv[1] if len(sys.argv) > 1 else ""
    if not url:
        print("Usage: devops-read.py <azure-devops-project-url>")
        sys.exit(1)

    pages = ["backlog", "board", "sprint"]
    team = ""
    if "--pages" in sys.argv:
        idx = sys.argv.index("--pages")
        pages = sys.argv[idx + 1].split(",") if idx + 1 < len(sys.argv) else pages
    if "--team" in sys.argv:
        idx = sys.argv.index("--team")
        team = sys.argv[idx + 1] if idx + 1 < len(sys.argv) else ""

    result = read_devops(url, pages, team=team)
    print(
        json.dumps(result, ensure_ascii=False, indent=2),
        file=open(1, "w", encoding="utf-8", closefd=False),
    )


if __name__ == "__main__":
    main()
