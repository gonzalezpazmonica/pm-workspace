"""project-update.py — Deterministic orchestrator for /project-update.

Replaces agent-per-source pattern with pure multiprocessing.

Reads config from:
  - ~/.savia/mail-accounts.json    (per-account: tenant, drive, paths)
  - ~/.azure/projects/<file>.json  (per-project: org, project, iteration)

Phases:
  F0  Auth gate (ensure-daemons-auth.sh)
  F1  Refresh — parallel subprocesses per (source x account):
        devops-scan (slug)            single
        mail (account)                x N accounts
        calendar (account)            x N accounts
        teams-chats (account)         x N accounts
        sp-recordings list (acct)     x N accounts
        onedrive recent (acct)        x N accounts
        teams-transcripts (acct)      x N accounts (slowest; opt-in)
  F2  Digest — depends on F1 output (VTTs found):
        meetings_auto_digest          (VTT folder -> MD digests)

Confidentiality:
  Real names live only in ~/.savia/, ~/.azure/, projects/{slug}_main/.
  This script's stdout summary uses codenames (slug) only.
  Per-source outputs go to ~/.savia/project-update-tmp/<slug>/.

Usage:
  python project-update.py --slug "Project Aurora"
  python project-update.py --slug "Project Aurora" --skip teams-transcripts
  python project-update.py --slug "Project Aurora" --only refresh
  python project-update.py --slug "Project Aurora" --dry-run
"""
import argparse
import concurrent.futures as cf
import json
import os
import shlex
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

REPO_SCRIPTS = Path.home() / "savia" / "scripts"
SAVIA = Path.home() / ".savia"
TMP_BASE = SAVIA / "project-update-tmp"
ACCOUNTS_CFG = SAVIA / "mail-accounts.json"
PROJECTS_CFG_DIR = Path.home() / ".azure" / "projects"


def load_accounts():
    if not ACCOUNTS_CFG.exists():
        sys.exit("FATAL: " + str(ACCOUNTS_CFG) + " missing")
    return json.load(open(ACCOUNTS_CFG, encoding="utf-8"))


def resolve_project(slug):
    """Find project config file matching codename. Auto-pick if exactly one file."""
    if not PROJECTS_CFG_DIR.exists():
        sys.exit("FATAL: " + str(PROJECTS_CFG_DIR) + " missing")
    files = sorted(PROJECTS_CFG_DIR.glob("*.json"))
    if len(files) == 0:
        sys.exit("FATAL: no project configs in " + str(PROJECTS_CFG_DIR))
    if len(files) == 1:
        return files[0]
    matches = []
    for jf in files:
        try:
            d = json.load(open(jf, encoding="utf-8"))
        except Exception:
            continue
        if d.get("_codename") == slug:
            matches.append(jf)
    if len(matches) != 1:
        sys.exit("FATAL: cannot resolve slug=" + repr(slug)
                 + " (found " + str(len(matches)) + " in " + str(PROJECTS_CFG_DIR) + ")")
    return matches[0]


# Sources that REQUIRE a live browser-daemon (CDP). Saved-session sources
# (mail, calendar, teams-chats) try anyway because cookies may still be fresh.
CDP_DEPENDENT_SOURCES = {"sp-recordings", "onedrive", "teams-transcripts"}


