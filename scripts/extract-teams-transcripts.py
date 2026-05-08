#!/usr/bin/env python3
"""Extract meeting transcripts from Teams web via CDP.

Flow: Teams chat -> Transcript button -> xplatplugins.aspx iframe -> scroll+extract DOM.
Works for own meetings AND meetings where the user attended (organized by others).

Requirements:
  - Browser-daemon running with CDP port (9222 or 9223).
  - Teams web tab authenticated at teams.microsoft.com/v2/.

Usage:
  python scripts/extract-teams-transcripts.py --port 9223 --out-dir DIR --batch
  python scripts/extract-teams-transcripts.py --port 9223 --out-dir DIR --substring "Demo OCV"
"""
import argparse
import json
import os
import re
import sys
import time
import unicodedata
import urllib.request
import websocket


def get_tabs(port):
    return json.loads(urllib.request.urlopen("http://127.0.0.1:" + str(port) + "/json").read())


def find_tab(port, kind="page", url_contains=None):
    for t in get_tabs(port):
        if t.get("type") != kind:
            continue
        if url_contains and url_contains not in (t.get("url") or ""):
            continue
        return t
    return None


def teams_tab(port):
    return find_tab(port, "page", "teams.microsoft.com")


def xplat_iframe(port):
    return find_tab(port, "iframe", "xplatplugins.aspx")


class CDP:
    def __init__(self, target):
        self.ws = websocket.create_connection(
            target["webSocketDebuggerUrl"], suppress_origin=True, timeout=30
        )
        self.i = 0
        self._send("Page.enable")

    def _send(self, method, params=None):
        self.i += 1
        self.ws.send(json.dumps({"id": self.i, "method": method, "params": params or {}}))
        while True:
            r = json.loads(self.ws.recv())
            if r.get("id") == self.i:
                return r

    def eval(self, js):
        r = self._send("Runtime.evaluate", {"expression": js, "returnByValue": True})
        res = r.get("result", {}).get("result", {})
        if res.get("subtype") == "error":
            return {"_cdp_err": res.get("description", "?")}
        return res.get("value")

    def close(self):
        try:
            self.ws.close()
        except Exception:
            pass


JS_LIST_CHATS = r"""
(() => {
    const items = document.querySelectorAll('[role="treeitem"]');
    const out = []; const seen = new Set();
    items.forEach(it => {
        const tx = (it.innerText||'').trim();
        if (!tx) return;
        const first = tx.split('\n')[0].trim();
        const isMeeting = first.startsWith('[') || first.startsWith('Revisi');
        if (!isMeeting) return;
        if (first.length < 10 || first.length > 150) return;
        if (seen.has(first)) return;
        seen.add(first); out.push(first);
    });
    return JSON.stringify(out);
})()
"""

JS_EXPAND_CHATS = r"""
(() => {
    const items = document.querySelectorAll('[role="treeitem"]');
    for (const it of items) {
        if ((it.innerText||'').trim() === 'Chats' && it.getAttribute('aria-expanded') === 'false') it.click();
    }
    return 1;
})()
"""

JS_SCROLL_TREE_TPL = r"""
(() => {
    const tree = document.querySelector('[role="tree"]');
    if (tree) tree.scrollTop = tree.scrollHeight * __FRAC__;
    return tree ? tree.scrollHeight : 0;
})()
"""

JS_CLICK_CHAT_TPL = r"""
(() => {
    const T = __T__;
    const items = document.querySelectorAll('[role="treeitem"]');
    for (const it of items) {
        const first = (it.innerText||'').split('\n')[0].trim();
        if (first === T) {
            it.scrollIntoView({block:'center'});
            (it.querySelector('a,button,[role="button"]') || it).click();
            return '1';
        }
    }
    return '0';
})()
"""

JS_CLICK_TRANSCRIPT_TPL = r"""
(() => {
    // New Teams UI (post 2026-04): tab in recap-right-panel-pill-list
    const tab = document.querySelector('button[role="tab"][data-tid="Transcript"]');
    if (tab) { tab.scrollIntoView({block:'center'}); tab.click(); return 't'; }
    // Fallback to legacy buttons by label
    const btns = Array.from(document.querySelectorAll('button, a, [role="button"]'));
    const btn = btns.find(b => (b.innerText||'').trim() === __TRANS__);
    if (btn) { btn.scrollIntoView({block:'center'}); btn.click(); return 't'; }
    const vr = btns.find(b => (b.innerText||'').trim() === __RESUMEN__);
    if (vr) { vr.click(); return 'r'; }
    return 'n';
})()
"""

