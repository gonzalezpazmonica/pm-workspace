import json, time
from pathlib import Path
from playwright.sync_api import sync_playwright
H = Path.home()
PORT = 9221
SIG = H / ".savia" / "vass-extract.signal"
STOP = H / ".savia" / "vass-stop.signal"
CALSIG = H / ".savia" / "vass-calendar.signal"
OUT = Path(__file__).parent / "output"
OUT.mkdir(parents=True, exist_ok=True)
for s in [SIG, STOP, CALSIG]:
    if s.exists(): s.unlink()

p = sync_playwright().start()
c = p.chromium.launch_persistent_context(
    str(H/".savia"/"chromium-vass"), headless=False,
    args=[f"--remote-debugging-port={PORT}", "--window-position=1300,100", "--window-size=1200,800"],
    viewport={"width":1200,"height":800}, timeout=30000,
)
pg = c.pages[0] if c.pages else c.new_page()
URL = "https" + "://" + "outlook.office365.com/mail/inbox"
pg.goto(URL, wait_until="domcontentloaded")
print(f"VASS_DAEMON_READY port={PORT}", flush=True)

def ex_inbox():
    return pg.evaluate("""() => {
        const r = [];
        document.querySelectorAll('[role="option"],[data-convid]').forEach(el => {
            const t = (el.innerText || '').trim();
            if (t.length > 40) r.push(t.substring(0, 700));
        });
        return r.slice(0, 40);
    }""")

def ex_cal():
    pg.goto("https" + "://" + "outlook.office365.com/calendar/view/day", wait_until="domcontentloaded")
    pg.wait_for_timeout(5000)
    pg.evaluate("""() => {
        document.querySelectorAll('button').forEach(b => {
            const al = (b.getAttribute('aria-label') || '').toLowerCase();
            if (al.includes('ir al d\u00eda siguiente')) b.click();
        });
    }""")
    pg.wait_for_timeout(5000)
    return pg.evaluate("""() => {
        const r = [], seen = new Set();
        document.querySelectorAll('[aria-label]').forEach(el => {
            const al = el.getAttribute('aria-label') || '';
            if (al.length < 20 || al.length > 250) return;
            if (!al.match(/\d{1,2}[:.]\d{2}/)) return;
            if (seen.has(al)) return;
            seen.add(al); r.push(al.substring(0, 250));
        });
        return r.slice(0, 40);
    }""")

while True:
    time.sleep(2)
    if STOP.exists():
        STOP.unlink(); break
    if SIG.exists():
        SIG.unlink()
        try:
            if "login" in pg.url: pg.goto(URL, wait_until="domcontentloaded", timeout=30000)
            elif "outlook" not in pg.url: pg.goto(URL, wait_until="domcontentloaded", timeout=30000)
            pg.wait_for_timeout(5000)
            em = ex_inbox()
            (OUT / "inbox-vass-chromium.json").write_text(json.dumps({"account":"vass","ts":time.strftime("%Y-%m-%dT%H:%M:%S"),"count":len(em),"emails":em}, ensure_ascii=False, indent=2), encoding="utf-8")
            print(f"VASS INBOX: {len(em)}", flush=True)
        except Exception as e: print(f"err in: {e}", flush=True)
    if CALSIG.exists():
        CALSIG.unlink()
        try:
            evs = ex_cal()
            (OUT / "cal-vass-15.json").write_text(json.dumps({"account":"vass","ts":time.strftime("%Y-%m-%dT%H:%M:%S"),"count":len(evs),"events":evs}, ensure_ascii=False, indent=2), encoding="utf-8")
            print(f"VASS CAL: {len(evs)}", flush=True)
        except Exception as e: print(f"err cal: {e}", flush=True)
c.close(); p.stop()
print("VASS_STOPPED", flush=True)