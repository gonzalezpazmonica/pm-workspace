#!/usr/bin/env python3
"""Savia Browser Daemon — persistent off-screen browser per account.
Accounts: ~/.savia/mail-accounts.json (local, never in git).
Usage: python3 browser-daemon.py <alias> [--auth]

Supported actions (via ~/.savia/browser-commands/{alias}-cmd.json):
  {"action": "check-mail"}
  {"action": "check-calendar"}
  {"action": "check-teams"}                  # extract current chat + sidebar list
  {"action": "check-teams", "chat": "name"}  # open chat by title then extract
  {"action": "stop"}

The daemon also exposes a Chrome DevTools Protocol port so other scripts can
`connect_over_cdp` without fighting the Chromium profile lock. Default ports:
account1=9222, account2=9223. Override per account via accounts file
("cdp_port") or env SAVIA_CDP_PORT.
"""
import json, os, sys, time

os.environ["PYTHONUTF8"] = "1"

from browser_helpers import (  # noqa: E402
    SIGNAL, OUTPUT_DIR, COMMANDS_DIR, KEEPALIVE_INTERVAL,
    DEFAULT_CDP_PORTS,
    load_account, extract_emails, extract_calendar,
    extract_teams_chat_list, extract_teams_active_chat,
    click_teams_chat, load_teams_extractor_js,
    list_teams_items, open_chat_by_deep_link,
)

# SPEC-SH03 heartbeat helpers (lazy import path-safe)
import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent))
from heartbeat_helpers import HeartbeatWriter as _HBWriter  # noqa: E402


def resolve_cdp_port(alias, cfg):
    """Priority: env SAVIA_CDP_PORT > accounts file cdp_port > default map."""
    env_port = os.environ.get("SAVIA_CDP_PORT")
    if env_port:
        try:
            return int(env_port)
        except ValueError:
            pass
    if "cdp_port" in cfg:
        return int(cfg["cdp_port"])
    return DEFAULT_CDP_PORTS.get(alias, 0)


