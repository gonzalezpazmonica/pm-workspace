import json, time
from pathlib import Path
from playwright.sync_api import sync_playwright
H = Path.home()
OUT = Path(__file__).parent / "output"
OUT.mkdir(parents=True, exist_ok=True)
p = sync_playwright().start()
c = p.chromium.launch_persistent_context(
    str(H/".savia"/"chromium-vass"), headless=True, timeout=30000,
)
pg = c.pages[0] if c.pages else c.new_page()
URL = "https" + "://" + "outlook.office365.com/mail/inbox"
pg.goto(URL, wait_until="domcontentloaded", timeout=60000)
try: pg.wait_for_selector('[role="option"]', timeout=40000)
except: pass
pg.wait_for_timeout(5000)
em = pg.evaluate("""() => {
    const r = [];
    document.querySelectorAll('[role="option"],[data-convid]').forEach(el => {
        const t = (el.innerText || '').trim();
        if (t.length > 40) r.push(t.substring(0, 700));
    });
    return r.slice(0, 40);
}""")
(OUT / "inbox-vass-chromium.json").write_text(json.dumps({"account":"vass","ts":time.strftime("%Y-%m-%dT%H:%M:%S"),"count":len(em),"emails":em}, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"vass: {len(em)} emails", flush=True)
c.close()
p.stop()