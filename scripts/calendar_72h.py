"""SPEC-R01: multi-day calendar window extractor.

Module API: `check_window` (used by browser-daemon.py).
CLI API:    `python calendar_72h.py [account|all] [--days N]` —
            sends `check-calendar` command to running daemon(s) and
            aggregates results. Falls back to error if daemon not running.
"""
import datetime as _dt


def check_window(page, cal_url, extractor, tenant_label, out_dir, span):
    """Navigate per-offset in range(span) and aggregate events."""
    result = {"events": [], "count": 0, "window_days": span}
    seen = set()
    base = _dt.date.today()
    for off in range(span):
        target = base + _dt.timedelta(days=off)
        ds = target.strftime("%Y-%m-%d")
        sep = "&" if "?" in cal_url else "?"
        day_url = cal_url + sep + "date=" + ds
        try:
            page.goto(day_url)
            page.wait_for_timeout(5000)
        except BaseException:
            continue
        if "login" in page.url:
            result["error"] = "session_expired"
            return result
        try:
            items = extractor(page)
        except BaseException:
            items = []
        for ev in items:
            k = (str(ev)[:80], ds)
            if k in seen:
                continue
            seen.add(k)
            result["events"].append({
                "event": ev, "day_offset": off, "day_date": ds,
            })
    result["count"] = len(result["events"])
    return result


def _cli_main():
    """CLI entry: queue check-calendar command on running daemons and aggregate."""
    import json
    import sys
    import time
    from pathlib import Path

    savia_dir = Path.home() / ".savia"
    output_dir = savia_dir / "outlook-inbox"
    commands_dir = savia_dir / "browser-commands"
    accounts_file = savia_dir / "mail-accounts.json"

    if not accounts_file.exists():
        print("[calendar] no accounts file at " + str(accounts_file), file=sys.stderr)
        sys.exit(1)
    with open(accounts_file, "r", encoding="utf-8") as f:
        accounts = json.load(f)

    target = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else "all"
    days = 3
    if "--days" in sys.argv:
        idx = sys.argv.index("--days")
        if idx + 1 < len(sys.argv):
            try:
                days = max(1, min(7, int(sys.argv[idx + 1])))
            except ValueError:
                pass

    aliases = list(accounts.keys()) if target == "all" else [target]
    commands_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)

    results = []
    for alias in aliases:
        if alias not in accounts:
            results.append({"account": alias, "error": "unknown_account"})
            continue

        # Verify daemon is running before queuing a command
        status_file = output_dir / (alias + "-status.json")
        daemon_running = False
        if status_file.exists():
            try:
                with open(status_file, "r", encoding="utf-8") as f:
                    st = json.load(f)
                daemon_running = st.get("status") == "running"
            except Exception:
                pass

        if not daemon_running:
            results.append({"account": alias, "error": "daemon_not_running"})
            continue

        cmd_file = commands_dir / (alias + "-cmd.json")
        # Calendar handler writes to a dedicated file to avoid the race against
        # parallel mail clients sharing {alias}-result.json.
        result_file = output_dir / (alias + "-calendar-result.json")
        if result_file.exists():
            try:
                result_file.unlink()
            except Exception:
                pass

        with open(cmd_file, "w", encoding="utf-8") as f:
            json.dump({"action": "check-calendar", "days": days}, f)

        got = None
        # Wait up to 240s — calendar scrape navigates per day; if a check-mail
        # (now also fetching sent items) is queued ahead, the wait can exceed
        # 90s on the first run.
        for _ in range(240):
            time.sleep(1)
            if result_file.exists():
                try:
                    with open(result_file, "r", encoding="utf-8") as fp:
                        got = json.load(fp)
                    break
                except Exception:
                    continue

        if got is None:
            results.append({"account": alias, "error": "daemon_timeout"})
        else:
            got.setdefault("account", alias)
            results.append(got)

    print(
        json.dumps(results, ensure_ascii=False, indent=2),
        file=open(1, "w", encoding="utf-8", closefd=False),
    )


if __name__ == "__main__":
    _cli_main()