# New scroll: target the recap panel in the parent page (post-2026-04 inline UI).
# Returns body text from the meeting-recap-main-panel container.
JS_SCROLL_RECAP = r"""
(() => {
    const panel = document.querySelector('[data-tid="meeting-recap-main-panel"]');
    if (!panel) return JSON.stringify({err:'no_panel', body:''});
    // Find tallest scrollable inside panel
    let c = panel; let h = 0;
    panel.querySelectorAll('*').forEach(el => {
        const sh = el.scrollHeight - el.clientHeight;
        if (sh > 20 && el.clientHeight > 100 && sh > h) { h = sh; c = el; }
    });
    const i = {sh:c.scrollHeight, ch:c.clientHeight, st:c.scrollTop};
    c.scrollTop = c.scrollTop + c.clientHeight * 0.85;
    i.body = panel.innerText || '';
    return JSON.stringify(i);
})()
"""

# Legacy scroll for old iframe-based UI (kept as fallback).
JS_SCROLL_IFRAME = r"""
(() => {
    let c = null; let h = 0;
    for (const el of document.querySelectorAll('*')) {
        const sh = el.scrollHeight - el.clientHeight;
        if (sh > 20 && el.clientHeight > 100 && sh > h) { h = sh; c = el; }
    }
    if (!c) return JSON.stringify({err:'nc', body:(document.body.innerText||'')});
    const i = {sh:c.scrollHeight, ch:c.clientHeight, st:c.scrollTop};
    c.scrollTop = c.scrollTop + c.clientHeight * 0.85;
    i.body = document.body.innerText || '';
    return JSON.stringify(i);
})()
"""


def norm(s):
    return "".join(c for c in unicodedata.normalize("NFD", s.lower()) if unicodedata.category(c) != "Mn")


def expand_and_list(port):
    tt = teams_tab(port)
    if not tt:
        return []
    cdp = CDP(tt)
    cdp.eval(JS_EXPAND_CHATS)
    time.sleep(2)
    for s in range(10):
        cdp.eval(JS_SCROLL_TREE_TPL.replace("__FRAC__", str(s * 0.12)))
        time.sleep(1)
    res = cdp.eval(JS_LIST_CHATS)
    cdp.close()
    try:
        return json.loads(res) if res else []
    except Exception:
        return []


def click_chat(port, title):
    tt = teams_tab(port)
    cdp = CDP(tt)
    res = cdp.eval(JS_CLICK_CHAT_TPL.replace("__T__", json.dumps(title)))
    cdp.close()
    return res


def click_transcript(port, trans_label, resumen_label):
    tt = teams_tab(port)
    cdp = CDP(tt)
    js = (JS_CLICK_TRANSCRIPT_TPL
          .replace("__TRANS__", json.dumps(trans_label))
          .replace("__RESUMEN__", json.dumps(resumen_label)))
    res = cdp.eval(js)
    cdp.close()
    return res


def _try_recap_panel(port, max_iter, stop_stalls):
    tt = teams_tab(port)
    if not tt:
        return None
    cdp = CDP(tt)
    deadline = time.time() + 12
    ready = False
    PROBE = '(()=>{const p=document.querySelector(\'[data-tid="meeting-recap-main-panel"]\');return p?p.innerText.length:0;})()'
    while time.time() < deadline:
        plen = cdp.eval(PROBE)
        try:
            if plen and int(plen) > 400:
                ready = True
                break
        except Exception:
            pass
        time.sleep(1)
    if not ready:
        cdp.close()
        return None
    collected = {}
    prev = -1
    stalls = 0
    for step in range(max_iter):
        res = cdp.eval(JS_SCROLL_RECAP)
        if not res:
            break
        try:
            d = json.loads(res)
        except Exception:
            break
        if d.get("err"):
            break
        body = d.get("body") or ""
        for line in body.split(chr(10)):
            ls = line.strip()
            if ls and len(ls) < 400 and ls not in collected:
                collected[ls] = step
        if d.get("st") == prev:
            stalls += 1
        else:
            stalls = 0
            prev = d.get("st", -1)
        if stalls >= stop_stalls:
            break
        if d["st"] + d["ch"] >= d["sh"] - 5:
            break
        time.sleep(0.5)
    cdp.close()
    ordered = sorted(collected.items(), key=lambda x: x[1])
    text = chr(10).join(line for line, _ in ordered)
    return text if text and len(text) > 200 else None


