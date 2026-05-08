#!/usr/bin/env python3
"""Lista .mp4 dentro de una carpeta SharePoint usando sesion persistida.

Uso: python3 list-folder-mp4.py <alias> <folder_url>
"""
import argparse, json, os, sys, time
from pathlib import Path
os.environ["PYTHONUTF8"] = "1"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from browser_helpers import SIGNAL, load_account


def extract_mp4(page):
    return page.evaluate(
        "() => {"
        " const out = []; const seen = new Set();"
        " document.querySelectorAll('a, [role=\"row\"]').forEach(el => {"
        "   const a = el.tagName === 'A' ? el : (el.querySelector ? el.querySelector('a') : null);"
        "   if (!a) return;"
        "   const href = a.href || ''; if (!href) return;"
        "   const low = href.toLowerCase();"
        "   if (!low.includes('.mp4') && !(low.includes('stream.aspx') && low.includes('id='))) return;"
        "   if (seen.has(href)) return; seen.add(href);"
        "   const txt = (el.innerText || a.innerText || '').trim();"
        "   out.push({href, text: txt.substring(0, 250)});"
        " });"
        " return out;"
        "}"
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("alias")
    ap.add_argument("folders", nargs='+')
    args = ap.parse_args()
    from playwright.sync_api import sync_playwright
    cfg = load_account(args.alias)
    session_dir = str(SIGNAL.parent / cfg["session_dir"])
    out_dir = Path.home() / ".savia" / "captured-vtt"
    out_dir.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    out_file = out_dir / ("folder-mp4-" + args.alias + "-" + stamp + ".json")
    p = sync_playwright().start()
    b = p.chromium.launch_persistent_context(
        session_dir, headless=False,
        args=["--window-position=-2000,-2000", "--window-size=1400,900"],
        viewport={"width": 1400, "height": 900}, timeout=0,
    )
    pg = b.pages[0] if b.pages else b.new_page()
    all_results = {}
    for url in args.folders:
        print("[nav]", url)
        try:
            pg.goto(url, wait_until="commit", timeout=30000)
            pg.wait_for_timeout(10000)
            cur = pg.url.lower()
            if "login" in cur or "sso." in cur:
                print("  [skip] login redirect")
                continue
            for _ in range(8):
                pg.evaluate("window.scrollBy(0, 800)")
                pg.wait_for_timeout(900)
            items = extract_mp4(pg)
            print("  [mp4]", len(items))
            all_results[url] = items
        except Exception as e:
            print("  [err]", e)
            all_results[url] = []
    out_file.write_text(json.dumps({
        "alias": args.alias,
        "scanned_at": stamp,
        "folders": all_results,
    }, ensure_ascii=False, indent=2), encoding="utf-8")
    print("[ok] ->", str(out_file))
    b.close(); p.stop()


if __name__ == "__main__":
    main()
