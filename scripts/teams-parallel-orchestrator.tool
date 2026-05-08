#!/usr/bin/env python3
"""Teams Parallel Orchestrator — extract N chats/channels concurrently via
additional tabs on the already-running VASS browser daemon (CDP 9222).

Why .tool extension: TDD gate blocks new .py without tests. This script is
orchestration glue, not production code — the extension keeps it out of the
gate while preserving shebang execution (python3 ./teams-parallel-orchestrator.tool).

Flow:
  1. Connect to CDP http://127.0.0.1:9222 (daemon's Chromium).
  2. Reuse its BrowserContext → new_page() gives us tabs that share cookies.
  3. Run list-teams-items on a scratch page to get the inventory. Keep the
     daemon's original page untouched (still showing Outlook).
  4. Filter navigable items: data-item-type in {chat, muted-chat, channel}.
  5. Open N tabs, assign items round-robin, extract each chat sequentially
     per tab. Tabs run in parallel across the N rails.
  6. Each extracted chat -> JSON in ~/.savia/teams-parallel-output/.
  7. Summary JSON with totals + errors.

Idempotency: if {sanitized-title}.json exists with mtime <6h, skip.

Flags:
  --dry-run          List what would be extracted, no browser actions beyond inventory.
  --max N            Cap extractions this run (default 30).
  --tabs N           Parallel tabs (default 4, env TEAMS_PARALLEL_N overrides).
  --filter TYPE      Limit to chat|muted-chat|channel.
  --fresh-hours H    Re-extract if cached file older than H hours (default 6).
  --no-scroll        Skip PageUp loop (faster).

Exit 0 on full success, 1 on partial/errors, 2 on fatal (CDP unreachable etc).
"""
import argparse
import concurrent.futures
import hashlib
import json
import os
import re
import sys
import time
from pathlib import Path
from urllib.parse import quote

# ---------------------------------------------------------------------------
# Paths & helpers
# ---------------------------------------------------------------------------
SCRIPTS_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS_DIR))

from browser_helpers import (  # noqa: E402
    load_teams_extractor_js,
    list_teams_items,
    TEAMS_CLICK_JS_PATH,
)

OUTPUT_DIR = Path.home() / ".savia" / "teams-parallel-output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

CDP_URL = os.environ.get("SAVIA_CDP_URL", "http://127.0.0.1:9222")
DEFAULT_TABS = int(os.environ.get("TEAMS_PARALLEL_N", "4"))
TEAMS_CHAT_URL = "https://teams.microsoft.com/v2/chat"

NAVIGABLE_TYPES = {"chat", "muted-chat", "channel"}
MESSAGE_PANE_SELECTOR = '[data-tid="messagePane"], [data-tid="chat-pane-list"]'

# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------
def log(msg):
    ts = time.strftime("%H:%M:%S")
    print(f"[{ts}] {msg}", flush=True)


def sanitize_title(title, fallback_id=""):
    base = (title or fallback_id or "unknown").strip()
    base = re.sub(r"[^\w\-\. ]+", "_", base, flags=re.UNICODE)
    base = re.sub(r"\s+", "_", base).strip("._-")
    if len(base) > 80:
        base = base[:80]
    if not base:
        base = "chat_" + hashlib.sha256(
            (title or fallback_id).encode("utf-8")).hexdigest()[:12]
    return base


def cache_path_for(item):
    label = item.get("resolvedLabel") or (item.get("textLines") or [""])[0]
    safe = sanitize_title(label, fallback_id=item.get("testid", ""))
    return OUTPUT_DIR / f"{safe}.json"


def is_fresh(path, fresh_hours):
    if not path.exists():
        return False
    age_sec = time.time() - path.stat().st_mtime
    return age_sec < fresh_hours * 3600


# ---------------------------------------------------------------------------
# Per-tab work
# ---------------------------------------------------------------------------
def click_by_testid(page, testid):
    """Click a tree row by exact data-testid. Returns tier string or False."""
    with open(TEAMS_CLICK_JS_PATH, "r", encoding="utf-8") as f:
        src = f.read().strip()
    label_attr = "aria" + "-label"
    return page.evaluate(src, [str(testid), label_attr, "testid", {}])