def extract_transcript(port, max_iter=80, stop_stalls=3):
    panel = _try_recap_panel(port, max_iter, stop_stalls)
    if panel:
        return panel
    deadline = time.time() + 25
    ifr = None
    while time.time() < deadline:
        ifr = xplat_iframe(port)
        if ifr:
            break
        time.sleep(1)
    if not ifr:
        return None
    cdp = CDP(ifr)
    time.sleep(3)
    collected = {}
    prev = -1
    stalls = 0
    for step in range(max_iter):
        res = cdp.eval(JS_SCROLL_IFRAME)
        if not res:
            break
        try:
            d = json.loads(res)
        except Exception:
            break
        body = d.get("body") or ""
        for l in body.split("\n"):
            ls = l.strip()
            if ls and len(ls) < 400 and ls not in collected:
                collected[ls] = step
        if d.get("err"):
            break
        if d.get("st") == prev:
            stalls += 1
        else:
            stalls = 0
            prev = d.get("st", -1)
        if stalls >= stop_stalls:
            break
        if d["st"] + d["ch"] >= d["sh"] - 5:
            break
        time.sleep(0.5)
    cdp.close()
    ordered = sorted(collected.items(), key=lambda x: x[1])
    return "\n".join(l for l, _ in ordered)


def save_transcript(out_dir, title, text):
    os.makedirs(out_dir, exist_ok=True)
    slug = re.sub(r"[^\w\-]+", "-", title)[:70].strip("-")
    dstr = time.strftime("%Y%m%d")
    path = os.path.join(out_dir, dstr + "-teams-" + slug + ".transcript.txt")
    with open(path, "w", encoding="utf-8") as f:
        f.write("# Teams transcript\n")
        f.write("Title: " + title + "\n")
        f.write("Extracted: " + time.strftime("%Y-%m-%d %H:%M") + "\n\n")
        f.write("=" * 60 + "\n")
        f.write(text)
    return path


def process_one(port, title, out_dir, trans_label, resumen_label):
    r = click_chat(port, title)
    if r == "0":
        return {"status": "chat_not_found"}
    time.sleep(6)
    r = click_transcript(port, trans_label, resumen_label)
    if r == "n":
        return {"status": "no_transcript_btn"}
    if r == "r":
        time.sleep(6)
        r = click_transcript(port, trans_label, resumen_label)
        if r != "t":
            return {"status": "no_transcript_after_resumen"}
    time.sleep(5)
    text = extract_transcript(port)
    if not text or len(text) < 100:
        return {"status": "empty", "len": len(text) if text else 0}
    path = save_transcript(out_dir, title, text)
    return {"status": "ok", "path": path, "len": len(text)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=9223)
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--trans-label", default="Transcripción")
    ap.add_argument("--resumen-label", default="Ver resumen")
    ap.add_argument(
        "--skip-file",
        default=os.path.expanduser("~/.savia/teams-processed.json"),
        help="Persistent skip list (default ~/.savia/teams-processed.json — was /tmp/ before; /tmp wiped on reboot)",
    )
    ap.add_argument("--substring")
    ap.add_argument("--batch", action="store_true")
    args = ap.parse_args()

    titles = expand_and_list(args.port)
    print("Meeting chats found: " + str(len(titles)))

    if args.substring:
        needle = norm(args.substring)
        titles = [t for t in titles if needle in norm(t)]
        print("Filtered by substring: " + str(len(titles)))

    if not args.batch and not args.substring:
        for t in titles:
            print(" - " + t[:100])
        print("\nPass --batch to process all, or --substring X to match one.")
        return 0

    processed = set()
    if args.skip_file and os.path.exists(args.skip_file):
        try:
            processed = set(json.load(open(args.skip_file)))
        except Exception:
            pass

    results = []
    for title in titles:
        if title in processed:
            print("[skip] " + title[:60])
            continue
        print("[process] " + title[:70])
        r = process_one(args.port, title, args.out_dir, args.trans_label, args.resumen_label)
        processed.add(title)
        if args.skip_file:
            try:
                json.dump(sorted(processed), open(args.skip_file, "w"))
            except Exception:
                pass
        results.append((title, r))
        print("  => " + str(r.get("status")) + " (" + str(r.get("len", "")) + " chars)")

    print("\n=== SUMMARY ===")
    ok = sum(1 for _, r in results if r.get("status") == "ok")
    print("Processed: " + str(len(results)) + " | OK: " + str(ok))
    for title, r in results:
        print("  [" + str(r.get("status", "?")) + "] " + title[:60])
    return 0


if __name__ == "__main__":
    sys.exit(main())
