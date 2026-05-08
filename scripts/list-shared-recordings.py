#!/usr/bin/env python3
"""Lista grabaciones compartidas via sesion persistida — multi-source.

Recorre OneDrive Shared, SharePoint, Stream y extrae items mp4/transcript.
Output JSON con href + texto + fecha.

Uso: python3 list-shared-recordings.py <alias> [--tenant <tenant>]
"""
import argparse, json, os, sys, time
from pathlib import Path
os.environ["PYTHONUTF8"] = "1"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from browser_helpers import SIGNAL, load_account


def try_urls(tenant):
    return [
        f"https://{tenant}/_layouts/15/onedrive.aspx?view=1&sortField=SharedOn&sortOrder=desc",
        f"https://{tenant}/_layouts/15/sharedwithyou.aspx",
        f"https://{tenant}/_layouts/15/stream.aspx?app=stream",
        "https://www.microsoft365.com/launch/stream?auth=2",
        "https://www.office.com/launch/onedrive?auth=2&home=1",
    ]


def extract_items(page):
    return page.evaluate(
        "() => {"
        " const out = []; const seen = new Set();"
        " const scan = el => {"
        "   const a = el.tagName === 'A' ? el : (el.querySelector ? el.querySelector('a') : null);"
        "   if (!a) return;"
        "   const href = a.href || ''; if (!href) return;"
        "   const low = href.toLowerCase();"
        "   const isTarget = low.includes('.mp4')"
        "     || low.includes('stream.aspx')"
        "     || low.includes('/recording')"
        "     || low.includes('transcrip')"
        "     || (low.includes('sharepoint.com') && low.includes('/personal/'));"
        "   if (!isTarget) return; if (seen.has(href)) return; seen.add(href);"
        "   const txt = (el.innerText || a.innerText || (el.getAttribute && el.getAttribute('aria-label')) || '').trim();"
        "   out.push({href, text: txt.substring(0, 300)});"
        " };"
        " document.querySelectorAll('a').forEach(scan);"
        " document.querySelectorAll('[role=\"row\"], [role=\"listitem\"], [data-automationid]').forEach(scan);"
        " return out;"
        "}"
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("alias")
    ap.add_argument("--tenant", default="grupovass-my.sharepoint.com")
    args = ap.parse_args()
    from playwright.sync_api import sync_playwright
    cfg = load_account(args.alias)
    session_dir = str(SIGNAL.parent / cfg["session_dir"])
    out_dir = Path.home() / ".savia" / "captured-vtt"
    out_dir.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    out_file = out_dir / ("shared-recordings-" + args.alias + "-" + stamp + ".json")
    p = sync_playwright().start()
    b = p.chromium.launch_persistent_context(
        session_dir, headless=False,
        args=["--window-position=-2000,-2000", "--window-size=1400,900"],
        viewport={"width": 1400, "height": 900}, timeout=0,
    )
    pg = b.pages[0] if b.pages else b.new_page()
    all_items = []
    for url in try_urls(args.tenant):
        print("[nav]", url)
        try:
            pg.goto(url, wait_until="commit", timeout=30000)
            pg.wait_for_timeout(9000)
            cur = pg.url.lower()
            if "login" in cur or "sso." in cur:
                print("  [skip] login redirect")
                continue
            for _ in range(5):
                pg.evaluate("window.scrollBy(0, 700)")
                pg.wait_for_timeout(900)
            items = extract_items(pg)
            print("  [items]", len(items))
            for it in items:
                if not any(x["href"] == it["href"] for x in all_items):
                    it_copy = dict(it); it_copy["source_url"] = url
                    all_items.append(it_copy)
        except Exception as e:
            print("  [err]", e)
    payload = {
        "alias": args.alias,
        "scanned_at": stamp,
        "count": len(all_items),
        "items": all_items,
    }
    out_file.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print("[ok]", len(all_items), "->", str(out_file))
    b.close(); p.stop()


if __name__ == "__main__":
    main()
