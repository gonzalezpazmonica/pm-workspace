#!/usr/bin/env python3
"""SaviaClaw Headless — autonomous server agent.

Async Talk pattern:
- Receive message → ack immediately if task takes >10s
- "Procesando... 10s" / "Procesando... 20s" cada 10s mientras ejecuta
- Resultado final cuando termina
- Dedup: no responde a mensajes repetidos (mismo texto en <60s)
"""
import sys, os, time, signal, json, logging, subprocess, threading
from logging.handlers import RotatingFileHandler

LOG_DIR = os.path.expanduser("~/.savia/zeroclaw")
LOG_FILE = os.path.join(LOG_DIR, "headless.log")
STATUS_FILE = os.path.join(LOG_DIR, "headless-status.json")
WORKSPACE = os.path.expanduser("~/claude")
TICK_INTERVAL = 10

_shutdown = False
_pending_tasks = {}           # msg_id → thread
_last_user_messages = {}      # msg_text → timestamp (dedup)

def _log():
    os.makedirs(LOG_DIR, exist_ok=True)
    h = RotatingFileHandler(LOG_FILE, maxBytes=1_000_000, backupCount=3)
    h.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
    L = logging.getLogger("saviaclaw.headless")
    L.setLevel(logging.INFO); L.addHandler(h); L.addHandler(logging.StreamHandler())
    return L

def _write_status(state, detail=""):
    os.makedirs(LOG_DIR, exist_ok=True)
    with open(STATUS_FILE, "w") as f:
        json.dump({"state": state, "detail": detail, "ts": time.time(),
                   "tasks": [t["name"] for t in SCHEDULE]}, f)

def _run_opencode(prompt, timeout=600):
    """opencode run con TERM=dumb. Retorna texto o None."""
    try:
        r = subprocess.run(
            ["opencode", "run", prompt],
            capture_output=True, text=True, timeout=timeout, cwd=WORKSPACE,
            env={**os.environ, "TERM": "dumb",
                 "PATH": os.path.expanduser("~/.opencode/bin") + ":" + os.environ.get("PATH", "")}
        )
        if r.returncode != 0:
            return None
        lines = [l.strip() for l in r.stdout.splitlines()
                 if l.strip() and not l.startswith("\x1b")]
        return "\n".join(lines).strip() if lines else None
    except Exception:
        return None

def _async_respond(prompt, log):
    """Ejecuta opencode en background. Solo un aviso a los 15s si tarda."""
    from zeroclaw.host.nctalk import send_message
    log.info("Async task started: %s...", prompt[:60])
    start = time.time()
    warned = [False]

    def _delayed_warn():
        time.sleep(15)
        if not _task_done[0]:
            send_message("Procesando...")
            warned[0] = True

    _task_done = [False]
    threading.Thread(target=_delayed_warn, daemon=True).start()

    ans = _run_opencode(prompt)
    _task_done[0] = True

    elapsed = time.time() - start
    if ans:
        log.info("Async task done in %.0fs", elapsed)
        send_message(ans[:1000])
    elif warned[0]:
        send_message("No pude completarlo en un tiempo razonable. ¿Lo intentamos distinto?")
    else:
        log.warning("Async task returned None after %.0fs", elapsed)

def _talk_poll(log):
    """Polla Talk con dedup TTL y respuesta directa/async segun longitud."""
    try:
        from zeroclaw.host.nctalk import poll_and_respond, send_message
        def handle_msg(prompt):
            now = time.time()
            # Hermes-style dedup: mismo texto en <120s → ignorar
            key = prompt[:200].strip().lower()
            prev = _last_user_messages.get(key, 0)
            if now - prev < 120:
                log.info("Talk dedup: same text within 120s")
                return "_DEDUP_"
            _last_user_messages[key] = now

            if len(prompt) < 80:
                return _run_opencode(prompt, timeout=45)

            threading.Thread(target=_async_respond, args=(prompt, log), daemon=True).start()
            return None

        poll_and_respond(llm_fn=handle_msg, logger=log)
    except Exception as e:
        log.warning("Talk poll: %s", e)

SCHEDULE = [
    {"name": "git-status", "interval_min": 30, "type": "shell",
     "action": "git -C ~/claude log --oneline -1; git -C ~/claude status --short | head -5",
     "silent_empty": True},
    {"name": "talk-poll",  "interval_min": 0,  "type": "talk"},
]

def run(log, once=False):
    log.info("SaviaClaw headless starting (pid=%d)", os.getpid())
    _write_status("running", f"{len(SCHEDULE)} tasks loaded")
    last = {}
    tick = 0
    last_cron = 0
    while not _shutdown:
        tick += 1
        now = time.time()
        for t in SCHEDULE:
            interval = t.get("interval_min", 5) * 60
            if now - last.get(t["name"], 0) < interval:
                continue
            last[t["name"]] = now
            try:
                if t["type"] == "talk":
                    _talk_poll(log)
                elif t["type"] == "shell":
                    r = _shell_task(t["action"])
                    if r and not t.get("silent_empty"):
                        log.info("[%s] %s", t["name"], r[:120])
            except Exception as e:
                log.error("[%s] %s", t["name"], e)
        if now - last_cron > 600:
            _cron_tasks(log)
            last_cron = now
        if once:
            break
        time.sleep(TICK_INTERVAL)
    log.info("shutdown after %d ticks", tick)

def _shell_task(cmd, timeout=30):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout, cwd=WORKSPACE)
        return r.stdout.strip()
    except Exception:
        return None

def _cron_tasks(log):
    log.info("[cron] git-status")
    try:
        r = subprocess.run("cd ~/claude && git log --oneline -1 && git status --short | head -5",
                           shell=True, capture_output=True, text=True, timeout=15)
        if r.stdout.strip():
            log.info("[cron] %s", r.stdout.strip()[:200])
    except Exception:
        pass

def main():
    signal.signal(signal.SIGINT, lambda *_: setattr(sys.modules[__name__], '_shutdown', True))
    signal.signal(signal.SIGTERM, lambda *_: setattr(sys.modules[__name__], '_shutdown', True))
    log = _log()
    log.info("=" * 30)
    log.info("SaviaClaw Headless Agent")
    log.info("=" * 30)
    run(log, once="--once" in sys.argv)

if __name__ == "__main__":
    main()