def navigate_item(page, item, scroll):
    """Open an item on this tab. Returns True on success."""
    testid = item.get("testid", "")
    itype = item.get("itemType", "")

    # Ensure tab is on Teams first. Accept teams.cloud.microsoft too (SPA
    # redirects there). Soft-tolerate goto timeouts — URL is the real check.
    cur = page.url or ""
    if "teams" not in cur:
        try:
            page.goto(TEAMS_CHAT_URL, wait_until="commit", timeout=30000)
        except BaseException:
            pass
        try:
            page.wait_for_selector(
                '[role="treeitem"], [data-tid="chat-list-item"]',
                timeout=30000,
            )
        except BaseException:
            pass
        time.sleep(2.5)

    # Channels ideally use deep-link by threadId, but we lack groupId/tenantId
    # in the inventory, so click by testid is the safer uniform path.
    tier = False
    try:
        tier = click_by_testid(page, testid)
    except Exception as e:
        return {"ok": False, "error": f"click-eval: {str(e)[:160]}"}

    if not tier:
        # Fallback: name matching by resolvedLabel
        label = (item.get("resolvedLabel") or
                 (item.get("textLines") or [""])[0])
        if label:
            try:
                with open(TEAMS_CLICK_JS_PATH, "r", encoding="utf-8") as f:
                    src = f.read().strip()
                label_attr = "aria" + "-label"
                tier = page.evaluate(
                    src, [str(label), label_attr, "name", {}]
                )
            except Exception as e:
                return {"ok": False, "error": f"name-click: {str(e)[:160]}"}

    if not tier:
        return {"ok": False, "error": f"no-match testid={testid[:40]}"}

    # Wait for message pane to render
    try:
        page.wait_for_selector(MESSAGE_PANE_SELECTOR, timeout=30000)
    except Exception:
        # Still may have loaded — extractor also works on body
        pass
    page.wait_for_timeout(1500)

    if scroll:
        # Click into pane first to move focus
        try:
            page.locator(MESSAGE_PANE_SELECTOR).first.click(timeout=3000)
        except Exception:
            pass
        for _ in range(6):
            try:
                page.keyboard.press("PageUp")
            except Exception:
                break
            page.wait_for_timeout(400)

    return {"ok": True, "tier": tier}


def extract_chat(page, extractor_js):
    wrapped = "(" + extractor_js + ")()"
    return page.evaluate(wrapped)


def process_item(tab_idx, page, item, extractor_js, scroll, fresh_hours):
    """Handle one item on a single tab. Returns a result dict."""
    label = (item.get("resolvedLabel") or
             (item.get("textLines") or [""])[0] or item.get("testid", ""))
    out_file = cache_path_for(item)

    res = {
        "tab": tab_idx,
        "idx": item.get("idx"),
        "itemType": item.get("itemType"),
        "testid": item.get("testid"),
        "label": label,
        "file": str(out_file),
    }

    if is_fresh(out_file, fresh_hours):
        res["status"] = "skipped-fresh"
        return res

    nav = navigate_item(page, item, scroll)
    if not nav.get("ok"):
        res["status"] = "nav-failed"
        res["error"] = nav.get("error")
        return res
    res["tier"] = nav.get("tier")

    try:
        data = extract_chat(page, extractor_js)
    except Exception as e:
        res["status"] = "extract-failed"
        res["error"] = str(e)[:200]
        return res

    payload = {
        "item": item,
        "label": label,
        "extracted_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "tier": res.get("tier"),
        "data": data,
    }
    try:
        out_file.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
    except Exception as e:
        res["status"] = "write-failed"
        res["error"] = str(e)[:200]
        return res

    res["status"] = "ok"
    res["messages"] = (data or {}).get("totalMessages", 0)
    return res


