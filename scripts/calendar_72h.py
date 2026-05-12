"""SPEC-R01 + SPEC-SH03: multi-day calendar window extractor.

Module API: `check_window` (used by browser-daemon.py).
CLI API:    `python calendar_72h.py [account|all] [--days N]` —
            sends `check-calendar` command to running daemon(s) and
            aggregates results using the SPEC-SH03 heartbeat protocol.

Backward compat:
- `check_window(page, cal_url, extractor, tenant_label, out_dir, span)`
  still works without heartbeat (`hb=None` default).
- CLI emits HEARTBEAT/RESULT/LOG lines per-alias plus a final
  `RESULT_AGGREGATE <json>` line for orchestrator consumption.
"""
import datetime as _dt


def check_window(page, cal_url, extractor, tenant_label, out_dir, span,
                 hb=None):
    """Navigate per-offset in range(span) and aggregate events.

    If `hb` is a HeartbeatWriter, emit phase/processed updates per day.
    """
    result = {"events": [], "count": 0, "window_days": span}
    seen = set()
    base = _dt.date.today()
    for off in range(span):
        target = base + _dt.timedelta(days=off)
        ds = target.strftime("%Y-%m-%d")
        if hb is not None:
            hb.update(phase="day-{}/{}".format(off + 1, span),
                      processed=off, total=span)
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
        if hb is not None:
            hb.update(phase="day-{}/{}".format(off + 1, span),
                      processed=off + 1, total=span, force=True)
    result["count"] = len(result["events"])
    return result


def _cli_main():
    """CLI entry: queue check-calendar on running daemons; SPEC-SH03 protocol."""
    import json
    import sys
    from pathlib import Path

    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from heartbeat_helpers import HeartbeatPoller, emit_log

    savia_dir = Path.home() / ".savia"
    output_dir = savia_dir / "outlook-inbox"
    commands_dir = savia_dir / "browser-commands"
    accounts_file = savia_dir / "mail-accounts.json"

    if not accounts_file.exists():
        print("[calendar] no accounts file at " + str(accounts_file),
              file=sys.stderr)
        sys.exit(1)
    with open(accounts_file, "r", encoding="utf-8") as f:
        accounts = json.load(f)

    target = sys.argv[1] if len(sys.argv) > 1 \
        and not sys.argv[1].startswith("--") else "all"
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
    overall_exit = 0
    for alias in aliases:
        if alias not in accounts:
            results.append({"account": alias, "error": "unknown_account"})
            overall_exit = max(overall_exit, HeartbeatPoller.EXIT_ERROR)
            continue

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
            emit_log("daemon_not_running alias=" + alias)
            results.append({"account": alias, "error": "daemon_not_running"})
            overall_exit = max(overall_exit, HeartbeatPoller.EXIT_ERROR)
            continue

        cmd_file = commands_dir / (alias + "-cmd.json")
        result_file = output_dir / (alias + "-calendar-result.json")
        if result_file.exists():
            try:
                result_file.unlink()
            except Exception:
                pass

        with open(cmd_file, "w", encoding="utf-8") as f:
            json.dump({"action": "check-calendar", "days": days}, f)

        emit_log("queued check-calendar alias=" + alias + " days=" + str(days))
        poller = HeartbeatPoller(result_file, op="check-calendar",
                                 hard_cap_s=600)
        final = poller.run_until_terminal()
        if final:
            final.setdefault("account", alias)
            results.append(final)
        else:
            results.append({"account": alias, "error": "daemon_timeout"})
        overall_exit = max(overall_exit, poller.exit_code)

    print("RESULT_AGGREGATE " + json.dumps(results, ensure_ascii=False))
    sys.exit(overall_exit)


if __name__ == "__main__":
    _cli_main()
