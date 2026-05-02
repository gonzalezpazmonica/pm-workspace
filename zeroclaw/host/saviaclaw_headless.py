#!/usr/bin/env python3
"""SaviaClaw Headless — autonomous server agent (Era 197: SE-095 + SE-096 + SE-097).

Self-monitoring: heartbeat, stuck detection, status reporting.
Cron: scheduled tasks via ~/.savia/zeroclaw/cron/jobs.json.
Streaming: progressive stdout capture for live feedback.
"""
import sys, os, time, signal, json, logging, subprocess, threading, uuid, re
from logging.handlers import RotatingFileHandler
from pathlib import Path

# ── Paths ────────────────────────────────────────────────────────────
LOG_DIR    = os.path.expanduser("~/.savia/zeroclaw")
LOG_FILE   = os.path.join(LOG_DIR, "headless.log")
STATUS_FILE = os.path.join(LOG_DIR, "headless-status.json")
CRON_DIR   = os.path.join(LOG_DIR, "cron")
JOBS_FILE  = os.path.join(CRON_DIR, "jobs.json")
LOGS_DIR   = os.path.join(CRON_DIR, "logs")
WORKSPACE  = os.path.expanduser("~/claude")
TICK_INTERVAL = 10

_shutdown = False

# ── Activity tracking (SE-095) ──────────────────────────────────────
_activity = {"last_ts": time.time(), "desc": "startup", "tool_calls": 0,
             "messages_rx": 0, "messages_tx": 0, "pending_tasks": {}}
def _touch(desc=""):
    _activity["last_ts"] = time.time()
    _activity["desc"] = desc or _activity["desc"]
def _summary():
    s = dict(_activity)
    s["uptime_sec"] = int(time.time() - _start_time)
    s["pending"] = list(_activity["pending_tasks"].keys())
    s["stalled"] = {k: int(time.time()-v) for k,v in _activity["pending_tasks"].items()
                    if time.time()-v > 300}
    return s

# ── Logging ──────────────────────────────────────────────────────────
def _log():
    os.makedirs(LOG_DIR, exist_ok=True)
    h = RotatingFileHandler(LOG_FILE, maxBytes=1_000_000, backupCount=3)
    h.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
    L = logging.getLogger("saviaclaw.headless")
    L.setLevel(logging.INFO); L.addHandler(h); L.addHandler(logging.StreamHandler())
    return L

def _write_status(state, detail=""):
    os.makedirs(LOG_DIR, exist_ok=True)
    s = _summary()
    s["state"] = state; s["detail"] = detail
    with open(STATUS_FILE, "w") as f: json.dump(s, f)

# ── LLM Backend ──────────────────────────────────────────────────────
def _run_opencode(prompt, timeout=600):
    """opencode run sincrono (respuesta larga con tools)."""
    try:
        r = subprocess.run(["opencode", "run", prompt], capture_output=True,
                           text=True, timeout=timeout, cwd=WORKSPACE,
                           env={**os.environ, "TERM": "dumb",
                                "PATH": os.path.expanduser("~/.opencode/bin")
                                + ":" + os.environ.get("PATH", "")})
        if r.returncode != 0: return None
        lines = [l.strip() for l in r.stdout.splitlines() if l.strip() and not l.startswith("\x1b")]
        return "\n".join(lines).strip() if lines else None
    except: return None

def _run_opencode_streaming(prompt, log, timeout=600):
    """SE-097: Progressive streaming — captura stdout linea a linea, envia '▸ linea'."""
    from zeroclaw.host.nctalk import send_message
    _touch("streaming: " + prompt[:60])
    lines_sent = 0
    last_send = 0
    last_text = ""
    try:
        proc = subprocess.Popen(["opencode", "run", prompt], stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, text=True, bufsize=1, cwd=WORKSPACE,
                                env={**os.environ, "TERM": "dumb",
                                     "PATH": os.path.expanduser("~/.opencode/bin")
                                     + ":" + os.environ.get("PATH", "")})
        for line in proc.stdout:
            clean = line.strip()
            if not clean or clean.startswith("\x1b"): continue
            last_text = clean
            now = time.time()
            if now - last_send >= 5:  # rate limit: 1 msg / 5s
                send_message(f"\u25b8 {clean[:200]}")
                lines_sent += 1
                last_send = now
        proc.wait(timeout=timeout)
        # Send final result without ▸ prefix
        if lines_sent > 0:
            if last_text:
                send_message(last_text[:1000])
            else:
                send_message("Tarea completada.")
    except Exception as e:
        log.error("Stream error: %s", e)
        send_message(f"\u2717 Error: {str(e)[:200]}")
    finally:
        _activity["pending_tasks"].pop(prompt[:60], None)