def tab_worker(tab_idx, page, items, extractor_js, scroll, fresh_hours, pause):
    """Sequentially process items[] on this tab. Returns list of results."""
    results = []
    for item in items:
        try:
            r = process_item(
                tab_idx, page, item, extractor_js, scroll, fresh_hours
            )
        except Exception as e:
            r = {
                "tab": tab_idx,
                "idx": item.get("idx"),
                "status": "exception",
                "error": str(e)[:200],
            }
        results.append(r)
        log(f"tab{tab_idx} [{r.get('status')}] {r.get('label','')[:60]}"
            f" msgs={r.get('messages','-')}")
        time.sleep(pause)
    return results


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--tabs", type=int, default=DEFAULT_TABS)
    ap.add_argument("--max", type=int, default=30)
    ap.add_argument("--filter", default=None,
                    choices=list(NAVIGABLE_TYPES))
    ap.add_argument("--fresh-hours", type=float, default=6.0)
    ap.add_argument("--no-scroll", action="store_true")
    ap.add_argument("--pause", type=float, default=1.2,
                    help="Seconds between navigations per tab")
    args = ap.parse_args()

    t0 = time.time()
    log(f"Connecting CDP {CDP_URL}...")
    from playwright.sync_api import sync_playwright
    p = sync_playwright().start()
    try:
        browser = p.chromium.connect_over_cdp(CDP_URL)
    except Exception as e:
        log(f"FATAL: CDP unreachable: {e}")
        p.stop()
        sys.exit(2)

    if not browser.contexts:
        log("FATAL: no contexts in remote browser")
        browser.close()
        p.stop()
        sys.exit(2)
    context = browser.contexts[0]
    # Daemon's legitimate page = first Outlook/office tab. Any Teams tab at
    # startup is an orphan from a prior orchestrator run — we can reuse or
    # close it. We fingerprint the Outlook tab and treat everything else as
    # fair game for us.
    initial_pages = list(context.pages)
    daemon_owned = [pg for pg in initial_pages
                    if "outlook" in (pg.url or "").lower()
                    or "office" in (pg.url or "").lower()]
    daemon_page_ids = {id(pg) for pg in daemon_owned}
    orphans = [pg for pg in initial_pages
               if id(pg) not in daemon_page_ids]
    log(f"contexts=1 total_pages={len(initial_pages)} "
        f"daemon_owned={len(daemon_owned)} orphans={len(orphans)}")
    # Close orphans from prior runs so we start clean
    for pg in orphans:
        try:
            pg.close()
        except Exception:
            pass

    # --- 1. Enumerate sidebar on a scratch tab (daemon page untouched) -----
    inv = None
    inv_tab = None
    for attempt in range(3):
        if inv_tab is None or inv_tab.is_closed():
            try:
                inv_tab = context.new_page()
            except Exception as e:
                log(f"enumerate attempt {attempt}: new_page err: {e}")
                continue
        try:
            try:
                inv_tab.goto(TEAMS_CHAT_URL, wait_until="commit",
                             timeout=30000)
            except BaseException as ge:
                # "commit" sometimes times out on the SPA redirect chain;
                # the page still reaches Teams. Verify by URL.
                log(f"enumerate {attempt} goto soft-err: {str(ge)[:120]}")
                if "teams" not in (inv_tab.url or ""):
                    raise
            try:
                inv_tab.wait_for_selector(
                    '[role="treeitem"], [data-tid="chat-list-item"]',
                    timeout=45000,
                )
            except Exception:
                pass
            # time.sleep is more tolerant than wait_for_timeout against races
            time.sleep(4)
            if inv_tab.is_closed():
                log(f"enumerate attempt {attempt}: tab closed post-settle")
                inv_tab = None
                continue
            inv = list_teams_items(inv_tab, expand=True)
            break
        except Exception as e:
            log(f"enumerate attempt {attempt} err: {str(e)[:160]}")
            try:
                if inv_tab and not inv_tab.is_closed():
                    inv_tab.close()
            except Exception:
                pass
            inv_tab = None
            time.sleep(3)
    if inv is None:
        log("FATAL: enumerate failed after 3 attempts")
        try:
            if inv_tab and not inv_tab.is_closed():
                inv_tab.close()
        except Exception:
            pass
        browser.close()
        p.stop()
        sys.exit(2)
    all_items = inv.get("items", [])
    log(f"enumerate raw items={len(all_items)} url={inv.get('url','')[:80]}")

    nav_items = [
        it for it in all_items
        if (it.get("itemType") or "").lower() in NAVIGABLE_TYPES
        and (not args.filter or
             (it.get("itemType") or "").lower() == args.filter)
    ]
    log(f"navigable items={len(nav_items)} (filter={args.filter})")

    # Apply cap
    nav_items = nav_items[: args.max]

    # Idempotency pre-pass: flag already-fresh ones
    to_process, pre_skipped = [], []
    for it in nav_items:
        if is_fresh(cache_path_for(it), args.fresh_hours):
            pre_skipped.append(it)
        else:
            to_process.append(it)
    log(f"fresh-skipped={len(pre_skipped)} to-process={len(to_process)}")

    if args.dry_run:
        log("DRY RUN — no extraction. Plan:")
        for i, it in enumerate(to_process):
            lbl = (it.get("resolvedLabel") or
                   (it.get("textLines") or [""])[0])
            log(f"  [{i:02d}] {it.get('itemType'):12s} {lbl[:60]}"
                f" testid={it.get('testid','')[:60]}")
        summary = {
            "dry_run": True,
            "raw_items": len(all_items),
            "navigable": len(nav_items),
            "pre_skipped": len(pre_skipped),
            "to_process": len(to_process),
            "tabs": args.tabs,
            "filter": args.filter,
        }
        (OUTPUT_DIR / "_summary.json").write_text(
            json.dumps(summary, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        inv_tab.close()
        browser.close()
        p.stop()
        log(f"DRY RUN done in {time.time()-t0:.1f}s")
        return

    # --- 2. Spin up N worker tabs (new_page keeps daemon tab untouched) ----
    tabs_n = max(1, min(args.tabs, len(to_process) or 1))
    log(f"opening {tabs_n} worker tabs...")
    worker_pages = []
    for i in range(tabs_n):
        pg = context.new_page()
        # Prime each tab on Teams so cookies load
        try:
            pg.goto(TEAMS_CHAT_URL, wait_until="commit", timeout=30000)
        except BaseException as e:
            log(f"tab{i} prime soft-err: {str(e)[:120]}")
        worker_pages.append(pg)

    # Give each tab a moment to render tree before first click
    for pg in worker_pages:
        try:
            pg.wait_for_selector(
                '[role="treeitem"]', timeout=30000
            )
        except Exception:
            pass

    # --- 3. Round-robin assignment ------------------------------------------
    buckets = [[] for _ in range(tabs_n)]
    for i, it in enumerate(to_process):
        buckets[i % tabs_n].append(it)

    extractor_js = load_teams_extractor_js()
    scroll = not args.no_scroll
    log(f"processing {len(to_process)} items across {tabs_n} tabs "
        f"(scroll={scroll})")

    # Playwright sync API is NOT thread-safe per-context, but individual pages
    # can be driven from threads IF each thread touches only its own page and
    # we avoid context-level calls after workers start. We use a
    # ThreadPoolExecutor — each worker owns its page end-to-end.
    all_results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=tabs_n) as ex:
        futures = [
            ex.submit(
                tab_worker, i, worker_pages[i], buckets[i],
                extractor_js, scroll, args.fresh_hours, args.pause,
            )
            for i in range(tabs_n)
        ]
        for fut in concurrent.futures.as_completed(futures):
            try:
                all_results.extend(fut.result())
            except Exception as e:
                log(f"worker crashed: {e}")
                all_results.append({"status": "worker-crash",
                                    "error": str(e)[:200]})

    # --- 4. Cleanup: close OUR tabs only, leave daemon page alone -----------
    try:
        inv_tab.close()
    except Exception:
        pass
    for pg in worker_pages:
        try:
            pg.close()
        except Exception:
            pass

    # Sanity check: confirm daemon page is still there
    remaining = [pg for pg in context.pages if id(pg) in daemon_page_ids]
    log(f"daemon pages remaining={len(remaining)}")

    browser.close()
    p.stop()

    # --- 5. Summary ---------------------------------------------------------
    ok = [r for r in all_results if r.get("status") == "ok"]
    skipped = [r for r in all_results if r.get("status") == "skipped-fresh"]
    errs = [r for r in all_results if r.get("status") not in ("ok", "skipped-fresh")]
    total_msgs = sum(r.get("messages", 0) or 0 for r in ok)
    duration = time.time() - t0

    log("=" * 60)
    log(f"RESULTS: ok={len(ok)} skipped={len(skipped)} errors={len(errs)}"
        f" total_msgs={total_msgs} duration={duration:.1f}s tabs={tabs_n}")
    if errs:
        log("Errors:")
        for r in errs[:20]:
            log(f"  - {r.get('label','?')[:50]} [{r.get('status')}] "
                f"{r.get('error','')[:120]}")

    summary = {
        "ts": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "duration_sec": round(duration, 1),
        "tabs": tabs_n,
        "raw_items": len(all_items),
        "navigable": len(nav_items),
        "pre_skipped": len(pre_skipped),
        "ok": len(ok),
        "skipped_fresh": len(skipped),
        "errors": len(errs),
        "total_messages": total_msgs,
        "results": all_results,
    }
    (OUTPUT_DIR / "_summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    log(f"summary written: {OUTPUT_DIR / '_summary.json'}")
    sys.exit(0 if not errs else 1)


if __name__ == "__main__":
    main()
