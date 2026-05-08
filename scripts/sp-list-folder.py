#!/usr/bin/env python3
"""Lista ficheros de una carpeta SharePoint via API REST + cookies de sesion.

Uso: python3 sp-list-folder.py <alias> <site_url> <folder_relative_path>
"""
import argparse, json, os, sys, time
from pathlib import Path
os.environ["PYTHONUTF8"] = "1"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from browser_helpers import SIGNAL, load_account


def fetch_folder(page, site_url, folder_rel):
    site = site_url.rstrip("/")
    rel = "/" + folder_rel.strip("/")
    user_seg = site.split("/personal/")[-1] if "/personal/" in site else None
    if user_seg:
        srv_rel = "/personal/" + user_seg + rel
    else:
        srv_rel = rel
    api = (site + "/_api/web/GetFolderByServerRelativeUrl('"
           + srv_rel.replace("'", "''")
           + "')/Files?$select=Name,ServerRelativeUrl,TimeLastModified,Length"
           "&$orderby=TimeLastModified desc&$top=200")
    print("[api]", api[:140])
    js = (
        "async (u) => {"
        " const r = await fetch(u, {credentials: 'include',"
        "   headers: {'Accept': 'application/json;odata=verbose'}});"
        " const t = await r.text();"
        " return {status: r.status, body: t.substring(0, 400000)};"
        "}"
    )
    return page.evaluate(js, api)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("alias")
    ap.add_argument("site_url")
    ap.add_argument("folder", nargs='?', default="Documents/Recordings")
    args = ap.parse_args()
    from playwright.sync_api import sync_playwright
    cfg = load_account(args.alias)
    sd = str(SIGNAL.parent / cfg["session_dir"])
    out_dir = Path.home() / ".savia" / "captured-vtt"
    out_dir.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    p = sync_playwright().start()
    b = p.chromium.launch_persistent_context(
        sd, headless=False,
        args=["--window-position=-2000,-2000", "--window-size=1200,800"],
        viewport={"width": 1200, "height": 800}, timeout=0,
    )
    pg = b.pages[0] if b.pages else b.new_page()
    pg.goto(args.site_url, wait_until="commit", timeout=30000)
    pg.wait_for_timeout(5000)
    res = fetch_folder(pg, args.site_url, args.folder)
    print("[status]", res.get("status"))
    body = res.get("body", "")
    parsed = None
    try:
        parsed = json.loads(body)
        files = parsed.get("d", {}).get("results", [])
        print("[files]", len(files))
        for f in files[:25]:
            nm = f.get("Name", "")
            md = f.get("TimeLastModified", "")[:10]
            print("  -", md, "|", nm)
    except Exception as e:
        print("[err parse]", e)
        print("[body head]", body[:400])
    out = out_dir / ("sp-folder-" + args.alias + "-" + stamp + ".json")
    out.write_text(json.dumps({
        "alias": args.alias, "site": args.site_url, "folder": args.folder,
        "scanned_at": stamp, "status": res.get("status"),
        "raw": (body if not parsed else None),
        "files": (parsed.get("d", {}).get("results", []) if parsed else []),
    }, ensure_ascii=False, indent=2), encoding="utf-8")
    print("[ok] ->", str(out))
    b.close(); p.stop()


if __name__ == "__main__":
    main()