# ── Async Respond (SE-095 stuck detection + SE-097 streaming) ───────
def _async_respond(prompt, log):
    from zeroclaw.host.nctalk import send_message
    task_id = prompt[:60]
    _activity["pending_tasks"][task_id] = time.time()
    log.info("Async: %s", task_id)

    # SE-095: stuck detection thread
    warned = [False]
    def _stuck_watch():
        time.sleep(15)
        if task_id in _activity["pending_tasks"] and not warned[0]:
            send_message("Procesando...")
            warned[0] = True
        time.sleep(285)
        if task_id in _activity["pending_tasks"]:
            elapsed = int(time.time() - _activity["pending_tasks"][task_id])
            send_message(f"\u26a0 La tarea lleva {elapsed}s. \u00bfLa cancelo?")

    threading.Thread(target=_stuck_watch, daemon=True).start()

    # Stream or direct depending on prompt length
    if len(prompt) > 100:
        _run_opencode_streaming(prompt, log)
    else:
        ans = _run_opencode(prompt, timeout=45)
        _activity["pending_tasks"].pop(task_id, None)
        if ans: send_message(ans[:1000])
        elif warned[0]: send_message("No pude completarlo. \u00bfLo intentamos distinto?")

# ── Cron (SE-096) ───────────────────────────────────────────────────
def _load_jobs():
    os.makedirs(CRON_DIR, exist_ok=True)
    try:
        with open(JOBS_FILE) as f: return json.load(f)
    except: return []

def _save_jobs(jobs):
    os.makedirs(CRON_DIR, exist_ok=True)
    with open(JOBS_FILE, "w") as f:
        json.dump(jobs, f, indent=2)

def _cron_tick(log):
    """SE-096: Evaluate scheduled jobs, fire due ones."""
    jobs = _load_jobs()
    if not jobs: return
    now = time.time()
    fired = False
    for j in jobs:
        if not j.get("enabled", True): continue
        next_ts = j.get("_next_ts", 0)
        if now >= next_ts:
            log.info("[cron] firing: %s (%s)", j["id"], j["action"][:80])
            j["last_run"] = time.strftime("%Y-%m-%d %H:%M")
            fired = True
            # Fire in background thread
            threading.Thread(target=_run_opencode, args=(j["action"],), daemon=True).start()
            # Advance to next occurrence
            j["_next_ts"] = _next_cron_ts(j["schedule"])
    if fired: _save_jobs(jobs)

def _parse_cron(expr):
    """Parse 5-field cron: 'min hour dom mon dow' → Unix timestamp."""
    try:
        from datetime import datetime
        parts = expr.strip().split()
        if len(parts) != 5: return None
        mm, hh, dom, mon, dow = parts
        # Simple: today at HH:MM. Full croniter would handle */5 etc.
        now = datetime.now()
        target = now.replace(hour=int(hh), minute=int(mm), second=0, microsecond=0)
        ts = target.timestamp()
        if ts <= time.time(): ts += 86400  # tomorrow
        return ts
    except: return None

_next_cron_ts = _parse_cron

def _handle_cron_command(text, log):
    """Process /cron commands from Talk."""
    from zeroclaw.host.nctalk import send_message
    jobs = _load_jobs()
    if text.startswith("/cron list"):
        if not jobs: return "No hay tareas programadas."
        lines = ["Tareas programadas:"]
        for j in jobs:
            ts = j.get("_next_ts", 0)
            next_run = time.strftime("%H:%M", time.localtime(ts)) if ts else "?"
            lines.append(f"  {j['id']}: {j['schedule']} \u2192 {j['action'][:60]} (next: {next_run})")
        return "\n".join(lines)
    if text.startswith("/cron add"):
        # /cron add 30 22 * * * backup diario: zip + email
        rest = text[len("/cron add "):].strip()
        parts = rest.split(None, 5)
        if len(parts) < 6: return "Formato: /cron add MIN HORA DOM MON DOW descripcion"
        expr = " ".join(parts[:5])
        desc = parts[5]
        ts = _parse_cron(expr)
        if not ts: return f"Expresion cron invalida: {expr}"
        jid = str(uuid.uuid4())[:8]
        jobs.append({"id": jid, "schedule": expr, "action": desc,
                      "enabled": True, "_next_ts": ts, "last_run": None})
        _save_jobs(jobs)
        return f"Creada tarea {jid}: {expr} \u2192 {desc[:60]}"
    if text.startswith("/cron remove"):
        jid = text[len("/cron remove "):].strip()
        jobs = [j for j in jobs if j["id"] != jid]
        _save_jobs(jobs)
        return f"Tarea {jid} eliminada."
    if text.startswith("/cron run"):
        jid = text[len("/cron run "):].strip()
        for j in jobs:
            if j["id"] == jid:
                threading.Thread(target=_run_opencode, args=(j["action"],), daemon=True).start()
                return f"Ejecutando {jid}..."
        return f"Tarea {jid} no encontrada."
    return None