def build_jobs(slug, accounts, project_cfg_path, opts):
    """Return list of (label, argv, timeout) for parallel execution.

    Per-source granular degrade: jobs in CDP_DEPENDENT_SOURCES are skipped
    when their account is in opts['account_skip']; other jobs (saved-session)
    are attempted because session cookies may still be valid.
    """
    jobs = []
    account_skip = opts.get("account_skip") or set()

    if "devops" not in opts["skip"]:
        jobs.append((
            "devops",
            ["bash", str(REPO_SCRIPTS / "project-update-devops.sh"), str(project_cfg_path)],
            240,
        ))

    def _skip(source, acct):
        return source in opts["skip"] or (
            source in CDP_DEPENDENT_SOURCES and acct in account_skip
        )

    for acct, cfg in accounts.items():
        port = cfg.get("cdp_port") or {"account1": 9222, "account2": 9223}.get(acct)
        if not port:
            continue

        if not _skip("mail", acct):
            jobs.append((
                "mail-" + acct,
                ["python3", str(REPO_SCRIPTS / "inbox-check.py"), acct],
                90,
            ))
        if not _skip("calendar", acct):
            jobs.append((
                "calendar-" + acct,
                ["python3", str(REPO_SCRIPTS / "calendar_72h.py"), acct, "--days", "3"],
                90,
            ))
        if not _skip("teams-chats", acct):
            jobs.append((
                "teams-chats-" + acct,
                ["python3", str(REPO_SCRIPTS / "teams-check.py"), acct],
                90,
            ))
        if not _skip("sp-recordings", acct):
            jobs.append((
                "sp-recordings-" + acct,
                ["python3", str(REPO_SCRIPTS / "sp-recordings.py"),
                 "--account", acct, "--action", "list", "--since-days", "30"],
                120,
            ))
        if not _skip("onedrive", acct):
            jobs.append((
                "onedrive-" + acct,
                ["python3", str(REPO_SCRIPTS / "onedrive_recent.py"),
                 "--account", acct, "--days", "14"],
                120,
            ))
        if not _skip("teams-transcripts", acct):
            out = TMP_BASE / slug / "teams-transcripts" / acct
            out.mkdir(parents=True, exist_ok=True)
            jobs.append((
                "teams-transcripts-" + acct,
                ["python3", str(REPO_SCRIPTS / "extract-teams-transcripts.py"),
                 "--port", str(port), "--out-dir", str(out), "--batch"],
                900,
            ))

    return jobs


def probe_auth_per_account():
    """Return (set_of_failed, raw_dict) by parsing check-daemon-auth.sh JSON."""
    bad = set()
    raw = {}
    try:
        proc = subprocess.run(
            ["bash", str(REPO_SCRIPTS / "check-daemon-auth.sh")],
            capture_output=True, text=True, timeout=30,
        )
        raw = json.loads(proc.stdout) if proc.stdout.strip() else {}
        for acct, info in (raw.get("accounts") or {}).items():
            if info.get("status") != "running":
                bad.add(acct)
    except Exception:
        return ({"_probe_failed"}, {})
    return (bad, raw)


def run_one(spec):
    label, argv, timeout = spec
    start = time.time()
    try:
        proc = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
        return {
            "label": label,
            "rc": proc.returncode,
            "elapsed_s": round(time.time() - start, 1),
            "stderr_tail": (proc.stderr or "").strip().split("\n")[-3:],
            "stdout_preview": (proc.stdout or "").strip()[:300],
        }
    except subprocess.TimeoutExpired:
        return {"label": label, "rc": -1, "error": "timeout " + str(timeout) + "s",
                "elapsed_s": timeout}
    except Exception as err:
        return {"label": label, "rc": -2, "error": str(err)[:200],
                "elapsed_s": round(time.time() - start, 1)}


def phase_refresh(jobs, opts):
    print("[F1] refresh - " + str(len(jobs)) + " jobs (workers="
          + str(opts["workers"]) + ")", file=sys.stderr)
    results = []
    with cf.ThreadPoolExecutor(max_workers=opts["workers"]) as pool:
        for r in pool.map(run_one, jobs):
            tag = "OK" if r.get("rc") == 0 else ("FAIL[" + str(r.get("rc")) + "]")
            print("  [" + tag + "] " + r["label"] + " - "
                  + str(r.get("elapsed_s", "?")) + "s", file=sys.stderr)
            results.append(r)
    return results


def phase_digest(slug):
    """F2 - digest VTTs into MD via meetings_auto_digest. Sequential."""
    print("[F2] digest - meetings_auto_digest", file=sys.stderr)
    sys.path.insert(0, str(REPO_SCRIPTS))
    import savia_paths
    target = str(savia_paths.project_paths(slug)["meetings"])
    cmd = ["python3", str(REPO_SCRIPTS / "meetings_auto_digest.py"),
           "--target-dir", target]
    return [run_one(("meetings-digest", cmd, 600))]


def phase_analyze(slug):
    """F3 - deterministic consolidator: read F1+F2 outputs, write radar.md."""
    print("[F3] analyze - project-update-analyze", file=sys.stderr)
    cmd = ["python3", str(REPO_SCRIPTS / "project-update-analyze.py"),
           "--slug", slug]
    return [run_one(("radar-consolidate", cmd, 120))]


