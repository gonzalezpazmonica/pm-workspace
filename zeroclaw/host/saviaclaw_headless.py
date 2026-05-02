#!/usr/bin/env python3
"""SaviaClaw Headless — autonomous server agent without ESP32 hardware.

Usage:
    python3 -m zeroclaw.host.saviaclaw_headless
    python3 -m zeroclaw.host.saviaclaw_headless --once
"""
import sys, os, time, signal, json, logging
from logging.handlers import RotatingFileHandler

LOG_DIR = os.path.expanduser("~/.savia/zeroclaw")
LOG_FILE = os.path.join(LOG_DIR, "headless.log")
STATUS_FILE = os.path.join(LOG_DIR, "headless-status.json")
WORKSPACE = os.path.expanduser("~/claude")
TICK_INTERVAL = 30
MEMORY_DIR = os.path.expanduser("~/.savia-memory/auto")
MEMORY_FILE = os.path.join(MEMORY_DIR, "MEMORY.md")

_shutdown = False

def _base_logger():
    os.makedirs(LOG_DIR, exist_ok=True)
    h = RotatingFileHandler(LOG_FILE, maxBytes=1_000_000, backupCount=3)
    h.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
    L = logging.getLogger("saviaclaw.headless")
    L.setLevel(logging.INFO); L.addHandler(h); L.addHandler(logging.StreamHandler())
    return L
def _on_signal(s, f): global _shutdown; _shutdown = True

# ── task runners (self-contained, no consciousness imports) ──────────
def _llm_task(prompt, timeout=60):
    """Usa OpenCode con TERM=dumb — mismo flujo que Savia (tools, hooks, skills, reglas)."""
    import subprocess
    try:
        r = subprocess.run(
            ["opencode", "run", prompt],
            capture_output=True, text=True, timeout=timeout, cwd=WORKSPACE,
            env={**os.environ, "TERM": "dumb",
                 "PATH": os.path.expanduser("~/.opencode/bin") + ":" + os.environ.get("PATH", "")}
        )
        if r.returncode != 0:
            return None
        # Clean TTY garbage if any
        lines = [l.strip() for l in r.stdout.splitlines()
                 if l.strip() and not l.startswith("\x1b") and "⏺" not in l]
        return "\n".join(lines).strip() if lines else None
    except subprocess.TimeoutExpired:
        return None
    except Exception:
        return None

def _shell_task(cmd, timeout=30):
    import subprocess
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True,
                           timeout=timeout, cwd=WORKSPACE)
        return r.stdout.strip()
    except: return None

def _talk_poll(log):
    try:
        from zeroclaw.host.nctalk import poll_and_respond
        poll_and_respond(llm_fn=_llm_task, logger=log)
    except Exception as e:
        log.warning("Talk poll: %s", e)

def _gmail_check(log):
    try:
        from zeroclaw.host.gmail_check import check_and_notify
        check_and_notify(_llm_task, lambda msg: log.info("Gmail notify: %s", msg[:60]), log)
    except Exception as e:
        log.warning("Gmail check: %s", e)

# ── schedule ─────────────────────────────────────────────────────────
SCHEDULE = [
    {"name": "git-status",  "interval_min": 30, "type": "shell", "action": "git -C ~/claude log --oneline -1; git -C ~/claude status --short | head -5", "silent_empty": True},
    {"name": "memory",      "interval_min": 60, "type": "llm",   "action": "/memory-stats"},
    {"name": "talk-poll",   "interval_min": 0,  "type": "talk"},
    {"name": "gmail-check", "interval_min": 5,  "type": "gmail"},
    {"name": "gdrive-sync", "interval_min": 360, "type": "shell", "action": "python3 zeroclaw/host/gdrive_sync.py sync", "notify": "on_error"},
]

# ── main loop ────────────────────────────────────────────────────────
def run(log, once=False):
    log.info("SaviaClaw headless starting (pid=%d)", os.getpid())
    last = {}
    tick = 0
    while not _shutdown:
        tick += 1
        now = time.time()
        for t in SCHEDULE:
            name = t["name"]
            interval = t.get("interval_min", 5) * 60
            if now - last.get(name, 0) < interval:
                continue
            last[name] = now
            log.info("[%s] running", name)
            try:
                typ = t["type"]
                if typ == "shell":
                    r = _shell_task(t["action"])
                    if r and not t.get("silent_empty"):
                        log.info("[%s] %s", name, r[:120])
                elif typ == "llm":
                    r = _llm_task(t["action"])
                    log.info("[%s] %s", name, str(r)[:120])
                elif typ == "talk":
                    _talk_poll(log)
                elif typ == "gmail":
                    _gmail_check(log)
            except Exception as e:
                log.error("[%s] %s", name, e)
        if once:
            log.info("--once complete"); return
        time.sleep(TICK_INTERVAL)
    log.info("shutdown after %d ticks", tick)

def main():
    signal.signal(signal.SIGINT, _on_signal)
    signal.signal(signal.SIGTERM, _on_signal)
    log = _base_logger()
    log.info("=" * 30)
    log.info("SaviaClaw Headless Agent")
    log.info("=" * 30)
    run(log, once="--once" in sys.argv)

if __name__ == "__main__":
    main()