# ── Talk Poll ────────────────────────────────────────────────────────
_last_user_messages = {}

def _talk_poll(log):
    try:
        from zeroclaw.host.nctalk import poll_and_respond, send_message
        def handle_msg(prompt):
            _touch("msg_rx: " + prompt[:60])
            _activity["messages_rx"] += 1
            now = time.time()
            # Dedup 120s
            key = prompt[:200].strip().lower()
            prev = _last_user_messages.get(key, 0)
            if now - prev < 120: return None
            _last_user_messages[key] = now

            # Cron commands
            if prompt.startswith("/cron"):
                ans = _handle_cron_command(prompt, log)
                if ans: return ans

            # Status check (SE-095)
            if any(q in prompt.lower() for q in ["estás bien", "estás viva", "estás ahí",
                                                   "cómo estás", "todo bien", "are you alive",
                                                   "status", "estado"]):
                s = _summary()
                return (f"Viva. {s['uptime_sec']//60}min up, {s['messages_rx']} msgs rx, "
                        f"{s['messages_tx']} tx, tick #{int(s.get('uptime_sec',0)//TICK_INTERVAL)}. "
                        f"Pendiente: {len(s['pending'])} tareas. "
                        + (f"Stalled: {len(s['stalled'])}." if s['stalled'] else ""))

            # Long prompt → async with streaming
            if len(prompt) > 100:
                threading.Thread(target=_async_respond, args=(prompt, log), daemon=True).start()
                return None

            return _run_opencode(prompt, timeout=45)

        poll_and_respond(llm_fn=handle_msg, logger=log)
    except Exception as e:
        log.warning("Talk poll: %s", e)

# ── Heartbeat (SE-095) ───────────────────────────────────────────────
def _heartbeat_check(log):
    """Cada 120s, ping a opencode. 3 fallos → auto-reinicio."""
    fails = _heartbeat_check.__dict__.setdefault("fails", 0)
    r = _run_opencode("responde solo: ok", timeout=30)
    if r and "ok" in r.lower():
        _heartbeat_check.fails = 0
        return
    fails = _heartbeat_check.__dict__["fails"] = _heartbeat_check.__dict__.get("fails", 0) + 1
    log.warning("Heartbeat fail #%d/3", fails)
    if fails >= 3:
        log.error("3 heartbeat fails. Auto-restarting...")
        os.system("systemctl restart saviaclaw-headless")

# ── Main Loop ────────────────────────────────────────────────────────
_start_time = time.time()

SCHEDULE = [
    {"name": "git-status", "interval_min": 30, "type": "shell",
     "action": "git -C ~/claude log --oneline -1; git -C ~/claude status --short | head -5",
     "silent_empty": True},
    {"name": "cron-tick",  "interval_min": 1,  "type": "cron"},
    {"name": "talk-poll",  "interval_min": 0,  "type": "talk"},
]

def run(log, once=False):
    log.info("SaviaClaw headless starting (pid=%d)", os.getpid())
    _write_status("running")
    last = {}; tick = 0; last_hb = time.time(); last_cron = 0
    while not _shutdown:
        tick += 1; now = time.time()
        for t in SCHEDULE:
            interval = t.get("interval_min", 5) * 60
            if now - last.get(t["name"], 0) < interval: continue
            last[t["name"]] = now
            try:
                if t["type"] == "talk":
                    _talk_poll(log)
                elif t["type"] == "cron":
                    _cron_tick(log)
                elif t["type"] == "shell":
                    r = _shell_task(t["action"])
                    if r and not t.get("silent_empty"):
                        log.info("[%s] %s", t["name"], r[:120])
            except Exception as e:
                log.error("[%s] %s", t["name"], e)
        # Heartbeat
        if now - last_hb > 120:
            _heartbeat_check(log)
            last_hb = now
        if once: break
        time.sleep(TICK_INTERVAL)
    log.info("shutdown after %d ticks", tick)

def _shell_task(cmd, timeout=30):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout, cwd=WORKSPACE)
        return r.stdout.strip()
    except: return None

def main():
    signal.signal(signal.SIGINT, lambda *_: setattr(sys.modules[__name__], '_shutdown', True))
    signal.signal(signal.SIGTERM, lambda *_: setattr(sys.modules[__name__], '_shutdown', True))
    log = _log()
    log.info("=" * 30); log.info("SaviaClaw Headless Agent"); log.info("=" * 30)
    run(log, once="--once" in sys.argv)

if __name__ == "__main__":
    main()