def phase_sync(slug):
    """F4 - deterministic PENDING.md updater: read latest radar, append new items."""
    print("[F4] sync - project-update-sync", file=sys.stderr)
    cmd = ["python3", str(REPO_SCRIPTS / "project-update-sync.py"),
           "--slug", slug]
    return [run_one(("pending-sync", cmd, 60))]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--slug", required=True,
                    help="Project codename (e.g. 'Project Aurora')")
    ap.add_argument("--only", choices=["refresh", "digest", "analyze", "sync"], default=None)
    ap.add_argument("--skip", action="append", default=[],
                    help="Skip a source: devops mail calendar teams-chats sp-recordings onedrive teams-transcripts")
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--skip-auth", action="store_true",
                    help="Skip F0 auth gate (assume daemons up)")
    args = ap.parse_args()

    slug = args.slug
    opts = {"skip": set(args.skip), "workers": args.workers,
            "dry_run": args.dry_run, "skip_auth": args.skip_auth}

    bad_accounts = set()
    auth_raw = {}
    if args.dry_run or opts["skip_auth"]:
        print("[F0] auth gate skipped", file=sys.stderr)
    else:
        print("[F0] auth gate (graceful)", file=sys.stderr)
        try:
            proc = subprocess.run(["bash", str(REPO_SCRIPTS / "ensure-daemons-auth.sh")],
                                  capture_output=True, text=True, timeout=60)
            _ = proc.returncode
        except subprocess.TimeoutExpired:
            pass
        bad_accounts, auth_raw = probe_auth_per_account()
        if bad_accounts:
            print("[F0] degraded: skipping " + ",".join(sorted(bad_accounts))
                  + " (auth not running) - devops + healthy accounts continue",
                  file=sys.stderr)
        opts["account_skip"] = bad_accounts

    accounts = load_accounts()
    project_cfg = resolve_project(slug)
    print("[orch] slug=" + slug + " accounts=" + str(list(accounts.keys()))
          + " project_cfg=" + project_cfg.name, file=sys.stderr)

    tmp_dir = TMP_BASE / slug
    tmp_dir.mkdir(parents=True, exist_ok=True)

    summary = {
        "slug": slug,
        "started_at": datetime.now(timezone.utc).isoformat(),
        "accounts": list(accounts.keys()),
        "skipped_accounts": sorted(opts.get("account_skip") or []),
        "auth_status": auth_raw if not args.dry_run and not opts["skip_auth"] else None,
        "project_cfg": project_cfg.name,
        "phases": {},
    }

    if args.only in (None, "refresh"):
        jobs = build_jobs(slug, accounts, project_cfg, opts)
        if args.dry_run:
            print("[dry-run] would launch " + str(len(jobs)) + " jobs:",
                  file=sys.stderr)
            for j in jobs:
                print("  " + j[0] + ": "
                      + " ".join(shlex.quote(x) for x in j[1])[:120],
                      file=sys.stderr)
            return
        summary["phases"]["F1"] = phase_refresh(jobs, opts)

    if args.only in (None, "digest"):
        if not args.dry_run:
            summary["phases"]["F2"] = phase_digest(slug)

    if args.only in (None, "analyze") and not args.dry_run:
        summary["phases"]["F3"] = phase_analyze(slug)

    if args.only in (None, "sync") and not args.dry_run:
        summary["phases"]["F4"] = phase_sync(slug)

    summary["finished_at"] = datetime.now(timezone.utc).isoformat()
    summary_path = tmp_dir / ("orchestrator-"
                              + datetime.now().strftime("%Y%m%d-%H%M") + ".json")
    summary_path.write_text(
        json.dumps(summary, ensure_ascii=False, indent=2),
        encoding="utf-8")

    n_ok = sum(1 for r in summary["phases"].get("F1", []) if r.get("rc") == 0)
    n_total = len(summary["phases"].get("F1", []))
    digest_ok = sum(1 for r in summary["phases"].get("F2", [])
                    if r.get("rc") == 0)
    digest_total = len(summary["phases"].get("F2", []))
    analyze_ok = sum(1 for r in summary["phases"].get("F3", [])
                     if r.get("rc") == 0)
    analyze_total = len(summary["phases"].get("F3", []))
    sync_ok = sum(1 for r in summary["phases"].get("F4", [])
                  if r.get("rc") == 0)
    sync_total = len(summary["phases"].get("F4", []))
    print(json.dumps({
        "slug": slug,
        "F1_ok": str(n_ok) + "/" + str(n_total),
        "F2_ok": str(digest_ok) + "/" + str(digest_total),
        "F3_ok": str(analyze_ok) + "/" + str(analyze_total),
        "F4_ok": str(sync_ok) + "/" + str(sync_total),
        "summary": str(summary_path),
    }))


if __name__ == "__main__":
    main()