def run_daemon(alias, auth_mode=False):
    from playwright.sync_api import sync_playwright

    cfg = load_account(alias)
    session_dir = str(SIGNAL.parent / cfg["session_dir"])
    mail_url = cfg.get("mail_url", "https://outlook.office365.com/mail/inbox")
    cal_url = cfg.get("calendar_url", "https://outlook.office365.com/calendar/view/day")
    teams_url = cfg.get("teams_url", "https://teams.microsoft.com/v2/chat")
    cdp_port = resolve_cdp_port(alias, cfg)

    # Preload the Teams extractor JS (fails fast if the file is missing).
    teams_extractor_js = load_teams_extractor_js()

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    COMMANDS_DIR.mkdir(parents=True, exist_ok=True)

    # Build base Chromium args. CDP port is opt-in (0 disables it).
    base_args = []
    if cdp_port:
        base_args.append(f"--remote-debugging-port={cdp_port}")

    p = sync_playwright().start()

    if auth_mode:
        if SIGNAL.exists():
            SIGNAL.unlink()
        browser = p.chromium.launch_persistent_context(
            session_dir, headless=False,
            args=base_args + ["--start-maximized"],
            viewport=None, timeout=0,
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
        print(f"Auth OK. Daemon {alias} active (off-screen). CDP port: {cdp_port or 'disabled'}")
    else:
        browser = p.chromium.launch_persistent_context(
            session_dir, headless=False,
            args=base_args + [
                "--window-position=-2000,-2000",
                "--window-size=1200,800",
            ],
            viewport={"width": 1200, "height": 800}, timeout=0,
        )
        page = browser.pages[0] if browser.pages else browser.new_page()
        page.goto(mail_url)
        page.wait_for_timeout(5000)

        if "login" in page.url or "sso." in page.url:
            status = {"account": alias, "status": "needs_auth",
                      "ts": time.strftime("%Y-%m-%dT%H:%M:%S"),
                      "cdp_port": cdp_port}
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
                    include_sent = bool(cmd.get("include_sent", True))
                    _mail_path = OUTPUT_DIR / f"{alias}-mail-result.json"
                    _mail_trace = OUTPUT_DIR / f"{alias}-mail-trace.jsonl"
                    _hb = _HBWriter(_mail_path, alias, "check-mail",
                                    trace_path=_mail_trace)
                    _hb.start()
                    try:
                        _hb.update(phase="inbox-load")
                        page.goto(mail_url)
                        page.wait_for_timeout(8000)
                        if "login" in page.url:
                            result["error"] = "session_expired"
                            _hb.terminal_session_expired(extra=result)
                            result["_hb_terminal"] = "session_expired"
                        else:
                            _hb.update(phase="inbox-extract")
                            result["emails"] = extract_emails(page)
                            result["count"] = len(result["emails"])
                            _hb.update(phase="inbox-extract",
                                       processed=result["count"])
                            page.screenshot(
                                path=str(OUTPUT_DIR / f"{alias}-screenshot.png"))
                            if include_sent:
                                _hb.update(phase="sent-load")
                                if "/mail/inbox" in mail_url:
                                    sent_url = mail_url.replace("/mail/inbox", "/mail/sentitems")
                                else:
                                    sent_url = mail_url.rstrip("/") + "/sentitems"
                                try:
                                    page.goto(sent_url)
                                    page.wait_for_timeout(8000)
                                    if "login" not in page.url:
                                        _hb.update(phase="sent-extract")
                                        result["sent"] = extract_emails(page)
                                        result["sent_count"] = len(result["sent"])
                                        _hb.update(phase="sent-extract",
                                                   processed=result["sent_count"])
                                        page.screenshot(
                                            path=str(OUTPUT_DIR / f"{alias}-sent-screenshot.png"))
                                    else:
                                        result["sent_error"] = "session_expired_on_sent"
                                    page.goto(mail_url, wait_until="commit")
                                except Exception as exc:
                                    result["sent_error"] = str(exc)[:200]
                            _hb.terminal_done(extra=result)
                            result["_hb_terminal"] = "done"
                    except Exception as _exc:
                        _hb.terminal_error(str(_exc))
                        result["error"] = str(_exc)[:200]
                        result["_hb_terminal"] = "error"

                elif action == "check-calendar":
                    from calendar_72h import check_window as _cw
                    wdays = max(1, min(7, int(cmd.get("days", 3))))
                    _cal_path = OUTPUT_DIR / f"{alias}-calendar-result.json"
                    _cal_trace = OUTPUT_DIR / f"{alias}-calendar-trace.jsonl"
                    _hb = _HBWriter(_cal_path, alias, "check-calendar",
                                    trace_path=_cal_trace)
                    _hb.start()
                    try:
                        _cw_res = _cw(page, cal_url, extract_calendar,
                                      alias, OUTPUT_DIR, wdays, hb=_hb)
                        result.update(_cw_res)
                        if _cw_res.get("error") == "session_expired":
                            _hb.terminal_session_expired(extra=_cw_res)
                            result["_hb_terminal"] = "session_expired"
                        else:
                            _hb.terminal_done(extra=_cw_res)
                            result["_hb_terminal"] = "done"
                    except Exception as _exc:
                        _hb.terminal_error(str(_exc))
                        result["error"] = str(_exc)[:200]
                        result["_hb_terminal"] = "error"

                elif action == "check-teams":
                    target_chat = cmd.get("chat")
                    extra_wait = int(cmd.get("wait_ms", 15000))
                    _t_path = OUTPUT_DIR / f"{alias}-teams-result.json"
                    _t_trace = OUTPUT_DIR / f"{alias}-teams-trace.jsonl"
                    _hb = _HBWriter(_t_path, alias, "check-teams",
                                    trace_path=_t_trace)
                    _hb.start()
                    try:
                        _hb.update(phase="navigate")
                        page.goto(teams_url)
                        try:
                            page.wait_for_load_state("networkidle", timeout=30000)
                        except Exception:
                            pass
                        _hb.update(phase="wait-tree")
                        tree_selectors = (
                            '[data-tid="chat-list-item"], '
                            '[role="treeitem"], '
                            '[data-tid*="chatTreeItem"]'
                        )
                        try:
                            page.wait_for_selector(tree_selectors, timeout=45000)
                        except Exception:
                            pass
                        page.wait_for_timeout(extra_wait)
                        if "login" in page.url or "sso." in page.url:
                            result["error"] = "session_expired"
                            _hb.terminal_session_expired(extra=result)
                            result["_hb_terminal"] = "session_expired"
                        else:
                            _hb.update(phase="extract-list")
                            try:
                                result["chat_list"] = extract_teams_chat_list(page)
                                _hb.update(phase="extract-list",
                                           processed=len(result["chat_list"]))
                            except Exception as e:
                                result["chat_list"] = []
                                result["chat_list_error"] = str(e)
                            if target_chat:
                                _hb.update(phase="click-chat")
                                try:
                                    list_teams_items(page, expand=True)
                                    page.wait_for_timeout(1500)
                                except Exception:
                                    pass
                                try:
                                    click_kind = cmd.get("click_kind", "name")
                                    clicked = click_teams_chat(
                                        page, target_chat, kind=click_kind)
                                    result["chat_clicked"] = clicked
                                    if clicked:
                                        page.wait_for_timeout(4000)
                                except Exception as e:
                                    result["chat_click_error"] = str(e)
                            _hb.update(phase="extract-active")
                            try:
                                result["active_chat"] = extract_teams_active_chat(
                                    page, teams_extractor_js)
                            except Exception as e:
                                result["active_chat"] = None
                                result["active_chat_error"] = str(e)
                            teams_png = OUTPUT_DIR / f"{alias}-teams.png"
                            page.screenshot(path=str(teams_png))
                            _hb.terminal_done(extra=result)
                            result["_hb_terminal"] = "done"
                        try:
                            page.goto(mail_url, wait_until="commit")
                        except Exception:
                            pass
                    except Exception as _exc:
                        _hb.terminal_error(str(_exc))
                        result["error"] = str(_exc)[:200]
                        result["_hb_terminal"] = "error"

                elif action == "list-teams-items":
                    expand = bool(cmd.get("expand", True))
                    page.goto(teams_url)
                    try:
                        page.wait_for_load_state("networkidle", timeout=30000)
                    except Exception:
                        pass
                    tree_sel = (
                        '[data-tid="chat-list-item"], '
                        '[role="treeitem"], '
                        '[data-tid*="chatTreeItem"]'
                    )
                    try:
                        page.wait_for_selector(tree_sel, timeout=45000)
                    except Exception:
                        pass
                    page.wait_for_timeout(4000)
                    try:
                        inv = list_teams_items(page, expand=expand)
                        result["items"] = inv.get("items", [])
                        result["items_url"] = inv.get("url", "")
                    except Exception as e:
                        result["error"] = str(e)[:200]
                    try:
                        page.goto(mail_url, wait_until="commit")
                    except Exception:
                        pass

                elif action == "open-chat":
                    chat_id = cmd.get("chat_id")
                    extra = int(cmd.get("wait_ms", 9500))
                    if not chat_id:
                        result["error"] = "missing chat_id"
                    else:
                        res = open_chat_by_deep_link(page, chat_id, wait_millis=extra)
                        result.update(res)
                        if res.get("ok"):
                            try:
                                result["active_chat"] = extract_teams_active_chat(
                                    page, teams_extractor_js)
                            except Exception as e:
                                result["active_chat_error"] = str(e)[:200]
                        try:
                            page.goto(mail_url, wait_until="commit")
                        except Exception:
                            pass

                elif action == "stop":
                    browser.close(); p.stop(); return

                if action == "open-chat":
                    out_file = OUTPUT_DIR / f"{alias}-teams-result.json"
                elif action == "check-teams":
                    # SPEC-SH03: HeartbeatWriter wrote {alias}-teams-result.json.
                    out_file = None
                elif action == "list-teams-items":
                    out_file = OUTPUT_DIR / f"{alias}-teams-items.json"
                elif action == "check-calendar":
                    # SPEC-SH03: HeartbeatWriter already wrote the terminal
                    # payload atomically. Skip generic write to avoid races.
                    out_file = None
                elif action == "check-mail":
                    # SPEC-SH03: HeartbeatWriter wrote {alias}-mail-result.json.
                    out_file = None
                else:
                    out_file = OUTPUT_DIR / f"{alias}-result.json"
                if out_file is not None:
                    with open(out_file, "w", encoding="utf-8") as f:
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
