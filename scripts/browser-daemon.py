#!/usr/bin/env python3
"""Savia Browser Daemon — persistent off-screen browser per account.
Accounts: ~/.savia/mail-accounts.json (local, never in git).
Usage: python3 browser-daemon.py <alias> [--auth]
"""
import json, os, sys, time

os.environ["PYTHONUTF8"] = "1"

from browser_helpers import (  # noqa: E402
    SIGNAL, OUTPUT_DIR, COMMANDS_DIR, KEEPALIVE_INTERVAL,
    load_account, extract_emails, extract_calendar,
)


def run_daemon(alias, auth_mode=False):
    from playwright.sync_api import sync_playwright

    cfg = load_account(alias)
    session_dir = str(SIGNAL.parent / cfg["session_dir"])
    mail_url = cfg.get("mail_url", "https://outlook.office365.com/mail/inbox")
    cal_url = cfg.get("calendar_url", "https://outlook.office365.com/calendar/view/day")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    COMMANDS_DIR.mkdir(parents=True, exist_ok=True)

    p = sync_playwright().start()

    if auth_mode:
        if SIGNAL.exists():
            SIGNAL.unlink()
        browser = p.chromium.launch_persistent_context(
            session_dir, headless=False,
            args=["--start-maximized"], viewport=None, timeout=0,
        )
        page = browser.pages[0] if browser.pages else browser.new_page()
        page.goto(mail_url, wait_until="commit")
        print(f"Auth mode: authenticate {alias} in browser. Signal when done.")

        for _ in range(120):
            time.sleep(5)
            if SIGNAL.exists():
                SIGNAL.unlink()
                break
        else:
            print("Timeout waiting for auth signal")
            browser.close(); p.stop(); return

        page.wait_for_timeout(3000)
        if "login" in page.url:
            print("Auth not completed")
            browser.close(); p.stop(); return

        page.evaluate("window.moveTo(-2000, -2000)")
        page.evaluate("window.resizeTo(1200, 800)")
        print(f"Auth OK. Daemon {alias} active (off-screen).")
    else:
        browser = p.chromium.launch_persistent_context(
            session_dir, headless=False,
            args=["--window-position=-2000,-2000", "--window-size=1200,800"],
            viewport={"width": 1200, "height": 800}, timeout=0,
        )
        page = browser.pages[0] if browser.pages else browser.new_page()
        page.goto(mail_url)
        page.wait_for_timeout(5000)

        if "login" in page.url or "sso." in page.url:
            status = {"account": alias, "status": "needs_auth",
                      "ts": time.strftime("%Y-%m-%dT%H:%M:%S")}
            with open(OUTPUT_DIR / f"{alias}-status.json", "w") as f:
                json.dump(status, f)
            browser.close(); p.stop(); return

    status = {"account": alias, "status": "running",
              "ts": time.strftime("%Y-%m-%dT%H:%M:%S")}
    with open(OUTPUT_DIR / f"{alias}-status.json", "w") as f:
        json.dump(status, f)

    last_keepalive = time.time()

    while True:
        try:
            cmd_file = COMMANDS_DIR / f"{alias}-cmd.json"
            if cmd_file.exists():
                with open(cmd_file, "r") as f:
                    cmd = json.load(f)
                cmd_file.unlink()
                action = cmd.get("action", "check-mail")
                result = {"account": alias, "action": action,
                          "ts": time.strftime("%Y-%m-%dT%H:%M:%S")}

                if action == "check-mail":
                    page.goto(mail_url)
                    page.wait_for_timeout(8000)
                    if "login" in page.url:
                        result["error"] = "session_expired"
                    else:
                        result["emails"] = extract_emails(page)
                        result["count"] = len(result["emails"])
                        page.screenshot(
                            path=str(OUTPUT_DIR / f"{alias}-screenshot.png"))

                elif action == "check-calendar":
                    page.goto(cal_url)
                    page.wait_for_timeout(8000)
                    if "login" in page.url:
                        result["error"] = "session_expired"
                    else:
                        result["events"] = extract_calendar(page)
                        result["count"] = len(result["events"])
                        page.screenshot(
                            path=str(OUTPUT_DIR / f"{alias}-calendar.png"))

                elif action == "stop":
                    browser.close(); p.stop(); return

                with open(OUTPUT_DIR / f"{alias}-result.json", "w",
                          encoding="utf-8") as f:
                    json.dump(result, f, ensure_ascii=False, indent=2)

            if time.time() - last_keepalive > KEEPALIVE_INTERVAL:
                page.reload()
                page.wait_for_timeout(3000)
                if "login" in page.url:
                    s = {"account": alias, "status": "session_expired",
                         "ts": time.strftime("%Y-%m-%dT%H:%M:%S")}
                    with open(OUTPUT_DIR / f"{alias}-status.json", "w") as f:
                        json.dump(s, f)
                last_keepalive = time.time()

            time.sleep(5)

        except Exception as e:
            with open(OUTPUT_DIR / f"{alias}-status.json", "w") as f:
                json.dump({"account": alias, "status": "error",
                           "error": str(e),
                           "ts": time.strftime("%Y-%m-%dT%H:%M:%S")}, f)
            time.sleep(10)


if __name__ == "__main__":
    alias = sys.argv[1] if len(sys.argv) > 1 else "account1"
    auth = "--auth" in sys.argv
    run_daemon(alias, auth_mode=auth)
